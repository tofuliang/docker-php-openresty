# Dockerfile - alpine
# https://github.com/openresty/docker-openresty
# https://github.com/docker-library/php
FROM alpine:3.11

MAINTAINER tofuiang <tofuliang@gmail.com>

# Docker Build Arguments
ARG RESTY_VERSION="1.15.8.2"
ARG RESTY_OPENSSL_VERSION="1.1.1c"
ARG RESTY_PCRE_VERSION="8.43"
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
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-http_iconv_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-http_degradation_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --add-module=/tmp/nginx-dav-ext-module-3.0.0/ \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"

ARG RESTY_ADD_PACKAGE_BUILDDEPS=""
ARG RESTY_ADD_PACKAGE_RUNDEPS=""
ARG RESTY_EVAL_PRE_CONFIGURE=""
ARG RESTY_EVAL_POST_MAKE=""

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib' \
    "

LABEL resty_image_base="${RESTY_IMAGE_BASE}"
LABEL resty_image_tag="${RESTY_IMAGE_TAG}"
LABEL resty_version="${RESTY_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"
LABEL resty_config_deps="${_RESTY_CONFIG_DEPS}"
LABEL resty_add_package_builddeps="${RESTY_ADD_PACKAGE_BUILDDEPS}"
LABEL resty_add_package_rundeps="${RESTY_ADD_PACKAGE_RUNDEPS}"
LABEL resty_eval_pre_configure="${RESTY_EVAL_PRE_CONFIGURE}"
LABEL resty_eval_post_make="${RESTY_EVAL_POST_MAKE}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"

ARG PHP_INI_DIR="/usr/local/etc"
# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ARG PHP_EXTRA_CONFIGURE_ARGS="--enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data"
ARG PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ARG PHP_CPPFLAGS="$PHP_CFLAGS"
ARG PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ARG GPG_KEYS="1729F83938DA44E27BA0F4D3DBDB397470D12172 B1B44D8F021E4E2D6021E995DC9FF8D3EE5AF27F"

ARG PHP_URL="https://secure.php.net/get/php- 7.3.14.tar.xz/from/this/mirror"
ARG PHP_ASC_URL="https://secure.php.net/get/php- 7.3.14.tar.xz.asc/from/this/mirror"
ARG PHP_SHA256="cc05dd373ca5d36652800762f65c10e828a17de35aaf246262e3efa99d00cdb0"
ARG PHP_MD5=""

# persistent / runtime deps
ARG PHPIZE_DEPS="\
        autoconf \
        dpkg-dev dpkg \
        file \
        g++ \
        gcc \
        libc-dev \
        make \
        pkgconf \
        re2c \
        argon2-dev \
        curl-dev \
        libedit-dev \
        libxml2-dev \
        sqlite-dev \
        coreutils \
        libressl-dev \
        libsodium-dev \
        imagemagick-dev \
        icu-dev \
        libzip-dev \
        "

ARG PHP_DEPS="\
        ca-certificates \
        curl \
        tar \
        xz \
# https://github.com/docker-library/php/issues/494
        libressl \
        imagemagick \
        graphviz \
        ttf-freefont \
        libzip \
        "

ARG OPENRESTY_BUILD_DEPS="\
        build-base \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
        "

ARG OPENRESTY_DEPS="\
        curl \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \
        "

COPY musl-fixes.patch /tmp/musl-fixes.patch
COPY fix_gcc8.patch /tmp/fix_gcc8.patch
COPY docker-php-source /usr/local/bin/
COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

# ensure www-data user exists
RUN set -x \
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data \
# 82 is the standard uid/gid for "www-data" in Alpine
# https://git.alpinelinux.org/aports/tree/main/apache2/apache2.pre-install?h=3.9-stable
# https://git.alpinelinux.org/aports/tree/main/lighttpd/lighttpd.pre-install?h=3.9-stable
# https://git.alpinelinux.org/aports/tree/main/nginx/nginx.pre-install?h=3.9-stable
    \
    && mkdir -p $PHP_INI_DIR/php/conf.d \
    \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        $OPENRESTY_BUILD_DEPS \
    && apk add --no-cache --virtual .persistent-deps \
        $PHP_DEPS \
        $OPENRESTY_DEPS \
    \
    && apk add --no-cache --virtual .fetch-deps \
        gnupg \
        openssl \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
           gnu-libiconv \
    ; \
    \
