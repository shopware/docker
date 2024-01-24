#!/usr/bin/env sh

set -e
set -x

. /usr/local/shopware/functions.sh

if php bin/console system:config:get shopware.installed; then
  run_hooks pre_update

  console system:update:finish
  console plugin:refresh

  update_all_plugins
  install_all_plugins

  run_hooks post_update
else
  run_hooks pre_install

  # Shopware is not installed
  console system:install --create-database "--shop-locale=$INSTALL_LOCALE" "--shop-currency=$INSTALL_CURRENCY" --force
  console user:create "$INSTALL_ADMIN_USERNAME" --admin --password="$INSTALL_ADMIN_PASSWORD" -n
  console sales-channel:create:storefront --name=Storefront --url="$APP_URL"
  console theme:change --all Storefront
  console system:config:set core.frw.completedAt '2019-10-07T10:46:23+00:00'
  console system:config:set core.usageData.shareUsageData false --json
  console plugin:refresh

  install_all_plugins

  run_hooks post_install
fi
