# Dockerfile - alpine
# https://github.com/docker-library/php
FROM --platform=$TARGETPLATFORM alpine:3.14

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
    gmp gmp-dev \
    tidyhtml-libs tidyhtml-dev \
    enchant2 enchant2-dev \
    imap-dev openldap-dev aspell-dev net-snmp-dev libxslt-dev libffi-dev \
    libwebp libwebp-dev libxpm libxpm-dev \
    jpeg-dev libpng-dev freetype freetype-dev libxml2-dev gettext-dev cyrus-sasl-dev bzip2-dev \
    patch \
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
    openssl \
    imagemagick \
    graphviz \
    ttf-freefont \
    libzip \
    boost-filesystem \
    "

# ensure www-data user exists
RUN set -x \
    && mkdir -p /usr/src \
    \
    && apk add --no-cache \
    $PHPIZE_DEPS \
    && apk add --no-cache \
    $PHP_DEPS