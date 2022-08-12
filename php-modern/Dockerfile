FROM --platform=$TARGETPLATFORM alpine:3.14

LABEL maintainer="tofuliang <tofuliang@gmail.com>"

ARG TARGETARCH

COPY --from=tofuliang/docker-php-openresty:php74 /usr/local/bin /usr/local/bin

COPY --from=tofuliang/docker-php-openresty:php81 /usr/local/php81/bin /usr/local/php81/bin
COPY --from=tofuliang/docker-php-openresty:php81 /usr/local/php81/sbin /usr/local/php81/sbin
COPY --from=tofuliang/docker-php-openresty:php81 /usr/local/php81/lib /usr/local/php81/lib
COPY --from=tofuliang/docker-php-openresty:php81 /usr/local/etc/php81 /usr/local/etc/php81

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

ADD s6/cont-init.d /etc/cont-init.d/
ADD s6/s6-overlay /etc/s6-overlay

RUN set -x \
    && addgroup -g 82 -S www-data || true \
    && adduser -u 82 -D -S -G www-data www-data || true \
    && for i in 81 80 74 73 72 71 70;do ln -s /usr/local/php$i/bin/php /usr/local/bin/php$i; done \
    && apk add --no-cache logrotate sudo tzdata git openssh-client busybox-extras tar xz curl \
    && apk add --no-cache --virtual .imagemagick_runtime imagemagick \
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
    { find /usr/local  -name "php*"  -size +1024 -type f -perm +0111 -exec upx -d '{}' + || true; } \
    fi \
    && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | grep so:l \
    | grep -v libc.musl \
    )" \
    && apk add --no-cache --virtual .persistent-deps $runDeps musl \
    && while [ ! -f /init ];do \
    curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/just-containers/s6-overlay/releases |grep download|grep noarch|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && while [ ! -f /command/s6-cat ];do \
    curl --output - -fSkL --retry 5 https://github.com$(curl https://github.com/just-containers/s6-overlay/releases |grep download|grep ${arch}|grep -oE '/just.*xz'|head -1)| tar xJf - -C /; \
    done \
    && if [ "$(command -v upx)q" != "q" ];then \
    if [ "$(echo $TARGETARCH|grep -E 'amd64|386')q" != "q" ];then \
    { find /usr/local -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; }; \
    { find /usr/local -type f -perm +0111 -exec upx --lzma '{}' + || true; }; \
    else \
    { find /usr/local/bin -size +1024 -type f -perm +0111 ! -name "composer*" -exec upx --lzma '{}' + || true; }; \
    fi \
    && { find /usr/local/sbin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/bin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/sbin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/bin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/sbin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /bin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /sbin -size -95k -type f -perm +0111 -exec upx --best '{}' + || true; } \
    && { find /usr/local/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/local/php${BRANCH}/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /usr/sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /bin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    && { find /sbin -type f -perm +0111 -exec upx --lzma '{}' + || true; } \
    fi \
    && apk del libc-utils || true \
    && rm -fr /usr/bin/upx || true \
    && rm -fr /*.core \
    # 日志目录
    && mkdir -p /usr/local/var/log/php-fpm/ \
    && mkdir -p /usr/local/var/log/php_errors/ \
    && mkdir -p /usr/local/var/log/php_slow/ \
    && mkdir -p /usr/local/var/log/nginx/ \
    && mkdir -p /usr/local/var/log/cron \
    && chown www-data:www-data -R /usr/local/var/log \
    && chmod a+x /etc/cont-init.d/*

ENV LD_PRELOAD=/usr/lib/preloadable_libiconv.so

# fpm
EXPOSE 9081
EXPOSE 9080
EXPOSE 9074
EXPOSE 9073
EXPOSE 9072
EXPOSE 9071
EXPOSE 9070

ENTRYPOINT ["/init"]