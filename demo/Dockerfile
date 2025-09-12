FROM ghcr.io/shopware/shopware-cli:latest-php-8.3 AS creation
ARG SHOPWARE_VERSION=6.7.2.0

RUN <<EOF
    set -e
    export COMPOSER_ALLOW_SUPERUSER=1
    shopware-cli project create /shop ${SHOPWARE_VERSION}
    shopware-cli project ci /shop
    composer -d /shop require "swag/demo-data:*"
EOF

COPY --chmod=555 <<EOF /shop/config/packages/override.yaml
parameters:
    env(TRUSTED_PROXIES): ''

framework:
    trusted_proxies: '%env(TRUSTED_PROXIES)%'
    secrets:
        enabled: false
    mailer:
        message_bus: 'messenger.default_bus'

shopware:
    auto_update:
        enabled: false
    store:
        frw: false
    cart:
      compress: false
    cache:
        cache_compression: true
        cache_compression_method: 'zstd'
    mail:
        update_mail_variables_on_send: false
    increment:
        user_activity:
            type: 'array'
        message_queue:
            type: 'array'
    admin_worker:
        enable_admin_worker: false
        enable_queue_stats_worker: false
        enable_notification_worker: false


monolog:
    handlers:
        main:
            level: error
            buffer_size: 30
        business_event_handler_buffer:
            level: error
EOF

FROM base
ARG SHOPWARE_VERSION=6.7.2.0

ENV APP_URL=http://localhost:8000 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_FILE_OVERRIDE=0

USER root

RUN <<EOF
    set -e
    apk add \
        --no-cache \
        mariadb \
        mariadb-client
EOF

COPY --link --from=composer/composer:2-bin /composer /usr/local/bin/composer
COPY --link rootfs /
COPY --link --from=creation /shop /var/www/html

RUN <<EOF
    set -e
    set -x
    mkdir -p /var/tmp /run/mysqld
    mariadb-install-db --datadir=/var/lib/mariadb --user=root

    mariadbd --basedir=/usr --datadir=/var/lib/mariadb --plugin-dir=/usr/lib/mariadb/plugin --user=root &

    i=1
    while [ $i -le 10 ]; do
        if mariadb-admin ping; then
            echo "Successfully connected to MariaDB on attempt $i!"
            break
        else
            echo "Attempt $i failed. Retrying in 5 seconds..."
            sleep 5
        fi
        i=$((i + 1))
    done

    if [ $i -gt 10 ]; then
        echo "Failed to connect to MariaDB after 10 attempts."
        exit 1
    fi

    mariadb-admin --user=root password 'root'
    php bin/console system:install --create-database --force
    mariadb -proot shopware -e "DELETE FROM sales_channel WHERE id = 0x98432def39fc4624b33213a56b8c944d"
    php bin/console user:create "admin" --admin --password="shopware" -n
    php bin/console sales-channel:create:storefront --name=Storefront --url="http://localhost/shop/public"
    php bin/console theme:change --all Storefront
    php bin/console plugin:refresh
    php -derror_reporting=E_ALL bin/console plugin:install --activate SwagPlatformDemoData
    mariadb -proot -e "SET GLOBAL innodb_fast_shutdown=0"
    mariadb -proot shopware -e "INSERT INTO system_config (id, configuration_key, configuration_value, sales_channel_id, created_at, updated_at) VALUES (0xb3ae4d7111114377af9480c4a0911111, 'core.frw.completedAt', '{\"_value\": \"2019-10-07T10:46:23+00:00\"}', NULL, '2019-10-07 10:46:23.169', NULL);"
    rm -rf var/cache/* /var/tmp/*
    php bin/console
    chown -R www-data:www-data /var/www/html /var/lib/mariadb/ /var/tmp /run/mysqld/

    echo "[program:worker]" | tee -a /etc/supervisord.conf
    echo "process_name=worker" | tee -a /etc/supervisord.conf
    echo "command=php /var/www/html/bin/console messenger:consume --all --memory-limit=512M --time-limit=60" | tee -a /etc/supervisord.conf
    echo "numprocs=1" | tee -a /etc/supervisord.conf
    echo "autostart=true" | tee -a /etc/supervisord.conf
    echo "autorestart=true" | tee -a /etc/supervisord.conf
    echo "" | tee -a /etc/supervisord.conf

    echo "[program:scheduled-task]" | tee -a /etc/supervisord.conf
    echo "process_name=scheduled-task" | tee -a /etc/supervisord.conf
    echo "command=php /var/www/html/bin/console scheduled-task:run --memory-limit=512M --time-limit=60" | tee -a /etc/supervisord.conf
    echo "numprocs=1" | tee -a /etc/supervisord.conf
    echo "autostart=true" | tee -a /etc/supervisord.conf
    echo "autorestart=true" | tee -a /etc/supervisord.conf
EOF

LABEL org.opencontainers.image.vendor="shopware AG" \
    org.opencontainers.image.url="https://www.shopware.com/" \
    org.opencontainers.image.documentation="https://developer.shopware.com/docs/guides/installation/setups/docker.html" \
    org.opencontainers.image.source="https://github.com/shopware/docker/tree/main/demo" \
    org.opencontainers.image.title="Shopware 6 Demo" \
    org.opencontainers.image.version="${SHOPWARE_VERSION}" \
    org.opencontainers.image.description="This is a Shopware installation with demo data for testing purposes."

USER www-data

ENTRYPOINT [ "/entrypoint" ]
CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf" ]
