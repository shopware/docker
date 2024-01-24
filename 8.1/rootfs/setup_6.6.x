#!/usr/bin/env sh

set -e
set -x

database_host=$(trurl $DATABASE_URL --get '{host}')
database_port=$(trurl $DATABASE_URL --get '{port}')

try=0
if [[ $MYSQL_WAIT_SECONDS != 0 ]]; then
  until nc -z -v -w30 $database_host ${database_port:-3306}
  do
    echo "Waiting for database connection..."
    # wait for 5 seconds before check again
    sleep 1

    try=$((try+1))

    if [[ $try -gt $MYSQL_WAIT_SECONDS ]]; then
      echo "Error: We have been waiting for database connection too long already; failing."
      exit 1
    fi
  done
fi

console() {
  console "$@"
}

update_all_plugins() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    console plugin:update $plugin
  done
}

install_all_plugins() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    console plugin:install --activate $plugin
  done
}

if php bin/console system:config:get shopware.installed; then
  console system:update:finish
  console plugin:refresh

  update_all_plugins
  install_all_plugins
  console theme:compile
else
  # Shopware is not installed
  console system:install --create-database "--shop-locale=$INSTALL_LOCALE" "--shop-currency=$INSTALL_CURRENCY" --force
  console user:create "$INSTALL_ADMIN_USERNAME" --admin --password="$INSTALL_ADMIN_PASSWORD" -n
  console sales-channel:create:storefront --name=Storefront --url="$APP_URL"
  console theme:change --all Storefront
  console system:config:set core.frw.completedAt '2019-10-07T10:46:23+00:00'
  console system:config:set core.usageData.shareUsageData false --json
  console plugin:refresh

  install_all_plugins
fi
