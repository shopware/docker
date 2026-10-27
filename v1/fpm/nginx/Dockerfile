#syntax=docker/dockerfile:1.4

FROM base

USER root

RUN apk add --no-cache nginx supervisor

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENV FPM_LISTEN=/tmp/php-fpm.sock

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
