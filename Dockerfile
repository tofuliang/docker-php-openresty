# Dockerfile - alpine
# https://github.com/openresty/docker-openresty
# https://github.com/docker-library/php
FROM alpine:3.11

MAINTAINER tofuiang <tofuliang@gmail.com>

# Docker Build Arguments

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

ARG PHP_URL="https://secure.php.net/get/php-7.4.13.tar.xz/from/this/mirror"
ARG PHP_ASC_URL="https://secure.php.net/get/php-7.4.13.tar.xz.asc/from/this/mirror"
ARG PHP_SHA256="aead303e3abac23106529560547baebbedba0bb2943b91d5aa08fff1f41680f4"
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
        coreutils \
        curl-dev \
        libedit-dev \
        libsodium-dev \
        libxml2-dev \
        linux-headers \
        oniguruma-dev \
        openssl-dev \
        sqlite-dev \
        libressl-dev \
        imagemagick-dev \
        icu-dev \
        libzip-dev \
        "

ARG PHP_DEPS="\
        ca-certificates \
        curl \
        tar \
        xz \
        openssl \
        imagemagick \
        graphviz \
        ttf-freefont \
        libzip \
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
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
        --with-pdo-sqlite=/usr \
        --with-sqlite3=/usr \
        \
        --with-curl \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        \
# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear") and will be removed in PHP 8+; see also https://github.com/docker-library/php/issues/846#issuecomment-505638494
        --with-pear \
        \
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
        $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
        \
        $PHP_EXTRA_CONFIGURE_ARGS \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && find -type f -name '*.a' -delete \
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
    && sed -i 's/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/g' $PHP_INI_DIR/php-fpm.d/www.conf \
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
    && cd /usr/src && pecl download swoole-4.5.8 \
    && tar xzf /usr/src/swoole-4.5.8.tgz -C /usr/src \
    && cd /usr/src/swoole-4.5.8 \
    && phpize && ./configure --with-php-config=/usr/local/bin/php-config --enable-shared --disable-static --enable-openssl --enable-http2 --enable-mysqlnd --enable-sockets && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && curl -fSkL --retry 5 https://github.com/swoole/sdebug/archive/sdebug_2_9-beta.tar.gz -o /usr/src/sdebug_2_9-beta.tar.gz \
    && tar xzf /usr/src/sdebug_2_9-beta.tar.gz -C /usr/src \
    && cd /usr/src/sdebug-sdebug_2_9-beta \
    && phpize && ./configure --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` \
    && cp /usr/src/sdebug-sdebug_2_9-beta/modules/xdebug.so "/usr/local/lib/php/extensions/no-debug-non-zts-`php -i|grep 'PHP API'|sed -e 's/PHP API => //'`/sdebug.so" \
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
    && cd /usr/local && find -type f -name '*.a' -delete \
#==============PHP-END==============
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
#ENV PYTHONPATH=$PYTHONPATH:/opt/bin/PHPRemoteDBGp/pythonlib
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

ADD etc/supervisor /etc/supervisor
ADD etc/php/conf.d /usr/local/etc/php/conf.d/
ADD etc/php/php-fpm.d /usr/local/etc/php-fpm.d/
ADD daemon /usr/local/bin/daemon

# Expose ports
# SSH
#EXPOSE 22
# Xdebug
#EXPOSE 9001
# fpm
EXPOSE 9000

CMD ["/usr/local/bin/daemon"]
