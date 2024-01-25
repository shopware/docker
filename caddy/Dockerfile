#syntax=docker/dockerfile:1.4

ARG PHP_PATCH_VERSION

FROM ghcr.io/shopware/docker-base:${PHP_PATCH_VERSION}-fpm

USER root

RUN apk add --no-cache caddy && \
    ln -s /usr/sbin/caddy /usr/bin/caddy

COPY --from=shyim/supervisord:latest --link /usr/local/bin/supervisord /usr/bin/supervisord

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENV FPM_LISTEN=/tmp/php-fpm.sock

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
