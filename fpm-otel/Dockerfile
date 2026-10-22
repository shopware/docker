#syntax=docker/dockerfile:1

FROM base AS build

USER root

RUN apk add --no-cache git grpc-cpp grpc-dev $PHPIZE_DEPS && \
    GRPC_VERSION=$(apk info grpc -d | grep grpc | cut -d- -f2) && \
    git clone --depth 1 -b v${GRPC_VERSION} https://github.com/grpc/grpc /tmp/grpc && \
    cd /tmp/grpc/src/php/ext/grpc && \
    phpize && \
    ./configure && \
    make && \
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

USER www-data

# Derived images use the build stage so this refresh cannot invalidate compilation.
FROM build AS runtime

USER root
ARG OS_PACKAGES_REFRESH
RUN echo "Refreshing OS packages: ${OS_PACKAGES_REFRESH}" \
    && apk upgrade --no-cache

USER www-data
