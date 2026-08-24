#syntax=docker/dockerfile:1
#check=skip=SecretsUsedInArgOrEnv

# The unpinned syntax directive is deliberate: it resolves to the latest stable
# dockerfile frontend. An older pin (1.7) lacks the source.git.checksum
# capability that docker/github-builder's git-context builds require.

# v2 dev image — built on top of the v2 FrankenPHP image
# (see adr/2026-07-08-docker-image-variant-v2.md)
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-bookworm-slim AS node

FROM base

ARG NODE_VERSION

# Versions are injected from docker-bake.hcl (single source of truth).
# tideways/blackfire/spx are distributed without PECL version pins.
ARG PHP_DEV_PINNED_EXTENSIONS="xdebug-3.5.3"
ARG PHP_DEV_EXTENSIONS="tideways blackfire spx"

USER root

COPY --link --from=node /usr/local/bin/node /usr/local/bin/node
COPY --link --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN <<EOF
    set -e

    ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
    ln -s /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

    node --version
    npm --version

    INSTALLED_NODE_VERSION=$(node -e "console.log(process.versions.node.split('.')[0])")
    if [ "$INSTALLED_NODE_VERSION" != "$NODE_VERSION" ]; then
        echo "ERROR: Installed Node.js version ($INSTALLED_NODE_VERSION) does not match expected version ($NODE_VERSION)"
        exit 1
    fi

    apt-get update
    apt-get install -y --no-install-recommends git patch unzip procps

    install-php-extensions ${PHP_DEV_PINNED_EXTENSIONS} ${PHP_DEV_EXTENSIONS}

    # profilers ship installed but not loaded; enabled via PHP_PROFILER=<name>
    # by adding their ini directory to PHP_INI_SCAN_DIR (see entrypoint-dev)
    for ext in xdebug tideways blackfire spx; do
        mkdir -p /usr/local/etc/php/conf.available/$ext
        mv /usr/local/etc/php/conf.d/docker-php-ext-$ext.ini /usr/local/etc/php/conf.available/$ext/
    done

    usermod -u 1000 www-data
    groupmod -g 1000 www-data
    mkdir -p /home/www-data
    usermod -d /home/www-data www-data
    chown -R 1000:1000 /var/www/html /home/www-data /data/caddy /config/caddy

    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
EOF

USER www-data

COPY --link --from=ghcr.io/shopware/shopware-cli:bin /shopware-cli /usr/local/bin/shopware-cli
COPY --link --from=composer/composer:2-bin /composer /usr/local/bin/composer
COPY --link --from=blackfire/blackfire /usr/local/bin/blackfire /usr/local/bin/blackfire
COPY --link --from=ghcr.io/shopware/shopware-cli/env-bridge /env-bridge /usr/local/bin/env-bridge
COPY --link rootfs /

ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_FILE_OVERRIDE=0

ENTRYPOINT ["/entrypoint-dev"]

CMD ["--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
