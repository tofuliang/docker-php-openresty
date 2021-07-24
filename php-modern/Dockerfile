FROM alpine:3.14

LABEL maintainer="tofuiang <tofuliang@gmail.com>"

COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/bin /usr/local/bin
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/lib /usr/local/lib

COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/php80/bin /usr/local/php80/bin
COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/php80/sbin /usr/local/php80/sbin
COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/php80/lib /usr/local/php80/lib
COPY --from=tofuliang/docker-php-openresty:php80 /usr/local/etc/php80 /usr/local/etc/php80

COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/php74/bin /usr/local/php74/bin
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/php74/sbin /usr/local/php74/sbin
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/php74/lib /usr/local/php74/lib
COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/etc/php74 /usr/local/etc/php74

COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/php73/bin /usr/local/php73/bin
COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/php73/sbin /usr/local/php73/sbin
COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/php73/lib /usr/local/php73/lib
COPY --from=tofuliang/docker-php-openresty:php73 /usr/local/etc/php73 /usr/local/etc/php73

COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/php72/bin /usr/local/php72/bin
COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/php72/sbin /usr/local/php72/sbin
COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/php72/lib /usr/local/php72/lib
COPY --from=tofuliang/docker-php-openresty:php72 /usr/local/etc/php72 /usr/local/etc/php72

COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/php71/bin /usr/local/php71/bin
COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/php71/sbin /usr/local/php71/sbin
COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/php71/lib /usr/local/php71/lib
COPY --from=tofuliang/docker-php-openresty:php71 /usr/local/etc/php71 /usr/local/etc/php71

COPY --from=tofuliang/docker-php-openresty:php70 /usr/local/php70/bin /usr/local/php70/bin
COPY --from=tofuliang/docker-php-openresty:php70 /usr/local/php70/sbin /usr/local/php70/sbin
COPY --from=tofuliang/docker-php-openresty:php70 /usr/local/php70/lib /usr/local/php70/lib
COPY --from=tofuliang/docker-php-openresty:php70 /usr/local/etc/php70 /usr/local/etc/php70

RUN set -x \
    && for i in 80 74 73 72 71 70;do ln -s /usr/local/php$i/bin/php /usr/local/bin/php$i; done \
    && apk --no-cache add upx \
    && { find /usr/local  -name "php*"  -size +1024 -type f -perm +0111 -exec upx -d '{}' + || true; } \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )" \
    && { find /usr/local  -name "php*"  -size +1024 -type f -perm +0111 -exec upx '{}' + || true; } \
    && ln -s /usr/local/bin/php80 /usr/local/bin/php \
    && addgroup -g 82 -S www-data || true \
    && adduser -u 82 -D -S -G www-data www-data || true \
    && apk del upx \
    && apk add --no-cache --virtual .persistent-deps \
    $runDeps \
    && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted \
    gnu-libiconv \
    && apk add --no-cache logrotate sudo tzdata git curl busybox-extras ca-certificates tar xz \
    #    openssh \
    && curl -fSkL --retry 5 https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz| tar xfz - -C / \
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
EXPOSE 9070

ADD s6-overlay/fix-attrs.d /etc/fix-attrs.d/
ADD s6-overlay/cont-init.d /etc/cont-init.d/
ADD s6-overlay/services.d /etc/services.d/

ENTRYPOINT ["/init"]