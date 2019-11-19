# Dockerfile - alpine
# https://github.com/docker-library/php
FROM alpine:3.4

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

ARG PHP_URL="https://www.php.net/distributions/php-5.3.29.tar.bz2"
ARG PHP_ASC_URL="https://secure.php.net/get/php-5.3.29.tar.bz2.asc/from/this/mirror"
ARG PHP_SHA256="c4e1cf6972b2a9c7f2777a18497d83bf713cdbecabb65d3ff62ba441aebb0091"
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
        openssl-dev \
        openldap-dev \
        unixodbc-dev \
        icu-dev \
        gmp-dev \
        imap-dev \
        freetds-dev \
        readline-dev \
        libxslt-dev \
        mariadb-dev \
        "

ARG PHP_DEPS="\
        ca-certificates \
        curl \
        tar \
        openssl \
        graphviz \
        ttf-freefont \
        unixodbc \
        freetds \
        "

COPY musl-fixes.patch /tmp/musl-fixes.patch
COPY docker-php-source /usr/local/bin/
COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

# ensure www-data user exists
RUN set -x \
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data \
# 82 is the standard uid/gid for "www-data" in Alpine
# http://git.alpinelinux.org/cgit/aports/tree/main/apache2/apache2.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/lighttpd/lighttpd.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/nginx-initscripts/nginx-initscripts.pre-install?h=v3.3.2
    \
    && mkdir -p $PHP_INI_DIR/php/conf.d \
    \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && apk add --no-cache --virtual .persistent-deps \
        $PHP_DEPS \
    \
    && apk add --no-cache --virtual .fetch-deps \
        gnupg \
        openssl \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
           gnu-libiconv \
    && apk add --no-cache --virtual .build-tidy-deps  --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
           tidyhtml-dev \
    ; \
    \
