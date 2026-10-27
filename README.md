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
