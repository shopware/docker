# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + (Caddy or Nginx), which you can use to build your docker image with your code.

[Documentation can be found here](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html)

The Nginx, Caddy and FrankenPHP configurations send `script-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'` for static SVG files and existing HTML files under `public/media` and `public/thumbnail`. Application-rendered HTML and bundled HTML applications retain their own response policies. Custom static documents must work without scripts, embedded documents, base URL overrides or form submissions; images and styles remain permitted. Development images inherit the corresponding server configuration.

## Compiled artifacts and daily images

PHP, FrankenPHP and all PHP extensions are built separately using the Dockerfiles
in `compiled/`. Two artifact variants are produced per PHP version and CPU
architecture: `fpm` and `frankenphp`. Both include gRPC and OpenTelemetry; FPM also
includes Xdebug, Tideways, Blackfire and SPX. These optional extensions are disabled
in the artifacts. Regular images leave them disabled, while `-otel` images enable
gRPC and OpenTelemetry. Dev images inherit the same FPM extensions, keep gRPC
enabled, and enable a selected profiler (including OpenTelemetry) with
`PHP_PROFILER`. They add Node and development tools without a separate PHP artifact.
Production FPM images therefore also carry the disabled profiler binaries and their
runtime libraries.

Each artifact image starts from `scratch` and contains `/usr/local`, the PHP source
archive needed by `docker-php-ext-install`, a generated runtime dependency manifest,
and compatibility metadata. Alpine dependencies are
derived from ELF SONAMEs; Debian dependencies are mapped to their owning packages.
Locally compiled libraries such as FrankenPHP's watcher stay with their binaries.
Distro libraries and the compiler image's OS layers are not copied.

Daily FPM images start from Alpine and daily FrankenPHP images start from Debian
slim. They install current runtime libraries, copy compiled artifacts, and restore
the users, entrypoints, capabilities and configuration needed to run them. Explicit
runtime dependencies cover data and tools that ELF scanning cannot detect, such as
ICU data, CA certificates and curl. A UTC-date build argument refreshes package
installation and upgrades daily. Alpine patch releases within the same branch are
accepted; switching distro releases requires new compiled artifacts.

`scripts/build-images.mjs` hashes the upstream build configuration, compilation
recipes and `compiledRevision`. It builds only missing artifact images, then
assembles daily images from those artifacts. Changes to Shopware configuration or
the refresh date do not change the compilation key. CI publishes artifacts under
`ghcr.io/shopware/docker-php-artifacts:<key>-<variant>-<php-version>` and resolves
those tags to digests before building daily images. The daily build graph is
checked to contain no compilation targets. Existing public image tags are retained.

Floating extension/installer downloads are resolved when a new artifact is built;
daily package updates do not update compiled PHP, extensions, or embedded Go/static
dependencies. Change their compilation inputs to update them. To force a complete
rebuild without a source-version change, bump `compiledRevision` in Bake and use
`--no-cache-compiled` when building the new artifact key.

## Building and verifying locally

Use a local Docker builder that can read images from the local Docker image store.
The following builds all 12 variants for PHP 8.4 on the daemon's native architecture,
loads them as `shopware-local:<bake-target>`, and does not publish anything:

```sh
BUILDX_BUILDER=default phpMinor=8.4 node scripts/build-images.mjs daily
```

Choose your local builder name from `docker buildx ls` (for example `orbstack` on
macOS). Omit `phpMinor` to build every supported PHP version, or replace `daily`
with specific Bake groups such as `fpm`, `frankenphp-otel` or `caddy-dev`.
Set `LOCAL_PLATFORM=linux/amd64` or `linux/arm64` to test another architecture with
local emulation; explicit platforms use separate repositories such as
`shopware-local-amd64` and `shopware-runtime-artifacts-amd64`. Pass the same
`LOCAL_PLATFORM` to the runtime test script. `--print` shows the artifact key and selected targets without
building. `--publish` explicitly enables registry writes and both architectures;
CI uses this mode after registry login.

```sh
node tests/build-plan.mjs
node tests/verify-runtime.mjs \
    shopware-local:fpm-8-4 \
    shopware-local:frankenphp-otel-8-4 \
    shopware-local:caddy-dev-8-4-24
```

The runtime check exercises extension loading, WebP/ICU/compression functionality,
shared-library resolution, user IDs, FPM configuration, dev profiler activation,
dev tools, HTTP serving and static-media response headers. Pass all generated image
tags to check the complete matrix. It uses temporary containers and localhost ports
and removes them afterwards.

To verify a second daily refresh, rerun the build with a different value:

```sh
BUILDX_BUILDER=default phpMinor=8.4 osPackagesRefresh=local-refresh-2 \
    node scripts/build-images.mjs daily
```

The log should report that all compiled artifacts are reused. Direct
`docker buildx bake` commands also work and follow the compilation graph locally;
use the script to exercise reuse of separately stored artifact images.
