ARG PHP_VERSION=8.4
ARG SHOPWARE_BUILD_SOURCE="branch"

FROM shopware/docker-base:${PHP_VERSION}-nginx-otel AS base-image
FROM shopware/shopware-cli:latest-php-${PHP_VERSION} AS shopware-cli

FROM shopware-cli AS checkout-tag

ARG SHOPWARE_VERSION

RUN shopware-cli project create /src ${SHOPWARE_VERSION#v} --verbose

FROM shopware-cli AS checkout-branch

ARG SHOPWARE_VERSION
ARG COMPOSER_ROOT_VERSION="6.7.9999999-dev"

ENV COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION}

ADD https://github.com/shopware/shopware.git#${SHOPWARE_VERSION} /src

FROM shopware-cli AS checkout-local

ARG COMPOSER_ROOT_VERSION="6.7.9999999-dev"

ENV COMPOSER_ROOT_VERSION=${COMPOSER_ROOT_VERSION}

COPY . /src

FROM checkout-${SHOPWARE_BUILD_SOURCE} AS prepare-general
SHELL ["/usr/bin/env", "bash", "-c"]

WORKDIR /src

RUN --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm <<EOF
set -euxo pipefail

composer require --ignore-platform-reqs --no-interaction "shopware/deployment-helper:*"
composer dump-autoload
EOF

FROM prepare-general AS prepare-tag

FROM prepare-general AS prepare-branch
SHELL ["/usr/bin/env", "bash", "-c"]

RUN <<EOF
set -euxo pipefail

shopware-cli project storefront-build /src --force-install-dependencies --skip-theme-compile
shopware-cli project admin-build /src

cd src/Storefront/Resources/app/storefront

npm install
node copy-to-vendor.js
EOF

FROM prepare-branch AS prepare-local

FROM prepare-${SHOPWARE_BUILD_SOURCE} AS build

RUN --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    shopware-cli project ci --with-dev-dependencies .

FROM base-image AS final

COPY --from=build --chown=82:82 /src /var/www/html
COPY --chown=82:82 <<EOF /var/www/html/install.lock
# Skip installer
EOF

ADD --chown=82:82 https://github.com/shopware/web-recovery/releases/latest/download/shopware-installer.phar.php /var/www/html/public/shopware-installer.phar.php

FROM final
