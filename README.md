# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + (Caddy or Nginx), which you can use to build your docker image with your code.

[Documentation can be found here](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html)

The Nginx, Caddy and FrankenPHP configurations send `script-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'` for static SVG files and existing HTML files under `public/media` and `public/thumbnail`. Application-rendered HTML and bundled HTML applications retain their own response policies. Custom static documents must work without scripts, embedded documents, base URL overrides or form submissions; images and styles remain permitted. Development images inherit the corresponding server configuration.

## Repository layout

Image generations live in their own top-level directories. The existing images
live in `v1/`; future calendar versions, such as `v2026.1/`, can coexist alongside
them with their own build definitions and configuration.

```text
v1/
├── docker-bake.hcl          # Shared v1 variables
├── fpm/
│   ├── docker-bake.hcl      # FPM and derived image targets
│   ├── Dockerfile
│   ├── rootfs/
│   ├── otel/
│   ├── caddy/
│   ├── nginx/
│   └── dev/                # Shared by the Caddy and Nginx dev images
└── frankenphp/
    ├── docker-bake.hcl
    ├── Dockerfile
    ├── rootfs/
    └── otel/
```

Shared automation lives in `.github/` and `scripts/`. The directory names do not
change the published image tags: v1 images keep their existing unversioned tags.

## Building images

Bake settings are split into shared variables in `v1/docker-bake.hcl` and targets
in `v1/fpm/docker-bake.hcl` and `v1/frankenphp/docker-bake.hcl`. Load the shared file
alongside the family you want to build. Run these commands from the repository
root, since Bake resolves build contexts relative to the working directory:

```sh
docker buildx bake -f v1/docker-bake.hcl -f v1/fpm/docker-bake.hcl fpm
docker buildx bake -f v1/docker-bake.hcl -f v1/frankenphp/docker-bake.hcl frankenphp
```

FPM targets include `fpm`, `fpm-otel`, `caddy`, `caddy-otel`, `nginx`,
`nginx-otel`, `caddy-dev` and `nginx-dev`. FrankenPHP targets are `frankenphp`
and `frankenphp-otel`. Add `--print` to inspect the build configuration.

Derived images use published base images. When changing a base image, build and
push it before building its dependents, as the CI workflows do.

The FPM and FrankenPHP workflows build independently when their files change.
Changes to shared Bake settings or the publishing action trigger both families.
Both workflows also support manual runs and daily rebuilds.

Run `node scripts/update-php-matrix.mjs` from the repository root to update the
PHP patch versions in the family-specific Bake files.

## Standalone PHP FPM

See [the consumption guide](php-fpm/README.md) for downstream Dockerfiles, image tags,
configuration and optional extensions.

`php-fpm/` compiles PHP and extensions independently of image generations.
Consumers start from Alpine, copy the compiled files, and install runtime APK
packages from the supplied dependency manifest. The published image is a scratch
image used as a copy source. It publishes
`ghcr.io/shopware/docker-php-fpm:<minor>` and `:<patch>` for AMD64 and ARM64.
v1 continues to use its existing bases; adopting this image is a separate change.
The compiled files include upstream FPM configuration and an entrypoint script.
Consumers configure their own users, environment, entrypoint and command.

The PHP build recipe and `docker-php-*` helpers are maintained locally in
`php-fpm/`, adapted from [docker-library/php](https://github.com/docker-library/php/tree/5ec2a6a0dad498e89a91a39454dbb52e98ce2bdb/8.6-rc/alpine3.24/fpm).
The original license is included as `php-fpm/LICENSE.docker-library-php`.
Builds download PHP releases directly from php.net and verify both their SHA-256
checksums and release signatures; they do not fetch Dockerfiles or scripts from
upstream. The recipe retains NTS and the build options needed by PHP 8.2–8.5.

Update each release's `version`, `sha256` and `gpgKeys` in
`php-fpm/docker-bake.hcl` when PHP changes. `alpineVersion` selects the base OS.
The existing v1 matrix updater does not change these source build inputs.

The image includes the normal FPM extensions plus gRPC, OpenTelemetry, Xdebug,
Tideways, Blackfire and SPX. Telemetry and profilers are installed but disabled.
Downstream images can enable an optional extension by renaming its `.disabled`
file in `/usr/local/etc/php/conf.d/` to `.ini`.

The standalone image builds when its PHP source inputs or extension recipe change,
with manual builds available through the workflow. Depending images can rebuild
daily from Alpine, installing current runtime packages and reusing the published
PHP binaries and extensions.

Build from the repository root:

```sh
phpMinor=8.4 docker buildx bake -f php-fpm/docker-bake.hcl \
    --set '*.platform=linux/arm64' \
    --set 'fpm-8-4.tags=shopware-php-fpm-local:fpm-8-4' --load fpm
```

Choose `linux/amd64` or `linux/arm64` for your local architecture. Omit
`phpMinor` to build the full matrix. Add `--print` to inspect the build plan.
Use `--push` to publish both architectures after registry login, without the
local platform and tag overrides. CI publishes PR images to
`ghcr.io/shopware/docker-php-fpm-ci-test:<pr>-<php-version>`.

An optional `COMPOSER_AUTH` environment variable can be passed to PIE with
`--set '*.secrets=id=composer_auth,env=COMPOSER_AUTH'`. Extension and installer
downloads are resolved when PHP is built; changes to the base recipe can be used
to update extensions between PHP releases.
