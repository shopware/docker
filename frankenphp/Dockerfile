#syntax=docker/dockerfile:1
#check=skip=SecretsUsedInArgOrEnv
FROM debian:trixie-slim

ARG PHP_VERSION
ENV PHP_INI_DIR=/usr/local/etc/php \
    PHP_VERSION=${PHP_VERSION} \
    PHPIZE_DEPS="autoconf dpkg-dev file g++ gcc libc6-dev make pkg-config re2c" \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -pie" \
    XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    GODEBUG=cgocheck=0

ARG OS_PACKAGES_REFRESH
RUN --mount=type=bind,from=artifacts,source=/,target=/compiled <<'EOF'
    set -eu
    sh /compiled/validate-runtime.sh
    echo "Refreshing OS packages: ${OS_PACKAGES_REFRESH}"
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl mailcap libcap2-bin xz-utils
    xargs apt-get install -y --no-install-recommends < /compiled/runtime-dependencies.txt
    apt-get upgrade --with-new-pkgs -y
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    usermod -u 82 www-data
    groupmod -g 82 www-data
    mkdir -p /var/www/html /config/caddy /data/caddy /etc/frankenphp
    chown -R www-data:www-data /config /data
    chmod 1777 /var/www/html
EOF

COPY --link --from=artifacts /usr/local/ /usr/local/
COPY --link --from=artifacts /usr/src/php.tar.xz /usr/src/php.tar.xz

ARG ENABLE_OTEL=0
RUN if [ "$ENABLE_OTEL" = 1 ]; then \
        mv "$PHP_INI_DIR/conf.d/grpc.disabled" "$PHP_INI_DIR/conf.d/grpc.ini" && \
        mv "$PHP_INI_DIR/conf.d/docker-php-ext-opentelemetry.disabled" "$PHP_INI_DIR/conf.d/docker-php-ext-opentelemetry.ini"; \
    fi
RUN ldconfig && setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp

ENTRYPOINT ["docker-php-entrypoint"]
STOPSIGNAL SIGTERM
EXPOSE 80 443 443/udp 2019
HEALTHCHECK CMD curl -f http://localhost:2019/metrics || exit 1

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
