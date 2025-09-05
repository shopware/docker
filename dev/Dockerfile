FROM base

ARG NODE_VERSION=22

USER root

RUN <<EOF
    set -e

    if [[ "$NODE_VERSION" == "24" ]]; then
        apk add \
            --no-cache \
            --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
            nodejs-current npm
    else
        apk add \
            --no-cache \
            --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
            nodejs npm
    fi

    apk add --no-cache npm bash
    install-php-extensions tideways blackfire xdebug

    cd /usr/local/etc/php/conf.d
    mv docker-php-ext-opentelemetry.ini docker-php-ext-opentelemetry.disabled
    mv docker-php-ext-xdebug.ini docker-php-ext-xdebug.disabled
    mv docker-php-ext-tideways.ini docker-php-ext-tideways.disabled
    mv docker-php-ext-blackfire.ini docker-php-ext-blackfire.disabled

    chown -R www-data:www-data /usr/local/etc/php/conf.d

    INSTALLED_NODE_VERSION=$(node -e "console.log(process.versions.node.substr(0,2))")
    if [[ "$INSTALLED_NODE_VERSION" != "$NODE_VERSION" ]]; then
        echo "ERROR: Installed Node.js version ($INSTALLED_NODE_VERSION) does not match expected version ($NODE_VERSION)"
        exit 1
    fi
EOF

USER www-data

COPY --link --from=ghcr.io/shopware/shopware-cli:bin /shopware-cli /usr/local/bin/shopware-cli
COPY --link rootfs /

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_FILE_OVERRIDE=0

ENTRYPOINT [ "/entrypoint" ]
CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
