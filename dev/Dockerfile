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

    apk add --no-cache npm bash git shadow patch coreutils
    
    PHP_VERSION_ID=$(php -r 'echo PHP_VERSION_ID;')
    if [[ "$PHP_VERSION_ID" -lt 80500 ]]; then
        install-php-extensions tideways blackfire xdebug
    else
        install-php-extensions xdebug
    fi

    cd /usr/local/etc/php/conf.d
    mv docker-php-ext-opentelemetry.ini docker-php-ext-opentelemetry.disabled
    mv docker-php-ext-xdebug.ini docker-php-ext-xdebug.disabled
    if [[ "$PHP_VERSION_ID" -lt 80500 ]]; then
        mv docker-php-ext-tideways.ini docker-php-ext-tideways.disabled
        mv docker-php-ext-blackfire.ini docker-php-ext-blackfire.disabled
    fi

    INSTALLED_NODE_VERSION=$(node -e "console.log(process.versions.node.substr(0,2))")
    if [[ "$INSTALLED_NODE_VERSION" != "$NODE_VERSION" ]]; then
        echo "ERROR: Installed Node.js version ($INSTALLED_NODE_VERSION) does not match expected version ($NODE_VERSION)"
        exit 1
    fi

    usermod -u 1000 www-data
    groupmod -g 1000 www-data
    chown -R 1000:1000 /var/www/html /home/www-data /usr/local/etc/php/conf.d
EOF

USER www-data

COPY --link --from=ghcr.io/shopware/shopware-cli:bin /shopware-cli /usr/local/bin/shopware-cli
COPY --link --from=composer/composer:2-bin /composer /usr/local/bin/composer
COPY --link --from=blackfire/blackfire /usr/local/bin/blackfire /usr/local/bin/blackfire
COPY --link rootfs /

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_FILE_OVERRIDE=0 \
    APP_URL_CHECK_DISABLED=0 \
    SHOPWARE_SKIP_WEBINSTALLER=0 \
    APP_SECRET=def00000bb5acb32b54ff8ee130270586eec0e878f7337dc7a837acc31d3ff00f93a56b595448b4b29664847dd51991b3314ff65aeeeb761a133b0ec0e070433bff08e48 \
    LOCK_DSN=flock

ENTRYPOINT [ "/entrypoint" ]
CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
