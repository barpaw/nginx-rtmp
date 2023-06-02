# ---------------------------------------------------------------------- #
# ----------------------livestreaming-nginx-rtmp------------------------ #
# ---------------------------------------------------------------------- #

# -----------------STAGE 1 nginx-build----------------- #

FROM ubuntu:22.04 AS nginx-build

RUN mkdir /app
WORKDIR /app

# NGINX CORE
ENV NGINX_VERSION=1.24.0
ENV OPENSSL_VERSION=3.0.8
ENV PCRE2_VERSION=10.42
ENV ZLIB_VERSION=1.2.13

# 3RD PARTY MODULES
ENV HEADERS_MORE_NGINX_VERSION=0.34
ENV VTS_VERSION=0.2.1
ENV STS_VERSION=0.1.1
ENV STS_CORE_VERSION=0.1.1
ENV RTMP_VERSION=1.2.2

# Set TimeZone
ENV TZ=Europe/Warsaw
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Add nginx user
RUN groupadd -r nonroot && useradd -r -s /bin/false -g nonroot nonroot

# Add 3rd-party repositories

# Add-apt-repository dependency
RUN apt-get update --fix-missing && \
    apt-get install -y software-properties-common && \
    rm -rf /var/lib/apt/lists/*


# Download needed packages from repository
RUN apt-get update && apt-get install -y \
  build-essential \
  tree \
  curl \
  git \
  cmake \
  wget \
  gcc \
  make \
  unzip \
  ca-certificates \
  autoconf \
  automake \
  libtool \
  pkgconf \
  zlib1g-dev \
  libssl-dev \
  libpcre3-dev \
  libxml2-dev \
  libyajl-dev \
  lua5.2-dev \
  libgeoip-dev \
  libcurl4-openssl-dev \
  openssl \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  zlib1g-dev \
  ffmpeg

# Download dependencies
RUN wget "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz" -O /app/pcre2.tar.gz && tar xzvf /app/pcre2.tar.gz && \
  wget "https://github.com/openresty/headers-more-nginx-module/archive/refs/tags/v${HEADERS_MORE_NGINX_VERSION}.tar.gz" -O /app/headers_more.tar.gz && tar xzvf /app/headers_more.tar.gz && \
  wget "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -O /app/openssl.tar.gz && tar xzvf /app/openssl.tar.gz && \
  wget "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" -O /app/zlib.tar.gz && tar xzvf /app/zlib.tar.gz && \
  wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O /app/nginx.tar.gz && tar xzvf /app/nginx.tar.gz && \
  wget "https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v${VTS_VERSION}.tar.gz" -O /app/vts.tar.gz && tar xzvf /app/vts.tar.gz && \
  wget "https://github.com/vozlt/nginx-module-stream-sts/archive/refs/tags/v${STS_CORE_VERSION}.tar.gz" -O /app/sts_core.tar.gz && tar xzvf /app/sts_core.tar.gz && \
  wget "https://github.com/vozlt/nginx-module-sts/archive/refs/tags/v${STS_VERSION}.tar.gz" -O /app/sts.tar.gz && tar xzvf /app/sts.tar.gz && \
  wget "https://github.com/arut/nginx-rtmp-module/archive/refs/tags/v${RTMP_VERSION}.tar.gz" -O /app/rtmp.tar.gz && tar xzvf /app/rtmp.tar.gz

# Create temp folders
RUN mkdir -p /var/cache/nginx/client_temp && \
  mkdir -p /var/cache/nginx/proxy_temp

# Configure NGINX
RUN cd /app/nginx-${NGINX_VERSION} && \
  ./configure \
  --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --user=nonroot \
  --group=nonroot \
  --build=nginx-rtmp \
  --with-select_module \
  --with-poll_module \
  --with-threads \
  --with-file-aio \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_stub_status_module \
  --with-stream \
  --with-stream_ssl_module \
  --without-http_ssi_module \
  --without-http_userid_module \
  --without-http_mirror_module \
  --without-http_autoindex_module \
  --without-http_split_clients_module \
  --without-http_fastcgi_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --without-http_grpc_module \
  --without-http_gzip_module \
  --without-http_memcached_module \
  --http-log-path=/var/log/nginx/access.log \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --without-mail_pop3_module \
  --without-mail_imap_module \
  --without-mail_smtp_module \
  --add-module=/app/headers-more-nginx-module-${HEADERS_MORE_NGINX_VERSION}  \
  --add-module=/app/nginx-module-vts-${VTS_VERSION} \
  --add-module=/app/nginx-module-stream-sts-${STS_CORE_VERSION} \
  --add-module=/app/nginx-module-sts-${STS_VERSION} \
  --add-module=/app/nginx-rtmp-module-${RTMP_VERSION} \
  --with-cc-opt=-O2 \
  --with-ld-opt='-Wl,-rpath,/usr/local/lib' \
  --with-pcre=/app/pcre2-${PCRE2_VERSION} \
  --with-pcre-jit \
  --with-zlib=/app/zlib-${ZLIB_VERSION} \
  --with-openssl=/app/openssl-${OPENSSL_VERSION} \
  --with-openssl-opt=no-nextprotoneg \
  --with-debug && \
  echo $(eval $CONFIGURE) && \
  make -j2 && make && make install


RUN chown -R nonroot:nonroot /etc/nginx
RUN chown -R nonroot:nonroot /etc/ssl/
RUN chown -R nonroot:nonroot /var/log/nginx/
RUN chown -R nonroot:nonroot /var/cache/nginx/
RUN chown -R nonroot:nonroot /var/run/

# Forward logs to docker log collector
# RUN ln -sf /dev/stdout /var/log/nginx/access.log \
#   && ln -sf /dev/stderr /var/log/nginx/error.log

## !! Uncoment HELPER TO KNOW WHICH FILES NEEDS TO BE COPIED FROM THIS STAGE
#RUN ldd /usr/sbin/nginx

# -----------------STAGE 2 final stage------------------------- #

# Grab the distroless static container.
FROM gcr.io/distroless/base:nonroot as nginx

# Set the container timezone as Europe/Warsaw.
ENV TZ=Europe/Warsaw

# Use this command to list of dependency libraries you should copy:
# command: ldd /usr/sbin/nginx

## NGINX

COPY --from=nginx-build /var/log /var/log
COPY --from=nginx-build /var/cache/nginx /var/cache/nginx
COPY --from=nginx-build /var/run /var/run
# Copy the nginx configuration and binary from build image.
COPY --from=nginx-build /etc/nginx /etc/nginx
COPY --from=nginx-build /usr/sbin/nginx /usr/bin/nginx
# # Copy the necessary dependencies from build image to run nginx properly in static container.

#COPY --from=nginx-build /lib/x86_64-linux-gnu/libmaxminddb.so.0 /lib/x86_64-linux-gnu/

COPY --from=nginx-build /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/
COPY --from=nginx-build /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/

COPY --from=nginx-build /lib64/ld-linux-x86-64.so.2 /lib64/
# # This is important for nginx as it is using libnss to query user information from `/etc/passwd` otherwise you will receive error like `nginx: [emerg] getpwnam("nonroot") failed`.
COPY --from=nginx-build /lib/x86_64-linux-gnu/libnss_compat.so.2 /lib/x86_64-linux-gnu/
COPY --from=nginx-build /lib/x86_64-linux-gnu/libnss_files.so.2 /lib/x86_64-linux-gnu/

# NGINX needs to be started as root. (for master proces)
# Only root processes can listen to ports below 1024
USER root

EXPOSE 443/tcp 2006/tcp

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]