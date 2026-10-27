#syntax=docker/dockerfile:1.4
#check=skip=SecretsUsedInArgOrEnv

ARG PHP_VERSION=8.4
FROM dunglas/frankenphp:php${PHP_VERSION}

RUN <<EOF
    set -e
    apt-get update
    apt-get upgrade -y
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl
EOF

RUN --mount=type=secret,id=composer_auth \
    --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    if [ -f /run/secrets/composer_auth ]; then
        export COMPOSER_AUTH="$(cat /run/secrets/composer_auth)"
    fi
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apt-get update
    savedAptMark=$(apt-mark showmanual)
    apt-get install -y --no-install-recommends $PHPIZE_DEPS libtool unzip patch libgrpc-dev git librabbitmq-dev libzstd-dev liblz4-dev liblzf-dev
    pie install --no-interaction --no-cache --skip-enable-extension phpredis/phpredis --enable-redis-lzf --with-liblzf=yes --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes
    pie install --no-interaction --no-cache --skip-enable-extension apcu/apcu
    pie install --no-interaction --no-cache --skip-enable-extension kjdev/zstd
    pie install --no-interaction --no-cache --skip-enable-extension php-amqp/php-amqp:2.2.0
    docker-php-ext-enable redis apcu zstd amqp
    # Keep telemetry extensions disabled; the -otel image enables them.
    GRPC_VERSION=$(dpkg -s libgrpc-dev | grep '^Version:' | cut -d' ' -f2 | cut -d'-' -f1)
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc
    cd /tmp/grpc && curl -sSL https://patch-diff.githubusercontent.com/raw/grpc/grpc/pull/40337.patch | git apply - && \
    cd /tmp/grpc/src/php/ext/grpc
    phpize
    ./configure
    make
    make install
    cd /root
    rm -rf /tmp/grpc
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    rm -rf /tmp/pie
    apt-mark auto '.*' > /dev/null
    apt-mark manual $savedAptMark librabbitmq4 libzstd1 liblz4-1 liblzf1 libgrpc29t64
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
    # The base image marks its compiler toolchain and headers as manually installed.
    compilerPackages=$(dpkg-query -W -f='${binary:Package}\n' 'gcc-*' | sed '/-base/d')
    apt-get purge -y --auto-remove $PHPIZE_DEPS $compilerPackages 'g++-*' 'cpp-*' 'binutils*' '*-dev' patch
    mkdir -p /var/www/html
    usermod -u 82 www-data
    groupmod -g 82 www-data
    chown -R www-data:www-data /data/caddy && chown -R www-data:www-data /config/caddy
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
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
    PHP_REALPATH_CACHE_TTL=3600

USER www-data

COPY --link rootfs /

WORKDIR /var/www/html

EXPOSE 8000

CMD ["--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
