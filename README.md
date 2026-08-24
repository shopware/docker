# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + (Caddy or Nginx), which you can use to build your docker image with your code.

[Documentation can be found here](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html)

## v2 images (preview)

The v2 images implement [ADR: Docker Image Variant v2](adr/2026-07-08-docker-image-variant-v2.md) and are published **alongside** the existing (v1) images. In short:

- **Calendar-versioned tags** with a frozen contract: `ghcr.io/shopware/docker-base:8.3-frankenphp-v2026.1`. A versioned tag keeps being rebuilt for security patches, but its contract (base OS, extension set, env defaults, entrypoint behavior) never changes. Breaking changes only ship in a new calendar version.
- **Debian instead of Alpine** (glibc, matching the `dunglas/frankenphp` base).
- **One production variant**: FrankenPHP. gRPC and OpenTelemetry are installed but **not loaded by default** — enable them with `PHP_EXTENSION_GRPC=1` / `PHP_EXTENSION_OPENTELEMETRY=1`.
- **No Shopware application env baked into the image**: `APP_ENV`, `LOCK_DSN`, `MAILER_DSN`, `SHOPWARE_*`, `INSTALL_*`, … are no longer set as image `ENV`, so your container env and `.env` files stay the single source of truth. Only infrastructure defaults (`PHP_*`, `COMPOSER_*`) remain.
- **Everything pinned**: base image by digest, PECL extensions by exact version, the extension installer by release — updated through reviewed PRs, not silently at build time.
- **Dev images** are built on top of the FrankenPHP variant: `ghcr.io/shopware/docker-dev:8.3-node22-v2026.1`. Profilers (xdebug, tideways, blackfire, spx) are shipped disabled and enabled with `PHP_PROFILER=<name>`.

### v2 tags

| Image | Tags |
|---|---|
| Base | `ghcr.io/shopware/docker-base:<php>-frankenphp-v2026.1`, also on Docker Hub as `shopware/docker-base` |
| Dev | `ghcr.io/shopware/docker-dev:<php>-node<22\|24>-v2026.1` |

`<php>` is either a minor (`8.3`) or a full patch version (`8.3.33`).

### Support windows

| Version | Release | Rolling tag flips | Security-only | EOL |
|---|---|---|---|---|
| v1 (legacy, unversioned) | — | not scheduled | not scheduled | not scheduled |
| v2026.1 | preview | — | not scheduled | not scheduled |

PHP versions that reach their [upstream end of life](https://www.php.net/supported-versions.php) are dropped from all calendar versions on day one.

Every v2 image carries its lifecycle dates as OCI labels (`com.shopware.image.version`, `com.shopware.image.security-only`, `com.shopware.image.eol`) and warns at container start once a date has passed. Set `SHOPWARE_DOCKER_SUPPRESS_EOL_WARNING=1` to silence the warning.
