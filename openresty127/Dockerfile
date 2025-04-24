### STAGE-1-BEGIN
# Dockerfile - alpine
# https://github.com/openresty/docker-openresty

ARG RESTY_IMAGE_BASE="alpine"
ARG RESTY_IMAGE_TAG="3.21.3"

FROM --platform=$TARGETPLATFORM ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG} AS build

LABEL maintainer="tofuliang <tofuliang@gmail.com>"

# Docker Build Arguments
ARG TARGETARCH
ARG RESTY_IMAGE_BASE="alpine"
ARG RESTY_IMAGE_TAG="3.21.3"
ARG RESTY_VERSION="1.27.1.2"
# https://github.com/openresty/openresty-packaging/blob/master/alpine/openresty-openssl3/APKBUILD
ARG RESTY_OPENSSL_VERSION="3.4.1"
ARG RESTY_OPENSSL_PATCH_VERSION="3.4.1"
ARG RESTY_OPENSSL_URL_BASE="https://github.com/openssl/openssl/releases/download/openssl-${RESTY_OPENSSL_VERSION}"
# LEGACY:  "https://www.openssl.org/source/old/1.1.1"
ARG RESTY_OPENSSL_BUILD_OPTIONS="enable-camellia enable-seed enable-rfc3779 enable-cms enable-md2 enable-rc5 \
        enable-weak-ssl-ciphers enable-ssl3 enable-ssl3-method enable-md2 enable-ktls enable-fips \
        "

# https://github.com/openresty/openresty-packaging/blob/master/alpine/openresty-pcre2/APKBUILD
ARG RESTY_PCRE_VERSION="10.44"
ARG RESTY_PCRE_SHA256="86b9cb0aa3bcb7994faa88018292bc704cdbb708e785f7c74352ff6ea7d3175b"
ARG RESTY_PCRE_BUILD_OPTIONS="--enable-jit --enable-pcre2grep-jit --disable-bsr-anycrlf --disable-coverage --disable-ebcdic --disable-fuzz-support \
    --disable-jit-sealloc --disable-never-backslash-C --enable-newline-is-lf --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-pcre2grep-callout --enable-pcre2grep-callout-fork --disable-pcre2grep-libbz2 --disable-pcre2grep-libz --disable-pcre2test-libedit \
    --enable-percent-zt --disable-rebuild-chartables --enable-shared --disable-static --disable-silent-rules --enable-unicode --disable-valgrind \
    "

ARG RESTY_J="1"
ARG NGINX_DAV_EXT_MODULE_VERSION="3.0.0"
ARG NGINX_HTTP_PROXY_CONNECT_MODULE_VERSION="0.0.5"

# https://github.com/openresty/openresty-packaging/blob/master/alpine/openresty/APKBUILD
ARG RESTY_CONFIG_OPTIONS="\
    --with-compat \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-http_iconv_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-sha1-asm \
    --with-http_degradation_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --add-module=/tmp/nginx-dav-ext-module-${NGINX_DAV_EXT_MODULE_VERSION}/ \
    --add-module=/tmp/ngx_http_proxy_connect_module-${NGINX_HTTP_PROXY_CONNECT_MODULE_VERSION}/ \
    --add-module=/tmp/ngx_brotli/ \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"
ARG RESTY_PCRE_OPTIONS="--with-pcre-jit"

ARG RESTY_ADD_PACKAGE_BUILDDEPS=""
ARG RESTY_ADD_PACKAGE_RUNDEPS=""
ARG RESTY_EVAL_PRE_CONFIGURE=""
ARG RESTY_EVAL_POST_DOWNLOAD_PRE_CONFIGURE=""
ARG RESTY_EVAL_POST_MAKE=""

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre2/include -I/usr/local/openresty/openssl3/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre2/lib -L/usr/local/openresty/openssl3/lib -Wl,-rpath,/usr/local/openresty/pcre2/lib:/usr/local/openresty/openssl3/lib' \
    "

