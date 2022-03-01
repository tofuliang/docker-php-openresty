### ARG-BEGIN
ARG BRANCH="73"
ARG ARCHC
ARG PHP_INI_DIR="/usr/local/etc/php${BRANCH}"
ARG TARGETARCH
ARG LOG_FILE="/tmp/${BRANCH}.base.${TARGETARCH}.log"
### ARG-END

### STAGE-1-BEGIN

# Dockerfile - alpine
# https://github.com/docker-library/php
FROM --platform=$TARGETPLATFORM tofuliang/docker-php-openresty:php-builder AS build
ARG BRANCH
ARG ARCHC
ARG PHP_INI_DIR
ARG TARGETARCH
ARG LOG_FILE
# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ARG PHP_EXTRA_CONFIGURE_ARGS="--enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --prefix=/usr/local/php${BRANCH}"
ARG PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ARG PHP_CPPFLAGS="$PHP_CFLAGS"
ARG PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

ARG GPG_KEYS="1729F83938DA44E27BA0F4D3DBDB397470D12172 B1B44D8F021E4E2D6021E995DC9FF8D3EE5AF27F"

ARG PHP_URL="https://secure.php.net/get/php-7.3.33.tar.xz/from/this/mirror"
ARG PHP_ASC_URL="https://secure.php.net/get/php-7.3.33.tar.xz.asc/from/this/mirror"
ARG PHP_SHA256="166eaccde933381da9516a2b70ad0f447d7cec4b603d07b9a916032b215b90cc"
ARG PHP_MD5=""

COPY docker-php-source /usr/bin/
COPY docker-php-ext-* /usr/bin/

ARG JOBS=2
ENV PATH="/usr/local/php${BRANCH}/bin:/usr/local/php${BRANCH}/sbin:${PATH}"

RUN set -x && echo $TARGETARCH \
    && apk upgrade --no-cache \
    && mkdir -p $PHP_INI_DIR/conf.d \
    && mkdir -p $PHP_INI_DIR/php-fpm.d \
    && mkdir -p /usr/src \
    \
    && cd /usr/src; \
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
    fi;
