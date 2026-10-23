# Compiled PHP FPM image

This image distributes compiled PHP CLI and FPM (NTS), extensions, configuration
and helper scripts. Consuming images start directly from Alpine, copy these files,
and install their own current APK runtime packages. PHP compilation only happens
when the PHP build inputs change.

The published image starts from `scratch` and is used as a copy source. It contains:

| Path | Contents |
| --- | --- |
| `/usr/local/` | PHP binaries, extensions, configuration, helpers and license. |
| `/usr/src/php.tar.xz` | PHP source archive for installing additional extensions. |
| `/runtime-dependencies.txt` | APK packages and `so:` dependencies for all extensions. |
| `/alpine-version` | Required Alpine release branch, such as `3.24`. |
| `/php-version` | Compiled PHP patch version. |

OS libraries and the APK package database come from the consuming Alpine image.
Existing v1 images have not yet adopted these compiled files.

## Tags

The release repository is `ghcr.io/shopware/docker-php-fpm`, with multi-platform
images for `linux/amd64` and `linux/arm64`:

| Tag | Use |
| --- | --- |
| `8.4` | Follow the selected PHP minor's patch releases. |
| `8.4.27` | Select a specific PHP patch release. |
| `8.4.27@sha256:<digest>` | Pin the exact published image, including its extensions. |

The supported PHP minors are listed in [docker-bake.hcl](docker-bake.hcl).
Patch tags can be rebuilt when the extension recipe changes; use a digest when
an exact image is required.

PR builds use `ghcr.io/shopware/docker-php-fpm-ci-test:<pr>-<minor>` and
`:<pr>-<patch>`, for example `:256-8.4`. Use these tags to try changes before the
release image is published.

## Build a consuming image

Use the same Alpine release branch as the compilation image. Docker selects the
matching architecture from the multi-platform PHP image automatically. Alpine
patch updates within that branch are supported; moving to another Alpine branch
requires rebuilding PHP against it.

```dockerfile
# syntax=docker/dockerfile:1
ARG PHP_IMAGE=ghcr.io/shopware/docker-php-fpm:8.4
FROM ${PHP_IMAGE} AS php

FROM alpine:3.24

ENV PHP_INI_DIR=/usr/local/etc/php \
    PHPIZE_DEPS="autoconf dpkg-dev dpkg file g++ gcc libc-dev make pkgconf re2c" \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -pie"

RUN --mount=type=bind,from=php,source=/,target=/compiled \
    test "$(cut -d. -f1,2 /etc/alpine-release)" = "$(cat /compiled/alpine-version)" \
    && xargs apk add --no-cache < /compiled/runtime-dependencies.txt \
    && adduser -u 82 -D -S -G www-data www-data \
    && mkdir -p /var/www/html \
    && chown www-data:www-data /var/www/html

COPY --from=php /usr/local/ /usr/local/
COPY --from=php /usr/src/php.tar.xz /usr/src/php.tar.xz
COPY docker/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY --chown=www-data:www-data . /var/www/html

WORKDIR /var/www/html
ENTRYPOINT ["docker-php-entrypoint"]
STOPSIGNAL SIGQUIT
EXPOSE 9000
CMD ["php-fpm"]
```

The package manifest covers disabled extensions too, so enabling a profiler or
telemetry does not require another dependency scan. It also includes ICU data,
CA certificates and helper programs that ELF scanning cannot detect. Package
versions are resolved by the consumer's `apk add` when it builds.

Copying files does not inherit image environment variables, users, entrypoints
or commands. The example explicitly restores them. Application configuration,
a webserver, Composer, Node.js and Shopware entrypoint scripts belong in the
consuming image.

For example, `docker/php.ini` can contain:

```ini
memory_limit = 512M
upload_max_filesize = 128M
post_max_size = 128M
```

With the example above:

- Working directory: `/var/www/html`.
- Entrypoint: `docker-php-entrypoint`; default command: `php-fpm`.
- FPM listener: TCP port `9000`, using FastCGI. Connect a webserver to this port.
- FPM master user: root; default pool workers: `www-data` (UID 82).
- PHP configuration: `/usr/local/etc/php/php.ini` and `conf.d/*.ini`.
- FPM configuration: `/usr/local/etc/php-fpm.conf` and `php-fpm.d/*.conf`.

Add pool overrides in a later file such as
`/usr/local/etc/php-fpm.d/zzz-app.conf`, including a `[www]` section. Consuming
images provide their own configuration templating and environment variable
handling, including any Shopware-specific PHP or FPM settings.

Override the command to use the same image for CLI processes, for example:

```sh
docker run --rm your-app-image php bin/console about
```

## Extensions

The regular extensions are enabled, including `bcmath`, `gd`, `intl`, `mysqli`,
`pdo_mysql`, `pcntl`, `sockets`, `bz2`, `gmp`, `soap`, `zip`, `ftp`, `ffi`,
`opcache`, `xsl`, `redis`, `apcu`, `zstd` and `amqp`. PHP's base modules include
`mbstring`, `curl` and `sodium`.

The following extensions are installed but disabled:

| Extension | Configuration file under `/usr/local/etc/php/conf.d/` |
| --- | --- |
| gRPC | `grpc.disabled` |
| OpenTelemetry | `docker-php-ext-opentelemetry.disabled` |
| Xdebug | `docker-php-ext-xdebug.disabled` |
| Tideways | `docker-php-ext-tideways.disabled` |
| Blackfire | `docker-php-ext-blackfire.disabled` |
| SPX | `docker-php-ext-spx.disabled` |

Enable the extensions required by your image by renaming their configuration
files. For example, a telemetry-enabled image can add:

```dockerfile
RUN mv "$PHP_INI_DIR/conf.d/grpc.disabled" "$PHP_INI_DIR/conf.d/grpc.ini" \
    && mv "$PHP_INI_DIR/conf.d/docker-php-ext-opentelemetry.disabled" \
          "$PHP_INI_DIR/conf.d/docker-php-ext-opentelemetry.ini"
```

Enable a profiler in the same way, and add its settings in your own `.ini` file.
Selecting a profiler through `PHP_PROFILER` requires an entrypoint supplied by the
consuming image.

The `docker-php-source`, `docker-php-ext-configure`, `docker-php-ext-install`,
`docker-php-ext-enable` and `install-php-extensions` helpers are available for
additional extensions. The PHP source archive is retained for this purpose;
compiler tools are not installed in the final image.

## Rebuilds

The compiled image builds when its PHP release inputs or build recipe change, or
through a manual workflow run. PHP and extension compilation happens here.

Consuming images can rebuild daily from Alpine and the published compiled image.
Use `docker build --pull --no-cache` in that workflow to fetch the current Alpine
base and rerun `apk add`. These builds install current runtime libraries while
reusing compiled PHP and extensions. OS package updates do not update PHP or
compiled extensions.

For PHP updates, change the release version, SHA-256 checksum and signing keys in
[docker-bake.hcl](docker-bake.hcl), then publish the compiled image before rebuilding its
consumers. Local build instructions are in the [repository README](../README.md#standalone-php-fpm).
