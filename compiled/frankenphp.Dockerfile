#syntax=docker/dockerfile:1
#check=skip=SecretsUsedInArgOrEnv

FROM base

RUN <<EOF
    set -e
    apt-get update
    install-php-extensions bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl
EOF

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apt-get update
    savedAptMark=$(apt-mark showmanual)
    apt-get install -y --no-install-recommends $PHPIZE_DEPS libtool unzip librabbitmq-dev libzstd-dev liblz4-dev liblzf-dev
    pie install --no-interaction --no-cache --skip-enable-extension phpredis/phpredis --enable-redis-lzf --with-liblzf=yes --enable-redis-zstd --enable-redis-lz4 --with-liblz4=yes
    pie install --no-interaction --no-cache --skip-enable-extension apcu/apcu
    pie install --no-interaction --no-cache --skip-enable-extension kjdev/zstd
    pie install --no-interaction --no-cache --skip-enable-extension php-amqp/php-amqp:2.2.0
    docker-php-ext-enable redis apcu zstd amqp
    rm -rf /tmp/pie
    apt-mark auto '.*' > /dev/null
    apt-mark manual $savedAptMark librabbitmq4 libzstd1 liblz4-1 liblzf1
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
    mkdir -p /var/www/html
    usermod -u 82 www-data
    groupmod -g 82 www-data
    chown -R www-data:www-data /data/caddy && chown -R www-data:www-data /config/caddy
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
EOF

USER root

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apt-get update
    apt-get install -y libgrpc-dev git
    GRPC_VERSION=$(dpkg -s libgrpc-dev | grep '^Version:' | cut -d' ' -f2 | cut -d'-' -f1)
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc
    cd /tmp/grpc && curl -sSL https://patch-diff.githubusercontent.com/raw/grpc/grpc/pull/40337.patch | git apply - && \
    cd /tmp/grpc/src/php/ext/grpc
    phpize
    ./configure
    make -j"$(nproc)"
    make install
    cd /root
    rm -rf /tmp/grpc
    apt-get install -y --no-install-recommends $PHPIZE_DEPS libtool unzip
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    docker-php-ext-enable opentelemetry
    rm -rf /tmp/pie
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini
EOF

# Optional extensions are enabled only by the daily image configuration.
RUN mv /usr/local/etc/php/conf.d/grpc.ini /usr/local/etc/php/conf.d/grpc.disabled && \
    mv /usr/local/etc/php/conf.d/docker-php-ext-opentelemetry.ini /usr/local/etc/php/conf.d/docker-php-ext-opentelemetry.disabled