RUN set -x && echo $TARGETARCH \
    && export CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
    LDFLAGS="$PHP_LDFLAGS" \
    && docker-php-source extract \
    && cd /usr/src/php \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && ./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --sysconfdir="$PHP_INI_DIR" \
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
    $(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
    \
    $PHP_EXTRA_CONFIGURE_ARGS >> ${LOG_FILE} 2>&1 \
    && make -j$JOBS >> ${LOG_FILE} 2>&1 \
    && find -type f -name '*.a' -delete \
    && make install >> ${LOG_FILE} 2>&1 \
    && cp /usr/src/php/php.ini-development $PHP_INI_DIR/php.ini-development \
    && cp /usr/src/php/php.ini-production $PHP_INI_DIR/php.ini-production \
    && cp /usr/src/php/php.ini-production $PHP_INI_DIR/php.ini \
    && cp /usr/local/etc/php${BRANCH}/php-fpm.conf.default $PHP_INI_DIR/php-fpm.conf \
    && cp /usr/local/etc/php${BRANCH}/php-fpm.d/www.conf.default $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/include=NONE\/etc\/php-fpm.d\/\*.conf/include=\/usr\/local\/etc\/php${BRANCH}\/php-fpm.d\/*.conf/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/;daemonize = yes/daemonize = no/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/user = nobody/user = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = nobody/listen.owner = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = www-data/listen.group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i "s/listen = 127.0.0.1:9000/listen = 0.0.0.0:90${BRANCH}/g" $PHP_INI_DIR/php-fpm.d/www.conf \
    && { find /usr/local/bin /usr/local/php${BRANCH}/bin /usr/local/php${BRANCH}/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }

RUN set -x && echo $TARGETARCH \
    # 配置GD库,开启更多图片支持
    && docker-php-ext-configure gd --with-webp-dir --with-jpeg-dir --with-xpm-dir --with-png-dir --with-zlib-dir --with-freetype-dir --with-gd >> ${LOG_FILE} 2>&1 \
    # 安装常用扩展
    && docker-php-ext-install -j$JOBS gd >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS intl >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS bcmath >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS bz2 >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS calendar >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS dba >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS exif >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS gettext >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS gmp >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS imap >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS ldap >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS mysqli >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS pcntl >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS pdo_mysql >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS pspell >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS shmop >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS snmp >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS soap >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS sockets >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS sysvmsg >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS sysvsem >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS sysvshm >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS tidy >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS xsl >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-install -j$JOBS zip >> ${LOG_FILE} 2>&1
# 从源码编译安装支持sasl的memcached扩展
RUN set -x && echo $TARGETARCH \
    && curl -fSkL --retry 5 http://pecl.php.net/get/memcached-3.1.5.tgz -o /usr/src/memcached-3.1.5.tgz \
    && tar xzf /usr/src/memcached-3.1.5.tgz -C /usr/src \
    && cd /usr/src/memcached-3.1.5 \
    && phpize >> ${LOG_FILE} 2>&1 && ./configure --enable-memcached --enable-memcached-json --enable-shared --disable-static >> ${LOG_FILE} 2>&1 \
    && make -j$JOBS >> ${LOG_FILE} 2>&1 && make install >> ${LOG_FILE} 2>&1

RUN set -x && echo $TARGETARCH \
    # 从源码编译安装 tideways 扩展
    && curl -fSkL --retry 5 https://github.com/tideways/php-xhprof-extension/archive/v5.0.4.tar.gz -o /usr/src/tideways-5.0.4.tar.gz \
    && tar xzf /usr/src/tideways-5.0.4.tar.gz -C /usr/src \
    && cd /usr/src/php-xhprof-extension-5.0.4 \
    && phpize >> ${LOG_FILE} 2>&1 && ./configure --enable-shared --disable-static >> ${LOG_FILE} 2>&1 \
    && make -j$JOBS >> ${LOG_FILE} 2>&1 && make install >> ${LOG_FILE} 2>&1 \
    && docker-php-ext-enable tideways_xhprof
### STAGE-1-END

### STAGE-2-BEGIN
ARG BRANCH
ARG ARCHC
ARG PHP_INI_DIR
ARG TARGETARCH
ARG LOG_FILE
ARG JOBS=2

# 使用pecl安装扩展
ARG MAKE="make -j$JOBS"
RUN set -x && echo $TARGETARCH \
    && pecl install grpc >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install redis >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install yac >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install yaf >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install xdebug >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install mongodb >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && pecl install imagick >> ${LOG_FILE} 2>&1
RUN set -x && echo $TARGETARCH \
    && if [ "q$TARGETARCH" != "q386" ];then \
    cd /usr/src && pecl download swoole-4.8.7 \
    && tar xzf /usr/src/swoole-4.8.7.tgz -C /usr/src \
    && cd /usr/src/swoole-4.8.7 \
    && phpize >> ${LOG_FILE} 2>&1 && ./configure --enable-shared --disable-static --enable-openssl --enable-http2 --enable-mysqlnd --enable-sockets >> ${LOG_FILE} 2>&1 \
    && make -j$JOBS >> ${LOG_FILE} 2>&1 && make install >> ${LOG_FILE} 2>&1 \
    && docker-php-ext-enable swoole; \
    fi
#    && curl -fSkL --retry 5 https://github.com/swoole/yasd/archive/refs/tags/v0.3.7.tar.gz -o /usr/src/yasd.tar.gz \
#    && tar xzf /usr/src/yasd.tar.gz -C /usr/src \
#    && cd /usr/src/yasd-0.3.7 \
#    && phpize --clean && phpize && ./configure && make -j$JOBS \
#    && cp /usr/src/yasd-0.3.7/modules/yasd.so "/usr/local/php${BRANCH}/lib/php/extensions/no-debug-non-zts-`php -ni|grep 'PHP Extension ='|sed -e 's/PHP Extension => //'`/yasd.so" \
RUN set -x && echo $TARGETARCH \
    && docker-php-ext-enable grpc memcached redis yac yaf sodium mongodb imagick opcache.so \
    # strip 所有扩展
    && { find /usr/local/php${BRANCH}/lib -type f -name "*.so" -exec strip --strip-all '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/lib -type f -name "*.so" -exec chmod -x '{}' + || true; }
RUN set -x && echo $TARGETARCH \
    # 安装composer
    && while [ ! -f composer-setup.php ];do \
    echo "getting composer-setup.php ..." \
    && curl -fSkL --retry 5 https://install.phpcomposer.com/installer -o composer-setup.php; \
    done \
    && while [ ! -f /usr/local/bin/composer1 ];do \
    echo "getting composer1 ..." \
    && php composer-setup.php --1 --filename=composer1 --install-dir=/usr/local/bin; \
    done \
    && while [ ! -f /usr/local/bin/composer ];do \
    echo "getting composer ..." \
    && php composer-setup.php --2 --filename=composer --install-dir=/usr/local/bin; \
    done \
    && php -r "unlink('composer-setup.php');" \
    # 删除源码文件
    #    && { mkdir /opt || true; } && cd /opt && curl -fSkL --retry 5 https://codeload.github.com/Mirocow/pydbgpproxy/zip/master -o master.zip \
    #    && unzip master.zip && rm -fr master.zip && mv pydbgpproxy-master PHPRemoteDBGp \
    && cd /usr/local && find -type f -name '*.a' -delete && find -type f -name '*.la' -delete \
    && { cd /usr/local/php${BRANCH}/lib/php;rm -fr `ls -a|grep -v extensions` || true; }

RUN set -x && echo $TARGETARCH \
    && arch=$TARGETARCH \
    && if [ "q$arch" = "q386" ];then upxarch="i386"; fi \
    && if [ "q$arch" = "qamd64" ];then upxarch="amd64"; fi \
    && if [ "q$arch" = "qarm64" ];then upxarch="arm64"; fi \
    && if [ "q$arch" = "qarm" ];then upxarch="arm"; fi \
    && while [ ! -f /usr/bin/upx ];do \
    echo "getting upx package ..." \
    && mkdir -p /tmp/upxd || true \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/upx/upx/releases |grep download|grep ${upxarch}_|grep -oE '/upx.*xz'|head -1)| tar xJf - -C /tmp/upxd \
    && mv "$(find /tmp/upxd -name 'upx' -type f)" /usr/bin/ && rm -fr /tmp/upxd; \
    done \
    && while [ ! -f /upx_amd64.core ];do \
    echo "getting amd64 upx package ..." \
    && mkdir -p /tmp/upxamd64 || true \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/upx/upx/releases |grep download|grep amd64_|grep -oE '/upx.*xz'|head -1)| tar xJf - -C /tmp/upxamd64 \
    && "$(find /tmp/upxamd64 -name 'upx' -type f)" -d /usr/bin/upx && touch /upx_amd64.core && rm -fr /tmp/upxamd64; \
    done \
    && if [ "$(command -v upx)q" != "q" ];then \
    if [ "$(echo $TARGETARCH|grep -E 'amd64|386')q" != "q" ];then \
    { find /usr/local -size +1024 -type f -perm +0111 -exec upx --lzma '{}' + || true; }; \
    else \
    { find /usr/local -size +1024 -type f -perm +0111 ! -name "composer*" -exec upx --lzma '{}' + || true; }; \
    fi \
    fi \
    && tar cf /tmp/pack.tar /usr/local/bin/composer /usr/local/bin/composer1 /usr/local/php${BRANCH}/bin /usr/local/php${BRANCH}/sbin /usr/local/php${BRANCH}/lib /usr/local/etc/php${BRANCH}
### STAGE-2-END

### STAGE-3-BEGIN
ARG BRANCH
ARG ARCHC
ARG PHP_INI_DIR
ARG TARGETARCH

FROM --platform=$TARGETPLATFORM alpine:3.14 AS tmp

COPY --from=stage-2 /tmp/pack.tar /tmp/pack.tar

RUN tar xf /tmp/pack.tar -C /

FROM --platform=$TARGETPLATFORM alpine:3.14
ARG BRANCH
ARG ARCHC
ARG PHP_INI_DIR
ARG TARGETARCH

LABEL maintainer="tofuliang <tofuliang@gmail.com>"

COPY --from=tmp /usr/local /usr/local

ADD etc/php/conf.d ${PHP_INI_DIR}/conf.d/
ADD etc/php/php-fpm.d ${PHP_INI_DIR}/php-fpm.d/
ADD s6/cont-init.d /etc/cont-init.d/
ADD s6/s6-overlay /etc/s6-overlay

ENV PATH="/usr/local/bin:/usr/local/php${BRANCH}/bin:/usr/local/php${BRANCH}/sbin:${PATH}"

RUN set -x && echo $TARGETARCH \
    && addgroup -g 82 -S www-data || true \
    && adduser -u 82 -D -S -G www-data www-data || true \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
    && apk add --no-cache --virtual .imagemagick_runtime imagemagick \
    && apk add --no-cache logrotate sudo tzdata git busybox-extras tar xz curl \
    && arch=$TARGETARCH \
    && best="--best" \
    && lzma="--lzma" \
    && if [ "q$arch" = "q386" ];then arch="i686";upxarch="i386"; fi \
    && if [ "q$arch" = "qamd64" ];then arch="x86_64";upxarch="amd64"; fi \
    && if [ "q$arch" = "qarm64" ];then arch="aarch64";upxarch="arm64";best="";lzma=""; fi \
    && if [ "q$arch" = "qarm" ];then arch="armhf";upxarch="arm";best="";lzma=""; fi \
    && while [ ! -f /usr/bin/upx ];do \
    echo "getting upx package ..." \
    && mkdir -p /tmp/upxd || true \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/upx/upx/releases |grep download|grep ${upxarch}_|grep -oE '/upx.*xz'|head -1)| tar xJf - -C /tmp/upxd \
    && mv "$(find /tmp/upxd -name 'upx' -type f)" /usr/bin/ && rm -fr /tmp/upxd; \
    done \
    && while [ ! -f /upx_amd64.core ];do \
    echo "getting amd64 upx package ..." \
    && mkdir -p /tmp/upxamd64 || true \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/upx/upx/releases |grep download|grep amd64_|grep -oE '/upx.*xz'|head -1)| tar xJf - -C /tmp/upxamd64 \
    && "$(find /tmp/upxamd64 -name 'upx' -type f)" -d /usr/bin/upx && touch /upx_amd64.core && rm -fr /tmp/upxamd64; \
    done \
    && if [ "$(command -v upx)q" != "q" ];then \
    { find /usr/local  -name "php*" -type f -perm +0111 -exec upx -d '{}' + || true; } \
    fi \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/php${BRANCH} \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/php${BRANCH}" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | grep so:l \
    | grep -v libc.musl \
    )" \
    && apk add --no-cache --virtual .persistent-deps $runDeps musl \
    && while [ ! -f /init ];do \
    echo "getting s6-overlay init ..." \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/just-containers/s6-overlay/releases |grep download|grep noarch|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && while [ ! -f /command/s6-cat ];do \
    echo "getting s6-overlay package ..." \
    && curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/just-containers/s6-overlay/releases |grep download|grep ${arch}|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && if [ "$(command -v upx)q" != "q" ] && [ "$(echo $TARGETARCH|grep -E 'amd64|386')q" != "q" ];then \
    if [ "$(echo $TARGETARCH|grep -E 'amd64|386')q" != "q" ];then \
    { find /usr/local -size -95k -type f -perm +0111 -exec upx ${best} '{}' + || true; }; \
    { find /usr/local -type f -perm +0111 -exec upx ${lzma} '{}' + || true; }; \
    else \
    { find /usr/local -size +1024 -type f -perm +0111 ! -name "composer*" -exec upx ${lzma} '{}' + || true; }; \
    fi \
    && { find /usr/bin -size -95k -type f -perm +0111 -exec upx ${best} '{}' + || true; } \
    && { find /package -size -95k -type f -perm +0111 -exec upx ${best} '{}' + || true; } \
    && { find /usr/sbin -size -95k -type f -perm +0111 -exec upx ${best} '{}' + || true; } \
    && { find /bin -type f -size -95k -perm +0111 -exec upx ${best} '{}' + || true; } \
    && { find /sbin -type f -size -95k -perm +0111 -exec upx ${best} '{}' + || true; } \
    && { find /usr/bin -type f -perm +0111 -exec upx ${lzma} '{}' + || true; } \
    && { find /package -type f -perm +0111 -exec upx ${lzma} '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -exec upx ${lzma} '{}' + || true; } \
    && { find /bin -type f -perm +0111 -exec upx ${lzma} '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -exec upx ${lzma} '{}' + || true; } \
    fi \
    && apk del libc-utils || true \
    && rm -fr /usr/bin/upx || true \
    && rm -fr /*.core;
# 日志目录
RUN set -x && echo $TARGETARCH \
    && mkdir -p /usr/local/var/log/php-fpm/ \
    && mkdir -p /usr/local/var/log/php_errors/ \
    && mkdir -p /usr/local/var/log/php_slow/ \
    && mkdir -p /usr/local/var/log/nginx/ \
    && mkdir -p /usr/local/var/log/cron/ \
    && chown www-data:www-data -R /usr/local/var/log \
    && echo "" >> /etc/s6-overlay/s6-rc.d/php-fpm/run \
    && echo "/usr/local/php${BRANCH}/sbin/php-fpm" >> /etc/s6-overlay/s6-rc.d/php-fpm/run \
    && chmod a+x /etc/cont-init.d/*

# Add additional binaries into PATH for convenience
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# Expose ports
# fpm
EXPOSE 90${BRANCH}

ENTRYPOINT ["/init"]

### STAGE-3-END

### PUSH-START
FROM --platform=$TARGETPLATFORM tofuliang/docker-php-openresty:php${BRANCH}-3-${ARCHC} AS stage-3
### PUSH-END
