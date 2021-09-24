# Dockerfile - alpine
# https://github.com/docker-library/php
FROM --platform=$TARGETPLATFORM alpine:3.8 AS build

LABEL maintainer="tofuiang <tofuliang@gmail.com>"
# Docker Build Arguments
ARG BRANCH="55"
ARG PHP_INI_DIR="/usr/local/etc/php${BRANCH}"

ARG TARGETARCH

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

ARG PHP_URL="https://secure.php.net/get/php-5.5.38.tar.xz/from/this/mirror"
ARG PHP_ASC_URL="https://secure.php.net/get/php-5.5.38.tar.xz.asc/from/this/mirror"
ARG PHP_SHA256="cb527c44b48343c8557fe2446464ff1d4695155a95601083e5d1f175df95580f"
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
    curl-dev \
    libedit-dev \
    libxml2-dev \
    sqlite-dev \
    coreutils \
    libressl-dev \
    imagemagick-dev \
    openldap-dev \
    unixodbc-dev \
    icu-dev \
    gmp-dev \
    imap-dev \
    freetds-dev \
    readline-dev \
    libxslt-dev \
    cyrus-sasl-dev \
    memcached-dev \
    libmemcached \
    libmemcached-dev \
    libmemcached-libs \
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
    unixodbc \
    freetds \
    "

COPY docker-php-source /usr/bin/
COPY docker-php-ext-* /usr/bin/

ENV PATH="/usr/local/php${BRANCH}/bin:/usr/local/php${BRANCH}/sbin:${PATH}"

RUN set -x \
    && mkdir -p $PHP_INI_DIR/conf.d \
    && mkdir -p $PHP_INI_DIR/php-fpm.d \
    && mkdir -p /usr/src \
    && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    && apk add --no-cache --virtual .persistent-deps \
    $PHP_DEPS \
    \
    && apk add --no-cache --virtual .fetch-deps \
    gnupg \
    openssl \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
    && apk add --no-cache --virtual .build-tidy-deps tidyhtml-dev \
    ; \
    \
    #==============PHP-START==============
    cd /usr/src; \
    \
    wget -O php.tar.xz "$PHP_URL"; \
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
    && apk add --no-cache xz \
    && curl -fSkL --retry 5 https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz -o /usr/src/libtool.tar.xz \
    && tar xJf /usr/src/libtool.tar.xz -C /usr/src \
    && cd /usr/src/libtool-2.4.6 \
    && ./configure --prefix=/usr && make -j`grep -c ^processor /proc/cpuinfo` && make install 

RUN set -x \
    && export CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
    LDFLAGS="$PHP_LDFLAGS" \
    && docker-php-source extract \
    && cd /usr/src/php \
    && ln -s /usr/include/tidybuffio.h /usr/include/buffio.h \
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
    --enable-pcntl=shared \
    --enable-option-checking=fatal \
    \
    # https://github.com/docker-library/php/issues/439
    --with-mhash=shared \
    \
    # --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
    --enable-ftp=shared \
    # --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
    --enable-mbstring \
    # --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
    --enable-mysqlnd \
    \
    --with-curl \
    --with-libedit=shared \
    --with-openssl \
    --with-zlib=shared \
    --with-xmlrpc=shared \
    --with-gmp=shared \
    --with-pdo-dblib=shared \
    --with-xsl=shared \
    --enable-wddx=shared \
    --with-imap=shared \
    --with-imap-ssl \
    --with-mssql=shared \
    --with-ldap=shared \
    --with-tidy=shared,/usr \
    --with-mysql=shared \
    --with-mysqli=shared \ 
    --with-pdo-odbc=shared,unixODBC,/usr,libodbc \
    --with-unixODBC=shared,/usr \
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
    && head -8 /usr/local/etc/php${BRANCH}/php-fpm.conf.default > $PHP_INI_DIR/php-fpm.conf \
    && sed -n '17,126p' $PHP_INI_DIR/php-fpm.conf.default >> $PHP_INI_DIR/php-fpm.conf \
    && sed -n '9,16p' $PHP_INI_DIR/php-fpm.conf.default >> $PHP_INI_DIR/php-fpm.conf \
    && sed -n '127,999p' $PHP_INI_DIR/php-fpm.conf.default > $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i "s/;include=etc\/fpm.d\/\*.conf/include=\/usr\/local\/etc\/php${BRANCH}\/php-fpm.d\/*.conf/g" $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/;daemonize = yes/daemonize = no/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/user = nobody/user = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = www-data/listen.owner = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.group = www-data/listen.group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i "s/listen = 127.0.0.1:9000/listen = 0.0.0.0:90${BRANCH}/g" $PHP_INI_DIR/php-fpm.d/www.conf \
    && { find /usr/local/bin /usr/local/php${BRANCH}/bin /usr/local/php${BRANCH}/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }

