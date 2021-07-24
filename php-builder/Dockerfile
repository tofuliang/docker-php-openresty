# Dockerfile - alpine
# https://github.com/docker-library/php
FROM alpine:3.14

# Docker Build Arguments

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
    openssl-dev \
    imagemagick-dev \
    icu-dev \
    libzip-dev \
    boost-dev \
    jpeg-dev libpng-dev freetype-dev libxml2-dev gettext-dev cyrus-sasl-dev bzip2-dev \
    patch \
    upx \
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
    boost-filesystem \
    "

COPY musl-fixes.patch /tmp/musl-fixes.patch
COPY fix_gcc8.patch /tmp/fix_gcc8.patch


# ensure www-data user exists
RUN set -x \
    && mkdir -p /usr/src \
    \
    && apk add --no-cache \
    $PHPIZE_DEPS \
    && apk add --no-cache \
    $PHP_DEPS \
    \
    # 从源码编译安装支持sasl的libmemcached
    && curl -fSkL --retry 5 https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz  -o /usr/src/libmemcached-1.0.18.tar.gz \
    && tar xzf /usr/src/libmemcached-1.0.18.tar.gz -C /usr/src \
    && mv /tmp/musl-fixes.patch /usr/src/libmemcached-1.0.18/musl-fixes.patch \
    && mv /tmp/fix_gcc8.patch /usr/src/libmemcached-1.0.18/fix_gcc8.patch \
    && cd /usr/src/libmemcached-1.0.18 \
    && patch -p1 -i musl-fixes.patch \
    && patch -p1 -i fix_gcc8.patch \
    && ./configure --enable-sasl && make -j`grep -c ^processor /proc/cpuinfo` && make install \
    # 删除源码文件
    && cd /usr/src/ && rm -fr *