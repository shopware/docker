#syntax=docker/dockerfile:1

FROM base AS build

USER root

RUN apk add --no-cache supervisor caddy

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENV FPM_LISTEN=/tmp/php-fpm.sock

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]

# Derived images use the build stage so this refresh cannot invalidate compilation.
FROM build AS runtime

USER root
ARG OS_PACKAGES_REFRESH
RUN echo "Refreshing OS packages: ${OS_PACKAGES_REFRESH}" \
    && apk upgrade --no-cache

USER www-data
