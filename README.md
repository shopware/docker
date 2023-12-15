# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + Caddy to build your own docker image with your code.

## Getting Started

Create a Dockerfile in your project like:

```dockerfile
#syntax=docker/dockerfile:1.4

# pin versions
FROM ghcr.io/shopware/docker-base:8.2 as base-image
FROM ghcr.io/friendsofshopware/shopware-cli:latest-php-8.2 as shopware-cli

# build

FROM shopware-cli as build

COPY --link . /src
WORKDIR /src

RUN --mount=type=secret,id=composer_auth,dst=/src/auth.json \
    --mount=type=cache,target=/root/.composer \
    --mount=type=cache,target=/root/.npm \
    /usr/local/bin/entrypoint.sh shopware-cli project ci /src

# build final image

FROM base-image

COPY --from=build --chown=www-data /src /var/www/html
```

or better run `composer req shopware/docker` to install the Symfony Recipe.

In the stage `build` we are using shopware-cli to build the Shopware files:

- Composer installs
- Build Administration and Storefront with Extensions if needed
- Strip some files of vendor to make the layer small
- Merge administration snippets into one file

Refer to [shopware-cli](https://github.com/FriendsOfShopware/shopware-cli) to learn more about `shopware-cli project ci`

## Building docker image

You build your individual docker image with the source code in your CI pipeline and push it to your Container Registry. Later on can you use this image inside example docker-compose / kubernetes / etc.

<details>
  <summary>Example Github Action to build the image</summary>

```yaml
name: Build Docker Image

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
        
      - name: Login into Github Docker Registery
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          file: ./docker/Dockerfile
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}
```

</details>

## Running the container

<details>
  <summary>Example docker-compose</summary>

```yaml
version: "3.8"
services:
    db:
        image: mysql:8.0
        environment:
            MYSQL_ROOT_PASSWORD: 'shopware'
            MYSQL_USER: shopware
            MYSQL_PASSWORD: shopware
            MYSQL_DATABASE: shopware
        volumes:
        - mysql-data:/var/lib/mysql

    init-perm:
        image: alpine
        volumes:
            - jwt:/var/www/html/config/jwt
            - files:/var/www/html/files
            - theme:/var/www/html/public/theme
            - media:/var/www/html/public/media
            - thumbnail:/var/www/html/public/thumbnail
            - sitemap:/var/www/html/public/sitemap
        command: chown 82:82 /var/www/html/files /var/www/html/public/theme /var/www/html/public/media /var/www/html/public/thumbnail /var/www/html/public/sitemap /var/www/html/config/jwt

    init:
        image: local
        build:
            context: .
        env_file: .app.env
        entrypoint: /setup
        volumes:
            - jwt:/var/www/html/config/jwt
            - files:/var/www/html/files
            - theme:/var/www/html/public/theme
            - media:/var/www/html/public/media
            - thumbnail:/var/www/html/public/thumbnail
            - sitemap:/var/www/html/public/sitemap
        depends_on:
            db:
                condition: service_started
            init-perm:
                condition: service_completed_successfully
    web:
        image: local
        build:
            context: .
        volumes:
            - jwt:/var/www/html/config/jwt
            - files:/var/www/html/files
            - theme:/var/www/html/public/theme
            - media:/var/www/html/public/media
            - thumbnail:/var/www/html/public/thumbnail
            - sitemap:/var/www/html/public/sitemap
        depends_on:
            init:
                condition: service_completed_successfully
        env_file: .app.env
        ports:
            - 8000:8000

    worker:
        image: local
        restart: unless-stopped
        build:
            context: .
        volumes:
            - jwt:/var/www/html/config/jwt
            - files:/var/www/html/files
            - theme:/var/www/html/public/theme
            - media:/var/www/html/public/media
            - thumbnail:/var/www/html/public/thumbnail
            - sitemap:/var/www/html/public/sitemap
        depends_on:
            init:
                condition: service_completed_successfully
        env_file: .app.env
        entrypoint: [ "php", "bin/console", "messenger:consume", "async", "--time-limit=300", "--memory-limit=512M" ]
        deploy:
            replicas: 3

volumes:
    mysql-data:
    jwt:
    files:
    theme:
    media:
    thumbnail:
    sitemap:
```

</details>

In your setup you should have always an "init" container which does basic stuff like extension updates, theme compile etc with entrypoint `/setup`. 
When this container exits, you can start your actual app / worker containers. See docker-compose example above for details.

## Environment variables

| Variable                             | Default Value    | Description                                                                              |
|--------------------------------------|------------------|------------------------------------------------------------------------------------------|
| APP_ENV                              | prod             | Environment                                                                              |
| APP_SECRET                           | (empty)          | Can be generated with `openssl rand -hex 32`                                             |
| INSTANCE_ID                          | (empty)          | Unique Identifier for the Store: Can be generated with `openssl rand -hex 32`            |
| JWT_PRIVATE_KEY                      | (empty)          | Can be generated with `shopware-cli project generate-jwt --env`                          |
| JWT_PUBLIC_KEY                       | (empty)          | Can be generated with `shopware-cli project generate-jwt --env`                          |
| LOCK_DSN                             | flock            | DSN for Symfony locking                                                                  |
| APP_URL                              | (empty)          | Where Shopware will be accessible                                                        |
| DATABASE_HOST                        | (empty)          | Host of MySQL (needed for for checking is MySQL alive)                                   |
| DATABASE_PORT                        | 3306             | Host of MySQL (needed for for checking is MySQL alive)                                   |
| BLUE_GREEN_DEPLOYMENT                | 0                | This needs super priviledge to create trigger                                            |
| DATABASE_URL                         | (empty)          | MySQL credentials as DSN                                                                 |
| DATABASE_SSL_CA                      | (empty)          | Path to SSL CA file (needs to be readable for uid 512)                                   |
| DATABASE_SSL_CERT                    | (empty)          | Path to SSL Cert file (needs to be readable for uid 512)                                 |
| DATABASE_SSL_KEY                     | (empty)          | Path to SSL Key file (needs to be readable for uid 512)                                  |
| DATABASE_SSL_DONT_VERIFY_SERVER_CERT | (empty)          | Disables verification of the server certificate (1 disables it)                          |
| MAILER_DSN                           | null://localhost | Mailer DSN (Admin Configuration overwrites this)                                         |
| OPENSEARCH_URL                       | (empty)          | OpenSearch Hosts                                                                         |
| SHOPWARE_ES_ENABLED                  | 0                | OpenSearch Support Enabled?                                                              |
| SHOPWARE_ES_INDEXING_ENABLED         | 0                | OpenSearch Indexing Enabled?                                                             |
| SHOPWARE_ES_INDEX_PREFIX             | (empty)          | OpenSearch Index Prefix                                                                  |
| COMPOSER_HOME                        | /tmp/composer    | Caching for the Plugin Manager                                                           |
| SHOPWARE_HTTP_CACHE_ENABLED          | 1                | Is HTTP Cache enabled?                                                                   |
| SHOPWARE_HTTP_DEFAULT_TTL            | 7200             | Default TTL for Http Cache                                                               |
| INSTALL_LOCALE                       | en-GB            | Default locale for the Shop                                                              |
| INSTALL_CURRENCY                     | EUR              | Default currency for the Shop                                                            |
| INSTALL_ADMIN_USERNAME               | admin            | Default admin username                                                                   |
| INSTALL_ADMIN_PASSWORD               | shopware         | Default admin password                                                                   |
| PHP_SESSION_HANDLER                  | files            | Set to `redis` for redis session                                                         |
| PHP_SESSION_SAVE_PATH                | (empty)          | Set to `tcp://redis:6379` for redis session                                              |
| PHP_MAX_UPLOAD_SIZE                  | 128m             | See PHP documentation                                                                    |
| PHP_MAX_EXECUTION_TIME               | 300              | See PHP documentation                                                                    |
| PHP_MEMORY_LIMIT                     | 512m             | See PHP documentation                                                                    |
| FPM_PM                               | dynamic          | [See PHP FPM documentation](https://www.php.net/manual/en/install.fpm.configuration.php) |
| FPM_PM_MAX_CHILDREN                  | 5                | [See PHP FPM documentation](https://www.php.net/manual/en/install.fpm.configuration.php) |
| FPM_PM_START_SERVERS                 | 2                | [See PHP FPM documentation](https://www.php.net/manual/en/install.fpm.configuration.php) |
| FPM_PM_MIN_SPARE_SERVERS             | 1                | [See PHP FPM documentation](https://www.php.net/manual/en/install.fpm.configuration.php) |
| FPM_PM_MAX_SPARE_SERVERS             | 3                | [See PHP FPM documentation](https://www.php.net/manual/en/install.fpm.configuration.php) |


## Volumes

In a very basic setup when all files are stored locally you need 5 volumes:

| Usage                  | Path                           |
|------------------------|--------------------------------|
| invoices/private files | /var/www/html/files            |
| theme files            | /var/www/html/public/theme     |
| images                 | /var/www/html/public/media     |
| image thumbnails       | /var/www/html/public/thumbnail |
| generated sitemap      | /var/www/html/public/sitemap   |

It is recommanded to use an external storage provider when possible to store the files. With an external storage provider you won't need any mounts. Refer to [official Shopware docs for setup](https://developer.shopware.com/docs/guides/hosting/infrastructure/filesystem).

## FAQ

<details>
  <summary>Use Redis for sessions</summary>

   You can set `PHP_SESSION_HANDLER` to `redis` and `PHP_SESSION_SAVE_PATH` to any redis path like `tcp://redis:6379`
</details>

## Known issues

<details>
  <summary>Assets are stored locally, but asset-manifest.json tries to write to external location</summary>

Override the filesystem of asset-manifest.json to temporary filesystem:

```yaml
# config/packages/prod/asset-overwrite.yaml
services:
    Shopware\Core\Framework\Plugin\Util\AssetService:
        arguments:
            - '@shopware.filesystem.asset'
            - '@shopware.filesystem.temp'
            - '@kernel'
            - '@Shopware\Core\Framework\Plugin\KernelPluginLoader\KernelPluginLoader'
            - '@Shopware\Core\Framework\Adapter\Cache\CacheInvalidator'
            - '@Shopware\Core\Framework\App\Lifecycle\AppLoader'
            - '@parameter_bag'
```
    
</details>
