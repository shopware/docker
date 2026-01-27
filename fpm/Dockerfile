#syntax=docker/dockerfile:1.4

FROM base AS amqpinstall

RUN <<EOF
    set -e

    apk add --no-cache $PHPIZE_DEPS git patch rabbitmq-c-dev curl
    git clone https://github.com/php-amqp/php-amqp /tmp/php-amqp
    cd /tmp/php-amqp
    git reset --hard 3618db5f781aa3d371b630c666bc90845d7c77d4
    curl -L https://patch-diff.githubusercontent.com/raw/php-amqp/php-amqp/pull/595.patch | patch -p1
    phpize
    ./configure
    make -j"$(nproc)"
    make install
    echo 'extension=amqp.so' > /usr/local/etc/php/conf.d/docker-php-ext-amqp.ini
EOF

FROM base

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN <<EOF
    set -e

    apk add --no-cache icu-data-full curl jq trurl rabbitmq-c
    apk upgrade --no-cache
    chmod +x /usr/local/bin/install-php-extensions
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache redis apcu-5.1.27 zstd-0.15.2
    mkdir -p /var/www/html
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf.default
EOF

COPY --from=amqpinstall /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=amqpinstall /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

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
