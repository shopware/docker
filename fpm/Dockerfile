#syntax=docker/dockerfile:1.4

ARG PHP_PATCH_VERSION
ARG PHP_DIGEST

FROM docker.io/library/php:${PHP_PATCH_VERSION}-fpm-alpine@${PHP_DIGEST}

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN apk add --no-cache icu-data-full curl jq trurl && \
    apk upgrade --no-cache && \
    chmod +x /usr/local/bin/install-php-extensions && \
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ffi redis opcache apcu amqp && \
    mkdir -p /var/www/html && \
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini" && \
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf && \
    rm -f /usr/local/etc/php-fpm.d/www.conf.default

ENV APP_ENV=prod \
    APP_URL_CHECK_DISABLED=1 \
    LOCK_DSN=flock \
    MAILER_DSN=null://localhost \
    DATABASE_PORT=3306 \
    OPENSEARCH_URL= \
    BLUE_GREEN_DEPLOYMENT=0 \
    SHOPWARE_ES_ENABLED=0 \
    SHOPWARE_ES_INDEXING_ENABLED=0 \
    SHOPWARE_ES_INDEX_PREFIX= \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    SHOPWARE_HTTP_DEFAULT_TTL=7200 \
    SHOPWARE_CACHE_ID=docker \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    COMPOSER_PLUGIN_LOADER=1 \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_ROOT_VERSION=1.0.0 \
    INSTALL_LOCALE=en-GB \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware \
    FPM_LISTEN=9000 \
    FPM_PM=dynamic \
    FPM_PM_MAX_CHILDREN=5 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_MAX_SPARE_SERVERS=3 \
    FPM_PM_MAX_REQUESTS=0 \
    FPM_PM_STATUS_PATH=/-/fpm/status \
    FPM_PING_PATH=/-/fpm/ping \
    PHP_SESSION_COOKIE_LIFETIME=0 \
    PHP_SESSION_GC_MAXLIFETIME=1440 \
    PHP_SESSION_HANDLER=files \
    PHP_SESSION_SAVE_PATH= \
    PHP_MAX_UPLOAD_SIZE=128m \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MEMORY_LIMIT=512m \
    PHP_DISPLAY_ERRORS=Off \
    PHP_ERROR_REPORTING=E_ALL \
    PHP_OPCACHE_ENABLE_CLI=0 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=20 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=10000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=128 \
    PHP_OPCACHE_FILE_CACHE= \
    PHP_OPCACHE_FILE_CACHE_ONLY=0 \
    PHP_OPCACHE_FILE_OVERRIDE=1 \
    PHP_REALPATH_CACHE_SIZE=4096K \
    PHP_REALPATH_CACHE_TTL=3600 \
    MYSQL_WAIT_SECONDS=20

USER www-data

COPY --link rootfs /

WORKDIR /var/www/html