#==============PHP-START==============
    mkdir -p /usr/src; \
    cd /usr/src; \
    \
    wget -O php.tar.bz2 "$PHP_URL"; \
    \
    if [ -n "$PHP_SHA256" ]; then \
        echo "$PHP_SHA256 *php.tar.bz2" | sha256sum -c -; \
    fi; \
    if [ -n "$PHP_MD5" ]; then \
        echo "$PHP_MD5 *php.tar.bz2" | md5sum -c -; \
    fi; \
    \
    if [ -n "$PHP_ASC_URL" ]; then \
        wget -O php.tar.bz2.asc "$PHP_ASC_URL"; \
        export GNUPGHOME="$(mktemp -d)"; \
        for key in $GPG_KEYS; do \
            gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
        done; \
        gpg --batch --verify php.tar.bz2.asc php.tar.bz2; \
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
    &&  ln -s /usr/include/tidybuffio.h /usr/include/buffio.h \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/php/conf.d" \
        \
        --disable-cgi \
        --enable-pcntl=shared \
        \
# https://github.com/docker-library/php/issues/439
        --with-mhash=shared \
        \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
        --enable-ftp=shared \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
        --enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
        --enable-mysqlnd=shared \
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
    && head -8 $PHP_INI_DIR/php-fpm.conf.default > $PHP_INI_DIR/php-fpm.conf \
    && sed -n '17,126p' $PHP_INI_DIR/php-fpm.conf.default >> $PHP_INI_DIR/php-fpm.conf \
    && sed -n '9,16p' $PHP_INI_DIR/php-fpm.conf.default >> $PHP_INI_DIR/php-fpm.conf \
    && [ ! -d $PHP_INI_DIR/php-fpm.d ] && mkdir -p $PHP_INI_DIR/php-fpm.d \
    && sed -n '127,999p' $PHP_INI_DIR/php-fpm.conf.default > $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;include=etc\/fpm.d\/\*.conf/include=\/usr\/local\/etc\/php-fpm.d\/*.conf/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/;daemonize = yes/daemonize = no/g' $PHP_INI_DIR/php-fpm.conf \
    && sed -i 's/user = nobody/user = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/group = nobody/group = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
    && sed -i 's/;listen.owner = www-data/listen.owner = www-data/g' $PHP_INI_DIR/php-fpm.d/www.conf \
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
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }'|grep -v tidy \
    )" \
    && apk add --no-cache --virtual .php-ext-build-deps jpeg-dev libpng-dev freetype-dev libxml2-dev libmcrypt-dev gettext-dev cyrus-sasl-dev bzip2-dev \
# 配置GD库,开启更多图片支持
    && docker-php-ext-configure gd --enable-gd-native-ttf --enable-gd-jis-conv --with-jpeg-dir --with-png-dir --with-zlib-dir --with-freetype-dir --with-gd \
# 安装常用扩展
    && docker-php-ext-install -j`grep -c ^processor /proc/cpuinfo` intl gd bcmath bz2 calendar dba exif gettext mcrypt mysqli pdo_mysql shmop soap sockets sysvmsg sysvsem sysvshm zip \
# 从源码编译安装支持sasl的libmemcached
    && curl -fSkL --retry 5 https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz  -o /usr/src/libmemcached-1.0.18.tar.gz \
    && tar xzf /usr/src/libmemcached-1.0.18.tar.gz -C /usr/src \
    && mv /tmp/musl-fixes.patch /usr/src/libmemcached-1.0.18/musl-fixes.patch \
    && cd /usr/src/libmemcached-1.0.18 \
    && patch -p1 -i musl-fixes.patch \
    && ./configure --enable-sasl && make -j`grep -c ^processor /proc/cpuinfo` && make install \
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
# 使用pecl安装redis扩展
    && pecl install redis-4.3.0 swoole-1.10.5 xdebug-2.2.7 ZendOpcache \
    && cd /usr/src && pecl download yac-0.9.2 yaf-2.3.5 \
    && tar xf /usr/src/yac-0.9.2.tar -C /usr/src \
    && cd /usr/src/yac-0.9.2 \
    && phpize && ./configure --with-php-config=/usr/local/bin/php-config --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && tar xf /usr/src/yaf-2.3.5.tar -C /usr/src \
    && cd /usr/src/yaf-2.3.5 \
    && phpize && ./configure --with-php-config=/usr/local/bin/php-config --enable-shared --disable-static && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    && docker-php-ext-enable redis yac yaf swoole ftp gmp imap ldap mssql mysql mysqlnd odbc pcntl pdo_odbc pdo_dblib readline tidy wddx xmlrpc xsl zlib \
# strip 所有扩展
    && echo "zend_extension=/usr/local/lib/php/extensions/`ls /usr/local/lib/php/extensions`/opcache.so" > /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
    && strip "/usr/local/lib/php/extensions/`ls /usr/local/lib/php/extensions`/"* \
    && rm -fr "/usr/local/lib/php/extensions/`ls /usr/local/lib/php/extensions`/"*.a \
# 删除源码文件
#    && { mkdir /opt || true; } && cd /opt && curl -fSkL --retry 5 https://codeload.github.com/Mirocow/pydbgpproxy/zip/master -o master.zip \
#    && unzip master.zip && rm -fr master.zip && mv pydbgpproxy-master PHPRemoteDBGp \
    && phpExtrunDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }'|grep -v tidy \
    )" \
    && apk add --no-cache --virtual .ext-tidy-deps  --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted tidyhtml \
#==============PHP-END==============
    \
    && apk del .build-deps \
    && apk del .php-ext-build-deps \
    && apk del .build-tidy-deps \
    && apk add --no-cache --virtual .php-rundeps $runDeps \
    && apk add --no-cache --virtual .php-ext-rundeps $phpExtrunDeps \
    && rm -fr /usr/src/* \
    && rm -fr /tmp/* \
    && rm -fr /usr/local/include /usr/local/share/man /usr/share/gtk-doc \
    && { cd /usr/local/lib/php;rm -fr `ls -a|grep -v extensions` || true; } \
    && apk add --no-cache supervisor logrotate sudo \
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
