#syntax=docker/dockerfile:1.4

FROM base

USER root

RUN --mount=type=bind,from=ghcr.io/php/pie:bin,source=/pie,target=/usr/local/bin/pie <<EOF
    set -e
    export PIE_WORKING_DIRECTORY=/tmp/pie
    apt-get update
    apt-get install -y libgrpc++1.51 libgrpc-dev git
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
    apt-get remove -y git libgrpc-dev
    apt-get autoremove -y
    savedAptMark=$(apt-mark showmanual)
    apt-get install -y --no-install-recommends $PHPIZE_DEPS libtool unzip
    pie install --no-interaction --no-cache --skip-enable-extension open-telemetry/ext-opentelemetry
    docker-php-ext-enable opentelemetry
    rm -rf /tmp/pie
    apt-mark auto '.*' > /dev/null
    apt-mark manual $savedAptMark
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini
EOF

USER www-data
