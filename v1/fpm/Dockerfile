#syntax=docker/dockerfile:1.4

FROM base

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN <<EOF
    set -e

    apk add --no-cache icu-data-full curl jq trurl rabbitmq-c zstd-libs lz4-libs liblzf grpc-cpp
    apk upgrade --no-cache
    chmod +x /usr/local/bin/install-php-extensions
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl
EOF

RUN --mount=type=secret,id=composer_auth \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    if [ -f /run/secrets/composer_auth ]; then
        export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"
    fi
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip git grpc-dev rabbitmq-c-dev zstd-dev lz4-dev liblzf-dev
    pie install --no-interaction --no-cache --skip-enable-extension phpredis/phpredis --enable-redis-lzf --with-liblzf=yes --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes
    pie install --no-interaction --no-cache --skip-enable-extension apcu/apcu:5.1.27
    pie install --no-interaction --no-cache --skip-enable-extension kjdev/zstd:0.15.2
    pie install --no-interaction --no-cache --skip-enable-extension php-amqp/php-amqp:2.2.0
    docker-php-ext-enable redis apcu zstd amqp
    # Keep telemetry extensions disabled; the -otel image enables them.
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2)
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc
    cd /tmp/grpc/src/php/ext/grpc
    phpize
    ./configure
    make
    make install
    cd /root
    rm -rf /tmp/grpc
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps
    mkdir -p /var/www/html
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf.default
EOF

ENV APP_ENV=prod \
    APP_URL_CHECK_DISABLED=1 \
    LOCK_DSN=flock \
    MAILER_DSN=null://localhost \
    OPENSEARCH_URL= \
    BLUE_GREEN_DEPLOYMENT=0 \
    SHOPWARE_HTTP_CACHE_ENABLED=1 \
    SHOPWARE_CACHE_ID=docker \
    SHOPWARE_SKIP_WEBINSTALLER=1 \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_ROOT_VERSION=1.0.0 \
    INSTALL_LOCALE=en-GB \
    INSTALL_CURRENCY=EUR \
    INSTALL_ADMIN_USERNAME=admin \
    INSTALL_ADMIN_PASSWORD=shopware \
    FPM_LISTEN=9000 \
    FPM_PROCESS_CONTROL_TIMEOUT=0 \
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
    PHP_OPCACHE_MAX_ACCELERATED_FILES=20000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=256 \
    PHP_OPCACHE_FILE_CACHE= \
    PHP_OPCACHE_FILE_CACHE_ONLY=0 \
    PHP_OPCACHE_FILE_OVERRIDE=1 \
    PHP_REALPATH_CACHE_SIZE=4096K \
    PHP_REALPATH_CACHE_TTL=3600 \
    MYSQL_WAIT_SECONDS=20

USER www-data

COPY --link rootfs /

WORKDIR /var/www/html
