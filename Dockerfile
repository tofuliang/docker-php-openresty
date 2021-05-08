FROM alpine:3.13

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

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

COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/bin /usr/local/bin
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/lib /usr/local/lib

COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/php80 /usr/local/php80
COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/etc/php80 /usr/local/etc/php80

COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/php74 /usr/local/php74
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/etc/php74 /usr/local/etc/php74

COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/php73 /usr/local/php73
COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/etc/php73 /usr/local/etc/php73

COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/php72 /usr/local/php72
COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/etc/php72 /usr/local/etc/php72

COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/php71 /usr/local/php71
COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/etc/php71 /usr/local/etc/php71

RUN set -x \
    && for i in 80 74 73 72 71;do rm -fr /usr/local/php$i/php;done \
    && addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data \
    && apk add --no-cache --virtual .persistent-deps \
        $PHP_DEPS \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
           gnu-libiconv \
    && apk add --no-cache supervisor logrotate sudo tzdata git \
#    openssh \
# 日志目录
    && mkdir -p /usr/local/var/log/php-fpm/ \
    && mkdir -p /usr/local/var/log/php_errors/ \
    && mkdir -p /usr/local/var/log/php_slow/ \
    && mkdir -p /usr/local/var/log/nginx/ \
    && mkdir -p /usr/local/var/log/cron \
    && chown www-data:www-data -R /usr/local/var/log

ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# fpm
EXPOSE 9080
EXPOSE 9074
EXPOSE 9073
EXPOSE 9072
EXPOSE 9071

ENTRYPOINT ["/init"]