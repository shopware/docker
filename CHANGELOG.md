# Changelog

## 2026-08-24

Added the first iteration of the v2 images (see `adr/2026-07-08-docker-image-variant-v2.md`), published alongside the existing images:

- `ghcr.io/shopware/docker-base:<php>-frankenphp-v2026.1` — Debian-based FrankenPHP image with gRPC and OpenTelemetry installed but disabled by default (enable via `PHP_EXTENSION_GRPC=1` / `PHP_EXTENSION_OPENTELEMETRY=1`)
- `ghcr.io/shopware/docker-dev:<php>-node<22|24>-v2026.1` — dev image built on top of the v2 FrankenPHP image

v2 images no longer bake Shopware application environment variables (`APP_ENV`, `LOCK_DSN`, `MAILER_DSN`, `SHOPWARE_*`, `INSTALL_*`, …) into the image; only infrastructure defaults (`PHP_*`, `COMPOSER_*`) remain. The base image is pinned by digest and all PECL extensions are pinned to exact versions.

## 2024-08-13

Added zstd php extension to Docker image

## 2024-08-05

Added environment variable `COMPOSER_ROOT_VERSION` set to `1.0.0` to not require Git to find the fallback version number when not defined.

## 2024-08-02

Deprecated the installation and update scripts that were previously included in the repository. 
They will be removed November 2024, [use the Deployment Helper](https://developer.shopware.com/docs/guides/hosting/installation-updates/deployments/deployment-helper.html) as a replacement.