RUN set -x \
    && sed -i 's/\/usr\/local\/etc\/php\/conf.d/\/usr\/local\/etc\/php${BRANCH}\/conf.d/' /usr/bin/docker-php-ext-enable \
    # 配置GD库,开启更多图片支持
    && apk add --no-cache jpeg-dev libpng-dev freetype-dev libxml2-dev libmcrypt-dev gettext-dev bzip2-dev \
    && docker-php-ext-configure gd --enable-gd-native-ttf --enable-gd-jis-conv --with-jpeg-dir --with-png-dir --with-zlib-dir --with-freetype-dir --with-gd \
    # 安装常用扩展
    && docker-php-ext-install -j`grep -c ^processor /proc/cpuinfo` intl tidy gd bcmath bz2 calendar dba exif gettext mcrypt mysql mysqli pdo_mysql shmop soap sockets sysvmsg sysvsem sysvshm zip \
    # 从源码编译安装支持sasl的memcached扩展
    && curl -fSkL --retry 5 http://pecl.php.net/get/memcached-2.2.0.tgz -o /usr/src/memcached-2.2.0.tgz \
    && tar xzf /usr/src/memcached-2.2.0.tgz -C /usr/src \
    && cd /usr/src/memcached-2.2.0 \
    && phpize && ./configure --enable-memcached --enable-memcached-json --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable memcached \
    # 从源码编译安装 tideways 扩展
    && curl -fSkL --retry 5 https://codeload.github.com/tideways/php-profiler-extension/tar.gz/v4.1.6 -o /usr/src/tideways-4.1.6.tar.gz \
    && tar xzf /usr/src/tideways-4.1.6.tar.gz -C /usr/src \
    && cd /usr/src/php-xhprof-extension-4.1.6 \
    && phpize && ./configure --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable tideways \
    # 使用pecl安装扩展
    && pecl install redis-4.3.0 xdebug-2.5.5 imagick \
    && if [ "q$TARGETARCH" != "q386" ];then \
    pecl install swoole-1.10.5 && docker-php-ext-enable swoole; \
    fi \
    && cd /usr/src && pecl download yac-0.9.2 yaf-2.3.5 \
    && tar xf /usr/src/yac-0.9.2.tar -C /usr/src \
    && cd /usr/src/yac-0.9.2 \
    && phpize && ./configure --with-php-config=/usr/local/php${BRANCH}/bin/php-config --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && tar xf /usr/src/yaf-2.3.5.tar -C /usr/src \
    && cd /usr/src/yaf-2.3.5 \
    && phpize && ./configure --with-php-config=/usr/local/php${BRANCH}/bin/php-config --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable redis yac yaf imagick opcache ftp gmp imap ldap mssql mysql mysqli odbc pcntl pdo_odbc pdo_dblib readline tidy wddx xmlrpc xsl zlib \
    # strip 所有扩展
    && { find /usr/local/php${BRANCH}/lib -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/lib -type f -name "*.so" -exec chmod -x '{}' + || true; }
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
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted upx >/dev/null 2>&1 ||true \
    && if [ "$(command -v upx)q" != "q" ];then \
    if [ "$(echo $TARGETPLATFORM|grep -E 'amd64|386')q" != "q" ];then \
    { find /usr/local -size +1024 -type f -perm +0111 -exec upx --lzma '{}' + || true; }; \
    else \
    { find /usr/local -size +1024 -type f -perm +0111 ! -name "composer*" -exec upx --lzma '{}' + || true; }; \
    fi \
    fi \
    && tar cf /tmp/pack.tar /usr/local/bin/composer /usr/local/bin/composer1 /usr/local/php${BRANCH}/bin /usr/local/php${BRANCH}/sbin /usr/local/php${BRANCH}/lib /usr/local/etc/php${BRANCH}

FROM --platform=$TARGETPLATFORM alpine:3.8 AS tmp

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

COPY --from=build /tmp/pack.tar /tmp/pack.tar

RUN tar xf /tmp/pack.tar -C /

FROM --platform=$TARGETPLATFORM alpine:3.8

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

ARG BRANCH="55"
ARG PHP_INI_DIR="/usr/local/etc/php${BRANCH}"

ARG TARGETARCH

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
    && apk add --no-cache tidyhtml \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted --virtual .upxd upx >/dev/null 2>&1 ||true \
    && apk add --no-cache --virtual .pack dpkg \
    && if [ "$(command -v upx)q" != "q" ];then \
    { find /usr/local  -name "php*"  -size +1024 -type f -perm +0111 -exec upx -d '{}' + || true; } \
    fi \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/php${BRANCH} \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/php${BRANCH}" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | grep so:l \
    | grep -v libc.musl \
    )" \
    && apk add --no-cache logrotate sudo tzdata git tar xz curl \
    && apk add --no-cache $runDeps \
    && arch=$TARGETARCH && if [ "q$arch" = "q386" ];then arch="x86"; fi && if [ "q$arch" = "qarm64" ];then arch="aarch64"; fi \
    && curl -fSkL --retry 5 https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-${arch}.tar.gz| tar xfz - -C / \
    && if [ "$(command -v upx)q" != "q" ];then \
    if [ "$(echo $TARGETARCH|grep -E 'amd64|386')q" != "q" ];then \
    { find /usr/local -size +1024 -type f -perm +0111 -exec upx --lzma '{}' + || true; }; \
    else \
    { find /usr/local -size +1024 -type f -perm +0111 ! -name "composer*" -exec upx --lzma '{}' + || true; }; \
    fi \
    && { find /usr/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && apk del .upxd; \
    fi \
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

