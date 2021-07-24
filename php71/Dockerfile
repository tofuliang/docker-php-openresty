
# Dockerfile - alpine
# https://github.com/docker-library/php
FROM tofuliang/docker-php-openresty:php-builder AS build

# Docker Build Arguments
ARG BRANCH="71"
ARG PHP_INI_DIR="/usr/local/etc/php${BRANCH}"
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

ARG GPG_KEYS="A917B1ECDA84AEC2B568FED6F50ABC807BD5DCD0 528995BFEDFBA7191D46839EF9BA0ADA31CBD89E"

ARG PHP_URL="https://secure.php.net/get/php-7.1.33.tar.xz/from/this/mirror"
ARG PHP_ASC_URL="https://secure.php.net/get/php-7.1.33.tar.xz.asc/from/this/mirror"
ARG PHP_SHA256="657cf6464bac28e9490c59c07a2cf7bb76c200f09cfadf6e44ea64e95fa01021"
ARG PHP_MD5=""

COPY docker-php-source /usr/bin/
COPY docker-php-ext-* /usr/bin/

ENV PATH="/usr/local/php${BRANCH}/bin:/usr/local/php${BRANCH}/sbin:${PATH}"

RUN set -x \
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
RUN set -x \
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
    $PHP_EXTRA_CONFIGURE_ARGS \
    && make -j`grep -c ^processor /proc/cpuinfo` \
    && find -type f -name '*.a' -delete \
    && make install \
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

RUN set -x \
    && apk --no-cache add libmcrypt-dev unixodbc unixodbc-dev \
    # 配置GD库,开启更多图片支持
    && docker-php-ext-configure gd --enable-gd-native-ttf --enable-gd-jis-conv --with-jpeg-dir --with-png-dir --with-zlib-dir --with-freetype-dir --with-gd \
    # 安装常用扩展
    && docker-php-ext-install -j`grep -c ^processor /proc/cpuinfo` intl gd bcmath bz2 calendar dba exif gettext mcrypt mysqli pdo_mysql shmop soap sockets sysvmsg sysvsem sysvshm zip \
    # 从源码编译安装支持sasl的memcached扩展
    && curl -fSkL --retry 5 http://pecl.php.net/get/memcached-3.1.5.tgz -o /usr/src/memcached-3.1.5.tgz \
    && tar xzf /usr/src/memcached-3.1.5.tgz -C /usr/src \
    && cd /usr/src/memcached-3.1.5 \
    && phpize && ./configure --enable-memcached --enable-memcached-json --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    # 从源码编译安装 tideways 扩展
    && curl -fSkL --retry 5 https://github.com/tideways/php-xhprof-extension/archive/v5.0.4.tar.gz -o /usr/src/tideways-5.0.4.tar.gz \
    && tar xzf /usr/src/tideways-5.0.4.tar.gz -C /usr/src \
    && cd /usr/src/php-xhprof-extension-5.0.4 \
    && phpize && ./configure --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    # 使用pecl安装扩展
    && pecl install redis yac yaf xdebug-2.9.8 mongodb imagick \
    && cd /usr/src && pecl download swoole-4.5.10 \
    && tar xzf /usr/src/swoole-4.5.10.tgz -C /usr/src \
    && cd /usr/src/swoole-4.5.10 \
    && phpize && ./configure --enable-shared --disable-static --enable-openssl --enable-http2 --enable-mysqlnd --enable-sockets && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable tideways_xhprof.so memcached.so redis.so yac.so yaf.so swoole.so imagick.so opcache.so mongodb.so \
    # strip 所有扩展
    && { find /usr/local/php${BRANCH}/lib -type f -name "*.so" -exec strip --strip-all '{}' + || true; } 
RUN set -x \
    # 安装composer
    && php -r "copy('https://install.phpcomposer.com/installer', 'composer-setup.php');" \
    && php composer-setup.php --1 --filename=composer1 --install-dir=/usr/local/bin \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    # 删除源码文件
    #    && { mkdir /opt || true; } && cd /opt && curl -fSkL --retry 5 https://codeload.github.com/Mirocow/pydbgpproxy/zip/master -o master.zip \
    #    && unzip master.zip && rm -fr master.zip && mv pydbgpproxy-master PHPRemoteDBGp \
    && cd /usr/local && find -type f -name '*.a' -delete && find -type f -name '*.la' -delete \
    && { cd /usr/local/php${BRANCH}/lib/php;rm -fr `ls -a|grep -v extensions` || true; }

RUN set -x \
    && apk add --no-cache --virtual .runupx upx  \
    && { find /usr/local/bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && tar cf /tmp/pack.tar /usr/local/bin/composer /usr/local/bin/composer1 /usr/local/lib/libhashkit.so* /usr/local/lib/libmemcached.so* /usr/local/lib/libmemcachedutil.so* /usr/local/php${BRANCH}/bin /usr/local/php${BRANCH}/sbin /usr/local/php${BRANCH}/lib /usr/local/etc/php${BRANCH}

FROM alpine:3.14 AS tmp

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

COPY --from=build /tmp/pack.tar /tmp/pack.tar

RUN tar xf /tmp/pack.tar -C /

FROM alpine:3.14

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

ARG BRANCH="71"
ARG PHP_INI_DIR="/usr/local/etc/php${BRANCH}"

COPY --from=tmp /usr/local /usr/local

ADD etc/php/conf.d ${PHP_INI_DIR}/conf.d/
ADD etc/php/php-fpm.d ${PHP_INI_DIR}/php-fpm.d/
ADD s6-overlay/fix-attrs.d /etc/fix-attrs.d/
ADD s6-overlay/cont-init.d /etc/cont-init.d/
ADD s6-overlay/services.d /etc/services.d/

ENV PATH="/usr/local/bin:/usr/local/php${BRANCH}/bin:/usr/local/php${BRANCH}/sbin:${PATH}"

RUN set -x \
    && addgroup -g 82 -S www-data || true \
    && adduser -u 82 -D -S -G www-data www-data || true \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
    && apk add --no-cache --virtual .runupx upx  \
    && { find /usr/local  -name "php*" -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/php${BRANCH} \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/php${BRANCH}" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | grep so:l \
    | grep -v libmemcache \
    )" \
    && apk add --no-cache logrotate sudo tzdata git busybox-extras tar xz curl \
    && apk add --no-cache --virtual .persistent-deps $runDeps \
    && curl -fSkL --retry 5 https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz| tar xfz - -C / \
    && { find /usr/local/bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /bin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && apk del .runupx \
    # 日志目录
    && mkdir -p /usr/local/var/log/php-fpm/ \
    && mkdir -p /usr/local/var/log/php_errors/ \
    && mkdir -p /usr/local/var/log/php_slow/ \
    && mkdir -p /usr/local/var/log/nginx/ \
    && chown www-data:www-data -R /usr/local/var/log \
    && echo "exec /usr/local/php${BRANCH}/sbin/php-fpm" >> /etc/services.d/php-fpm/run

# Add additional binaries into PATH for convenience
ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# Expose ports
# fpm
EXPOSE 90${BRANCH}

ENTRYPOINT ["/init"]

