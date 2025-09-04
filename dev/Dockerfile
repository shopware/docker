ARG PHP_VERSION=8.4
FROM ghcr.io/shopware/docker-base:${PHP_VERSION}-caddy-otel

ARG NODE_VERSION=22

USER root

RUN <<EOF
    set -e
    NODE_PREFIX=""

    if [[ "$NODE_VERSION" == "24" ]]; then
        NODE_PREFIX="-current"
    fi

    apk add --no-cache npm bash nodejs${NODE_PREFIX}
    install-php-extensions tideways blackfire xdebug

    cd /usr/local/etc/php/conf.d
    mv docker-php-ext-opentelemetry.ini docker-php-ext-opentelemetry.disabled
    mv docker-php-ext-xdebug.ini docker-php-ext-xdebug.disabled
    mv docker-php-ext-tideways.ini docker-php-ext-tideways.disabled
    mv docker-php-ext-blackfire.ini docker-php-ext-blackfire.disabled

    chown -R www-data:www-data /usr/local/etc/php/conf.d
EOF

USER www-data

COPY --link --from=ghcr.io/shopware/shopware-cli:bin /shopware-cli /usr/local/bin/shopware-cli
COPY --link rootfs /

ENTRYPOINT [ "/entrypoint" ]
CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]