#==============PHP-START==============
    mkdir -p /usr/src; \
    cd /usr/src; \
    \
    curl -fSkL --retry 5  -o php.tar.xz "$PHP_URL"; \
    \
    if [ -n "$PHP_SHA256" ]; then \
        echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
    fi; \
    if [ -n "$PHP_MD5" ]; then \
        echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
    fi; \
    \
    if [ -n "$PHP_ASC_URL" ]; then \
        wget -O php.tar.xz.asc "$PHP_ASC_URL"; \
        export GNUPGHOME="$(mktemp -d)"; \
        for key in $GPG_KEYS; do \
            gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
        done; \
        gpg --batch --verify php.tar.xz.asc php.tar.xz; \
        command -v gpgconf > /dev/null && gpgconf --kill all; \
        rm -rf "$GNUPGHOME"; \
    fi; \
    \
    apk del .fetch-deps \
    && export CFLAGS="$PHP_CFLAGS" \
        CPPFLAGS="$PHP_CPPFLAGS" \
        LDFLAGS="$PHP_LDFLAGS" \
    && docker-php-source extract \
    && cd /usr/src/php \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && ./configure \
        --build="$gnuArch" \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/php/conf.d" \
        \
        --disable-cgi \
        \
# make sure invalid --configure-flags are fatal errors intead of just warnings
        --enable-option-checking=fatal \
        \
