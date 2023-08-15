#syntax=docker/dockerfile:1.4

FROM docker.io/library/php:8.0.28-fpm-alpine@sha256:8ad90c2835edc3ec378552317c073fe87fd857ad9611519f82252cc08a284d77

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apk add --no-cache icu-data-full curl jq && \
    apk upgrade --no-cache && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions bcmath gd intl mysqli pdo_mysql sockets bz2 gmp soap zip ffi redis opcache apcu amqp && \
    mkdir -p /var/www/html && \
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" && \
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf.default

COPY --from=ghcr.io/shyim/supervisord:latest@sha256:2fc9ea4c1925da2c2ee94fcd4e81a396deabc27f8c6c1d04cb60d7e4139e74a2 --link /usr/local/bin/supervisord /usr/bin/supervisord
COPY --from=docker.io/library/caddy:latest@sha256:0da93d63c5b3af38288e909b953bd8cdcf12537c27ff219aac46c6a01775cbdb --link /usr/bin/caddy /usr/bin/caddy

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
