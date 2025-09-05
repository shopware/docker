#syntax=docker/dockerfile:1.4

FROM base

USER root

RUN <<EOF
    set -e
    apt-get update
    apt-get install -y libgrpc++1.51 libgrpc-dev git
    GRPC_VERSION=$(dpkg -s libgrpc-dev | grep '^Version:' | cut -d' ' -f2 | cut -d'-' -f1)
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc
    cd /tmp/grpc/src/php/ext/grpc
    phpize
    ./configure
    make
    make install
    cd /root
    rm -rf /tmp/grpc
    apt-get remove -y git libgrpc-dev
    apt-get autoremove -y
    install-php-extensions opentelemetry
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini
EOF

USER www-data