# https://github.com/docker-library/php/issues/439
        --with-mhash \
        \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
        --enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
        --enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
        --enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
        --with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
        --with-sodium=shared \
        \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        \
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
        $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
        \
        $PHP_EXTRA_CONFIGURE_ARGS \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make install \
    && cp /usr/src/php/php.ini-development $PHP_INI_DIR/php.ini-development \
    && cp /usr/src/php/php.ini-production $PHP_INI_DIR/php.ini-production \
    && cp /usr/src/php/php.ini-production $PHP_INI_DIR/php.ini \
    && cp $PHP_INI_DIR/php-fpm.conf.default $PHP_INI_DIR/php-fpm.conf \
    && cp $PHP_INI_DIR/php-fpm.d/www.conf.default $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/include=NONE\/etc\/php-fpm.d\/\*.conf/include=\/usr\/local\/etc\/php-fpm.d\/*.conf/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/;daemonize = yes/daemonize = no/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/user = nobody/user = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = nobody/listen.owner = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = www-data/listen.group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && make clean \
    && cd /tmp \
    && docker-php-source delete \
    \
    && runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && apk add --no-cache --virtual .php-ext-build-deps jpeg-dev libpng-dev freetype-dev libxml2-dev gettext-dev cyrus-sasl-dev bzip2-dev \
# 配置GD库,开启更多图片支持
    && docker-php-ext-configure gd --enable-gd-jis-conv --with-jpeg-dir --with-png-dir --with-zlib-dir --with-freetype-dir --with-gd \
# 安装常用扩展
    && docker-php-ext-install -j`grep -c ^processor /proc/cpuinfo` intl gd bcmath bz2 calendar dba exif gettext mysqli pdo_mysql shmop soap sockets sysvmsg sysvsem sysvshm zip \
# 从源码编译安装支持sasl的libmemcached
    && curl -fSkL --retry 5 https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz  -o /usr/src/libmemcached-1.0.18.tar.gz \
    && tar xzf /usr/src/libmemcached-1.0.18.tar.gz -C /usr/src \
    && mv /tmp/musl-fixes.patch /usr/src/libmemcached-1.0.18/musl-fixes.patch \
    && mv /tmp/fix_gcc8.patch /usr/src/libmemcached-1.0.18/fix_gcc8.patch \
    && cd /usr/src/libmemcached-1.0.18 \
    && patch -p1 -i musl-fixes.patch \
    && patch -p1 -i fix_gcc8.patch \
    && ./configure --enable-sasl && make -j`grep -c ^processor /proc/cpuinfo` && make install \
# 从源码编译安装支持sasl的memcached扩展
    && curl -fSkL --retry 5 http://pecl.php.net/get/memcached-3.1.5.tgz -o /usr/src/memcached-3.1.5.tgz \
    && tar xzf /usr/src/memcached-3.1.5.tgz -C /usr/src \
    && cd /usr/src/memcached-3.1.5 \
    && phpize && ./configure --enable-memcached --enable-memcached-json --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable memcached \
# 从源码编译安装 tideways 扩展
    && curl -fSkL --retry 5 https://github.com/tideways/php-xhprof-extension/archive/v5.0.2.tar.gz -o /usr/src/tideways-5.0.2.tar.gz \
    && tar xzf /usr/src/tideways-5.0.2.tar.gz -C /usr/src \
    && cd /usr/src/php-xhprof-extension-5.0.2 \
    && phpize && ./configure --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable tideways_xhprof \
# 使用pecl安装redis扩展
    && pecl install redis yac-2.0.3 yaf xdebug imagick \
    && cd /usr/src && pecl download swoole \
    && tar xzf /usr/src/swoole-4.4.15.tgz -C /usr/src \
    && cd /usr/src/swoole-4.4.15 \
    && phpize && ./configure --with-php-config=/usr/local/bin/php-config --enable-shared --disable-static --enable-openssl --enable-http2 --enable-mysqlnd --enable-sockets && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable redis yac yaf swoole sodium imagick \
# strip 所有扩展
    && rm -fr "/usr/local/lib/php/extensions/no-debug-non-zts-`php -i|grep 'PHP API'|sed -e 's/PHP API => //'`/opcache.a" \
    && rm -fr "/usr/local/lib/php/extensions/no-debug-non-zts-`php -i|grep 'PHP API'|sed -e 's/PHP API => //'`/sodium.a" \
    && echo 'zend_extension=opcache.so' >  /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
    && strip "/usr/local/lib/php/extensions/no-debug-non-zts-`php -i|grep 'PHP API'|sed -e 's/PHP API => //'`/"* \
# 安装composer
    && php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
# 删除源码文件
#    && { mkdir /opt || true; } && cd /opt && curl -fSkL --retry 5 https://codeload.github.com/Mirocow/pydbgpproxy/zip/master -o master.zip \
#    && unzip master.zip && rm -fr master.zip && mv pydbgpproxy-master PHPRemoteDBGp \
    && phpExtrunDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
#==============PHP-END==============
    \
#==============OPENRESTY-START==============
    \
# These are not intended to be user-specified
# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup
    && unset CFLAGS \
    && unset CPPFLAGS \
    && unset LDFLAGS \
    && cd /tmp \
    && curl -fSkL --retry 5 https://github.com/arut/nginx-dav-ext-module/archive/v3.0.0.tar.gz |tar xzf - -C /tmp \
    && if [ -n "${RESTY_EVAL_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_PRE_CONFIGURE}); fi \
    && curl -fSkL --retry 5 https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && cd openssl-${RESTY_OPENSSL_VERSION} \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then \
        echo 'patching OpenSSL 1.1.1 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.1c-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.0" ] ; then \
        echo 'patching OpenSSL 1.1.0 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/ed328977028c3ec3033bc25873ee360056e247cd/patches/openssl-1.1.0j-parallel_build_fix.patch | patch -p1 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.0d-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && ./config \
      no-threads shared zlib -g \
      enable-ssl3 enable-ssl3-method \
      --prefix=/usr/local/openresty/openssl \
      --libdir=lib \
      -Wl,-rpath,/usr/local/openresty/openssl/lib \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make -j`grep -c ^processor /proc/cpuinfo` install_sw \
    && cd /tmp \
    && curl -fSkL --retry 5 https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre-${RESTY_PCRE_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/pcre \
        --disable-cpp \
        --enable-jit \
        --enable-utf \
        --enable-unicode-properties \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make -j`grep -c ^processor /proc/cpuinfo` install \
    && cd /tmp \
    && curl -fSkL --retry 5 https://github.com/openresty/openresty/releases/download/v${RESTY_VERSION}/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && eval ./configure -j`grep -c ^processor /proc/cpuinfo` ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} ${RESTY_LUAJIT_OPTIONS} \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && make -j`grep -c ^processor /proc/cpuinfo` install \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
    && { find /usr/local/openresty -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    \
#==============OPENRESTY-END==============
    \
    && apk del .build-deps \
    && apk del .php-ext-build-deps \
    && apk add --no-cache --virtual .php-rundeps $runDeps \
    && apk add --no-cache --virtual .php-ext-rundeps $phpExtrunDeps \
    && rm -fr /usr/src/* \
    && rm -fr /tmp/* \
    && rm -fr /usr/local/include /usr/local/share/man /usr/share/gtk-doc \
    && { cd /usr/local/lib/php;rm -fr `ls -a|grep -v extensions` || true; } \
    && apk add --no-cache supervisor logrotate sudo tzdata \
#    openssh \
# 日志目录
    && mkdir -p /usr/local/var/log/php-fpm/ \
    && mkdir -p /usr/local/var/log/php_errors/ \
    && mkdir -p /usr/local/var/log/php_slow/ \
    && mkdir -p /usr/local/var/log/nginx/ \
    && chown www-data:www-data -R /usr/local/var/log
# SSH
#    && { mkdir /var/run/sshd || true; } \
#    && ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -P "" \
#    && echo "PermitRootLogin yes"  >> /etc/ssh/sshd_config

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin
ENV PYTHONPATH=$PYTHONPATH:/opt/bin/PHPRemoteDBGp/pythonlib
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

ADD etc/supervisor /etc/supervisor
ADD etc/php/conf.d /usr/local/etc/php/conf.d/
ADD etc/php/php-fpm.d /usr/local/etc/php-fpm.d/
ADD daemon /usr/local/bin/daemon

# Expose ports
# SSH
EXPOSE 22
# NGINX
EXPOSE 80
EXPOSE 443
# Xdebug
EXPOSE 9001

CMD ["/usr/local/bin/daemon"]
