#syntax=docker/dockerfile:1.4

ARG FRANKENPHP_IMAGE=ghcr.io/shopware/docker-base-ci-test:15628943495-8.4-frankenphp

FROM ${FRANKENPHP_IMAGE}

USER root

RUN <<EOF
    set -e
    apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2)
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc
    cd /tmp/grpc/src/php/ext/grpc
    phpize
    ./configure
    make
    make install
    cd /root
    rm -rf /tmp/grpc
    apk del --no-cache git grpc-dev $PHPIZE_DEPS
    install-php-extensions opentelemetry
    echo "extension=grpc.so" > /usr/local/etc/php/conf.d/grpc.ini
EOF

USER www-data
