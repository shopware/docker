#syntax=docker/dockerfile:1.7
#check=skip=SecretsUsedInArgOrEnv

# v2 image — see adr/2026-07-08-docker-image-variant-v2.md
# The base image is pinned by digest via docker-bake.hcl (single source of truth).
ARG PHP_BASE_IMAGE=dunglas/frankenphp:php8.4

FROM ${PHP_BASE_IMAGE}

# All versions below are injected from docker-bake.hcl so production and dev
# images cannot drift (ADR section 5: single source of truth).
ARG INSTALL_PHP_EXTENSIONS_VERSION=2.11.12
ARG PHP_CORE_EXTENSIONS="bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl"
ARG PHP_PINNED_EXTENSIONS="redis-6.3.0 apcu-5.1.28 amqp-2.2.0 zstd-0.18.0"
ARG PHP_OPTIONAL_EXTENSIONS="grpc-1.83.0 opentelemetry-1.2.1"

# Pinned extension installer instead of the bundled/latest one (ADR section 5)
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/${INSTALL_PHP_EXTENSIONS_VERSION}/install-php-extensions /usr/local/bin/install-php-extensions

RUN <<EOF
    set -e
    apt-get update
    apt-get upgrade -y
    apt-get install -y --no-install-recommends curl
    install-php-extensions ${PHP_CORE_EXTENSIONS} ${PHP_PINNED_EXTENSIONS} ${PHP_OPTIONAL_EXTENSIONS}
    mkdir -p /var/www/html
    # uid/gid 82 keeps parity with the v1 production images (Alpine www-data)
    usermod -u 82 www-data
    groupmod -g 82 www-data
    chown -R www-data:www-data /data/caddy /config/caddy
    # grpc and opentelemetry ship installed but NOT loaded (ADR section 3).
    # Their ini files live outside the scan dir; the entrypoint adds them to
    # PHP_INI_SCAN_DIR when PHP_EXTENSION_GRPC / PHP_EXTENSION_OPENTELEMETRY is set to 1.
    for ext in grpc opentelemetry; do
        mkdir -p /usr/local/etc/php/conf.available/$ext
        mv /usr/local/etc/php/conf.d/docker-php-ext-$ext.ini /usr/local/etc/php/conf.available/$ext/
    done
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
EOF

# Lifecycle metadata (ADR section 7) — also exposed as OCI/com.shopware labels via bake.
# Empty date = not scheduled yet. The entrypoint compares these against the clock.
ARG IMAGE_VERSION=""
ARG IMAGE_SECURITY_ONLY_DATE=""
ARG IMAGE_EOL_DATE=""
ENV SHOPWARE_IMAGE_VERSION=${IMAGE_VERSION} \
    SHOPWARE_IMAGE_SECURITY_ONLY=${IMAGE_SECURITY_ONLY_DATE} \
    SHOPWARE_IMAGE_EOL=${IMAGE_EOL_DATE}

# Only infrastructure-level defaults live in ENV (ADR section 4). Shopware
# application defaults (APP_ENV, LOCK_DSN, MAILER_DSN, SHOPWARE_*, INSTALL_*)
# are intentionally NOT baked so container env and .env files stay in control.
ENV COMPOSER_HOME=/tmp/composer \
    COMPOSER_ROOT_VERSION=1.0.0 \
    PHP_EXTENSION_GRPC=0 \
    PHP_EXTENSION_OPENTELEMETRY=0 \
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

# Caddy's admin endpoint answers on localhost:2019 as long as the server runs
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS http://localhost:2019/metrics >/dev/null || exit 1

# Best-effort build-time EOL warning for downstream images (ADR section 7).
# Warn-only by contract: the script always exits 0.
ONBUILD RUN /usr/local/bin/shopware-image-lifecycle build

ENTRYPOINT ["/entrypoint"]

CMD ["--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
