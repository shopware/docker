#!/usr/bin/env sh

set -e
set -x

# shellcheck source=./functions.sh
. /usr/local/shopware/functions.sh

wait_for_mysql

if console system:is-installed; then
  run_hooks pre_update

  if [ "${SHOPWARE_SKIP_ASSET_COPY-""}" ]; then
    console system:update:finish --skip-asset-build
  else
    console system:update:finish
  fi

  if [ "${SHOPWARE_SKIP_ASSET_COPY-""}" ]; then
    console plugin:update:all
  else
    console plugin:update:all --skip-asset-build
  fi

  install_all_plugins

  run_hooks post_update
else
  run_hooks pre_install

  console system:install --create-database "--shop-locale=$INSTALL_LOCALE" "--shop-currency=$INSTALL_CURRENCY" --force
  console user:create "$INSTALL_ADMIN_USERNAME" --admin --password="$INSTALL_ADMIN_PASSWORD" -n
  console sales-channel:create:storefront --name=Storefront --url="$APP_URL"
  console theme:change --all Storefront
  console system:config:set core.frw.completedAt '2019-10-07T10:46:23+00:00'
  console plugin:refresh

  install_all_plugins

  run_hooks post_install
fi