LABEL resty_image_base="${RESTY_IMAGE_BASE}"
LABEL resty_image_tag="${RESTY_IMAGE_TAG}"
LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_openssl_patch_version="${RESTY_OPENSSL_PATCH_VERSION}"
LABEL resty_openssl_url_base="${RESTY_OPENSSL_URL_BASE}"
LABEL resty_openssl_build_options="${RESTY_OPENSSL_BUILD_OPTIONS}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_pcre_build_options="${RESTY_PCRE_BUILD_OPTIONS}"
LABEL resty_pcre_sha256="${RESTY_PCRE_SHA256}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"
LABEL resty_config_deps="${_RESTY_CONFIG_DEPS}"
LABEL resty_add_package_builddeps="${RESTY_ADD_PACKAGE_BUILDDEPS}"
LABEL resty_add_package_rundeps="${RESTY_ADD_PACKAGE_RUNDEPS}"
LABEL resty_eval_pre_configure="${RESTY_EVAL_PRE_CONFIGURE}"
LABEL resty_eval_post_download_pre_configure="${RESTY_EVAL_POST_DOWNLOAD_PRE_CONFIGURE}"
LABEL resty_eval_post_make="${RESTY_EVAL_POST_MAKE}"
LABEL resty_luajit_options="${RESTY_LUAJIT_OPTIONS}"
LABEL resty_pcre_options="${RESTY_PCRE_OPTIONS}"

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    coreutils \
    curl \
    gd-dev \
    geoip-dev \
    libxslt-dev \
    linux-headers \
    make \
    perl-dev \
    readline-dev \
    zlib-dev \
    ${RESTY_ADD_PACKAGE_BUILDDEPS} \
    && apk add --no-cache \
    gd \
    git \
    geoip \
    libgcc \
    libxslt \
    tzdata \
    zlib \
    ${RESTY_ADD_PACKAGE_RUNDEPS} \
    && apk add --no-cache upx >/dev/null 2>&1 ||true \
    && cd /tmp \
    && curl -fSkL --retry 5 https://github.com/chobits/ngx_http_proxy_connect_module/archive/refs/tags/v${NGINX_HTTP_PROXY_CONNECT_MODULE_VERSION}.tar.gz |tar xzf - -C /tmp \
    && curl -fSkL --retry 5 https://github.com/chobits/ngx_http_proxy_connect_module/raw/master/patch/proxy_connect_rewrite_102101.patch > /tmp/ngx_http_proxy_connect_module-${NGINX_HTTP_PROXY_CONNECT_MODULE_VERSION}/patch/proxy_connect_rewrite_102101.patch \
    && curl -fSkL --retry 5 https://github.com/arut/nginx-dav-ext-module/archive/v${NGINX_DAV_EXT_MODULE_VERSION}.tar.gz |tar xzf - -C /tmp \
    && git clone --depth=1 https://github.com/google/ngx_brotli /tmp/ngx_brotli && cd /tmp/ngx_brotli && git submodule update --init \
    && if [ -n "${RESTY_EVAL_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_PRE_CONFIGURE}); fi \
    && cd /tmp \
    && curl -fSkL --retry 5 "${RESTY_OPENSSL_URL_BASE}/openssl-${RESTY_OPENSSL_VERSION}.tar.gz" -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && cd openssl-${RESTY_OPENSSL_VERSION} \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-2) = "3." ] ; then \
        echo 'patching OpenSSL 3.x for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then \
        echo 'patching OpenSSL 1.1.1 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.0" ] ; then \
        echo 'patching OpenSSL 1.1.0 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/ed328977028c3ec3033bc25873ee360056e247cd/patches/openssl-1.1.0j-parallel_build_fix.patch | patch -p1 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ "q${TARGETARCH}" = "q386" ];then \
    ./Configure linux-elf \
    shared zlib -g \
    ${RESTY_OPENSSL_BUILD_OPTIONS} \
    --prefix=/usr/local/openresty/openssl3 \
    --libdir=lib \
    -Wl,-rpath,/usr/local/openresty/openssl3/lib; \
    else \
    ls -hal && ./config \
    shared zlib -g \
    ${RESTY_OPENSSL_BUILD_OPTIONS} \
    --prefix=/usr/local/openresty/openssl3 \
    --libdir=lib \
    -Wl,-rpath,/usr/local/openresty/openssl3/lib; \
    fi \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make -j`grep -c ^processor /proc/cpuinfo` install_sw \
    && cd /tmp \
    && curl -fSkL --retry 5 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${RESTY_PCRE_VERSION}/pcre2-${RESTY_PCRE_VERSION}.tar.gz" -o pcre2-${RESTY_PCRE_VERSION}.tar.gz \
    && echo "${RESTY_PCRE_SHA256}  pcre2-${RESTY_PCRE_VERSION}.tar.gz" | shasum -a 256 --check \
    && tar xzf pcre2-${RESTY_PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre2-${RESTY_PCRE_VERSION} \
    && CFLAGS="-g -O3" ./configure \
        --prefix=/usr/local/openresty/pcre2 \
        --libdir=/usr/local/openresty/pcre2/lib \
        ${RESTY_PCRE_BUILD_OPTIONS} \
    && CFLAGS="-g -O3" make -j`grep -c ^processor /proc/cpuinfo` \
    && CFLAGS="-g -O3" make -j`grep -c ^processor /proc/cpuinfo` install \
    && cd /tmp \
    && curl -fSkL --retry 5 https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && if [ -n "${RESTY_EVAL_POST_DOWNLOAD_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_POST_DOWNLOAD_PRE_CONFIGURE}); fi \
    && eval ./configure -j`grep -c ^processor /proc/cpuinfo` ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} ${RESTY_LUAJIT_OPTIONS} ${RESTY_PCRE_OPTIONS} \
    && patch -d build/nginx-${RESTY_VERSION%.*}/ -p 1 < /tmp/ngx_http_proxy_connect_module-${NGINX_HTTP_PROXY_CONNECT_MODULE_VERSION}/patch/proxy_connect_rewrite_102101.patch \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make -j`grep -c ^processor /proc/cpuinfo` install \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi \
    && rm -rf \
    openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
    pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
    && { find /usr/local -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && { find /usr/local -type f -name "*.so*" -exec strip --strip-all '{}' + || true; } \
    && if [ "$(command -v upx)q" != "q" ];then \
    { find /usr/local/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/luajit/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/pcre2/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/openssl3/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/nginx/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    fi \
    && find /usr/local -type f -name '*.a' -delete && find -type f -name '*.la' -delete \
    && rm -fr /usr/local/include /usr/local/share /usr/local/openresty/openssl3/include /usr/local/openresty/pcre2/share /usr/local/openresty/pcre2/include /usr/local/openresty/luajit/include /usr/local/openresty/pod /usr/local/openresty/site \
    #==============OPENRESTY-END==============
    \
    && tar cvf /tmp/pack.tar /usr/local

FROM --platform=$TARGETPLATFORM ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG} as tmp
LABEL maintainer="tofuliang <tofuliang@gmail.com>"

COPY --from=build /tmp/pack.tar /tmp/pack.tar
RUN tar xf /tmp/pack.tar -C /

FROM --platform=$TARGETPLATFORM ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG}

