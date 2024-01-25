#!/usr/bin/env sh

set -e

wait_for_mysql() {
	database_host=${DATABASE_HOST:-"$(trurl "$DATABASE_URL" --get '{host}')"}
	database_port=${DATABASE_PORT:-"$(trurl "$DATABASE_URL" --get '{port}')"}
	MYSQL_WAIT_SECONDS=${MYSQL_WAIT_SECONDS:-20}

	try=0
	if [ "$MYSQL_WAIT_SECONDS" != 0 ]; then
		until nc -z -v -w30 "$database_host" "${database_port:-3306}"; do
			echo "Waiting for database connection..."
			# wait for 5 seconds before check again
			sleep 1

			try=$((try + 1))

			if [ $try = "$MYSQL_WAIT_SECONDS" ]; then
				echo "Error: We have been waiting for database connection too long already; failing."
				exit 1
			fi
		done
	fi
}

console() {
  php -derror_reporting=E_ALL bin/console "$@"
}

install_all_plugins() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.installedAt == null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    console plugin:install --activate "$plugin"
  done
}

update_all_plugins() {
  list_with_updates=$(php bin/console plugin:list --json | jq 'map(select(.upgradeVersion != null)) | .[].name' -r)

  for plugin in $list_with_updates; do
    php -derror_reporting=E_ALL bin/console plugin:update "$plugin"
  done
}

run_hooks() {
  hook=$1
  if [ -d "/usr/local/shopware/$hook.d" ]; then
    for file in "/usr/local/shopware/$hook.d"/*.sh; do
  echo "Running $file for $hook"
  # shellcheck source=../../../../../../../../../dev/null
  . "$file"
done
  fi
}
