#syntax=docker/dockerfile:1

FROM base

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN <<EOF
    set -e

    apk add --no-cache icu-data-full curl jq trurl rabbitmq-c zstd-libs lz4-libs liblzf
    chmod +x /usr/local/bin/install-php-extensions
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl
EOF

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip rabbitmq-c-dev zstd-dev lz4-dev liblzf-dev
    pie install --no-interaction --no-cache --skip-enable-extension phpredis/phpredis --enable-redis-lzf --with-liblzf=yes --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes
    pie install --no-interaction --no-cache --skip-enable-extension apcu/apcu:5.1.27
    pie install --no-interaction --no-cache --skip-enable-extension kjdev/zstd:0.15.2
    pie install --no-interaction --no-cache --skip-enable-extension php-amqp/php-amqp:2.2.0
    docker-php-ext-enable redis apcu zstd amqp
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps
    mkdir -p /var/www/html
    mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"
    rm -f /usr/local/etc/php-fpm.d/zz-docker.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf
    rm -f /usr/local/etc/php-fpm.d/www.conf.default
EOF

USER root

RUN apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS && \
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2) && \
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc && \
    cd /tmp/grpc/src/php/ext/grpc && \
    phpize && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf /tmp/grpc && \
    apk del --no-cache git grpc-dev $PHPIZE_DEPS && \
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    docker-php-ext-enable opentelemetry
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps
EOF

USER root
RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<'EOF'
    set -eu
    export PIE_WORKING_DIRECTORY=/tmp/pie
    install-php-extensions tideways blackfire
    apk add --no-cache --virtual .pie-build-deps $PHPIZE_DEPS libtool unzip linux-headers zlib-dev
    pie install --no-interaction --no-cache --skip-enable-extension xdebug/xdebug:3.5.0
    pie install --no-interaction --no-cache --skip-enable-extension noisebynorthwest/php-spx
    docker-php-ext-enable xdebug spx
    rm -rf /tmp/pie
    apk del --no-cache .pie-build-deps

    cd /usr/local/etc/php/conf.d
    mv docker-php-ext-opentelemetry.ini docker-php-ext-opentelemetry.disabled
    mv docker-php-ext-xdebug.ini docker-php-ext-xdebug.disabled
    mv docker-php-ext-tideways.ini docker-php-ext-tideways.disabled
    mv docker-php-ext-blackfire.ini docker-php-ext-blackfire.disabled
    mv docker-php-ext-spx.ini docker-php-ext-spx.disabled

EOF

# Optional extensions are enabled only by the daily image configuration.
RUN mv /usr/local/etc/php/conf.d/grpc.ini /usr/local/etc/php/conf.d/grpc.disabled