LABEL maintainer="tofuliang <tofuliang@gmail.com>"

ARG TARGETARCH
COPY --from=tmp /usr/local /usr/local
# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin
ENV ENV=/etc/profile

RUN set -x \
    && addgroup -g 82 -S www-data || true \
    && adduser -u 82 -D -S -G www-data www-data || true \
    && apk add --no-cache --virtual .upxd upx >/dev/null 2>&1 ||true \
    && apk add --no-cache --virtual .pack curl \
    && arch=$TARGETARCH \
    && best="--best" \
    && lzma="--lzma" \
    && if [ "q$arch" = "q386" ];then arch="i686";upxarch="i386"; fi \
    && if [ "q$arch" = "qamd64" ];then arch="x86_64";upxarch="amd64"; fi \
    && if [ "q$arch" = "qarm64" ];then arch="aarch64";upxarch="arm64";best="";lzma=""; fi \
    && if [ "q$arch" = "qarm" ];then arch="armhf";upxarch="arm";best="";lzma=""; fi \
    && while [ ! -f /init ];do \
    echo "getting s6-overlay init ..." \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://api.github.com/repos/just-containers/s6-overlay/releases/latest |grep download|grep noarch|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && while [ ! -f /command/s6-cat ];do \
    echo "getting s6-overlay package ..." \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://api.github.com/repos/just-containers/s6-overlay/releases/latest |grep download|grep ${arch}|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && apk add --no-cache logrotate sudo tzdata \
    && if [ "$(command -v upx)q" != "q" ];then \
    { find /usr/local/bin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && { find /usr/local/openresty/luajit/bin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && { find /usr/local/openresty/pcre2/bin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && { find /usr/local/openresty/openssl3/bin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && { find /usr/local/openresty/bin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && { find /usr/local/openresty/nginx/sbin -type f -perm +0111 -exec upx -d '{}' + || true; } \
    fi \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | grep so:l \
    | grep -vE 'libcrypto|libss|pcre' \
    )" \
    && apk add --no-cache --virtual .persistent-deps $runDeps musl \
    && if [ "$(command -v upx)q" != "q" ];then \
    { find /usr/local/openresty/luajit/bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/local/openresty/pcre2/bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/local/openresty/openssl3/bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/local/openresty/bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/local/openresty/nginx/sbin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /bin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -size -95k -exec upx --best '{}' + || true; } \
    && { find /usr/local/openresty/luajit/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/pcre2/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/openssl3/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/openresty/nginx/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && apk del .upxd; \
    fi \
    && apk del .pack \
    # 日志目录
    && mkdir -p /usr/local/var/log/nginx/ \
    && chown www-data:www-data -R /usr/local/var/log

ADD mm /bin/mm
ADD alias.sh /etc/profile.d/alias.sh
ADD s6/cont-init.d /etc/cont-init.d/
ADD s6/s6-overlay /etc/s6-overlay

# Expose ports
# NGINX
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/init"]

### STAGE-1-END

### PUSH-START
ARG ARCHC
FROM --platform=$TARGETPLATFORM tofuliang/docker-php-openresty:openresty127-1-${ARCHC} AS stage-3
### PUSH-END
