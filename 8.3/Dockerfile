#syntax=docker/dockerfile:1.4

FROM docker.io/library/php:8.3.0-fpm-alpine@sha256:4964a6cdc14b075da55a1b5c3d647f2fd5d7d191a6aef4c64c5971c64f4f4ace

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apk add --no-cache icu-data-full curl jq && \
    apk upgrade --no-cache && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ffi redis opcache apcu amqp && \
    mkdir -p /var/www/html && \
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" && \
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf.default

COPY --from=ghcr.io/shyim/supervisord:latest --link /usr/local/bin/supervisord /usr/bin/supervisord
COPY --from=docker.io/library/caddy:latest@sha256:8a5908bc4ad5e9dcb6214a258f1bc17042f9072497c6ac29b7c6643dcfa8da1d --link /usr/bin/caddy /usr/bin/caddy

ENV APP_ENV=prod \
    APP_URL_CHECK_DISABLED=1 \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    LOCK_DSN=flock \
    MAILER_DSN=null://localhost \
    DATABASE_PORT=3306 \
    OPENSEARCH_URL= \
    SHOPWARE_ES_ENABLED=0 \
    SHOPWARE_ES_INDEXING_ENABLED=0 \
    SHOPWARE_ES_INDEX_PREFIX= \
    COMPOSER_HOME=/tmp/composer \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    SHOPWARE_HTTP_DEFAULT_TTL=7200 \
    SHOPWARE_CACHE_ID=docker \
    BLUE_GREEN_DEPLOYMENT=0 \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    COMPOSER_PLUGIN_LOADER=1 \
    INSTALL_LOCALE=en-GB \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware \
    FPM_PM=dynamic \
    FPM_PM_MAX_CHILDREN=5 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_MAX_SPARE_SERVERS=3 \
    PHP_SESSION_HANDLER=files \
    PHP_SESSION_SAVE_PATH= \
    PHP_MAX_UPLOAD_SIZE=128m \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MEMORY_LIMIT=512m \
    PHP_ERROR_REPORTING=E_ALL

USER www-data

COPY --link rootfs /

EXPOSE 8000
WORKDIR /var/www/html

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
