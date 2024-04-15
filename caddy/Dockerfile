#syntax=docker/dockerfile:1.4

ARG PHP_PATCH_VERSION

FROM ghcr.io/shopware/docker-base:${PHP_PATCH_VERSION}-fpm

USER root

RUN wget -O /etc/apk/keys/wolfi-signing.rsa.pub https://packages.wolfi.dev/os/wolfi-signing.rsa.pub && \
    apk add --no-cache --repository https://packages.wolfi.dev/os caddy && \
    ln -s /usr/bin/caddy /usr/sbin/caddy

COPY --from=shyim/supervisord:latest --link /usr/local/bin/supervisord /usr/bin/supervisord

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENV FPM_LISTEN=/tmp/php-fpm.sock

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
