#syntax=docker/dockerfile:1.4

ARG FPM_IMAGE=ghcr.io/shopware/docker-base:8.3.1-fpm

FROM chainguard/wolfi-base AS caddy-builder

RUN apk add --no-cache go xcaddy caddy-src

ENV CGO_ENABLED=0

RUN xcaddy build --with github.com/caddyserver/caddy/v2=/usr/src/caddy --with github.com/lolPants/caddy-requestid --output /usr/bin/caddy

FROM ${FPM_IMAGE}

USER root

COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy

RUN ln -s /usr/bin/caddy /usr/sbin/caddy && \
    apk add --no-cache supervisor

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENV FPM_LISTEN=/tmp/php-fpm.sock

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
