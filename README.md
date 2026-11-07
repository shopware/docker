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
Changes to shared Bake settings, the publishing workflow or matrix script trigger both families.
Both workflows also support manual runs and daily rebuilds.

CI uses [docker/github-builder](https://github.com/docker/github-builder)'s Bake
workflow with native GitHub-hosted `ubuntu-26.04` (AMD64) and `ubuntu-26.04-arm`
(ARM64) runners. Each concrete Bake target gets its own build, and the reusable
workflow combines both architectures into the published image. Namespace is no
longer required. Builds retain the existing no-cache behavior for fresh daily
dependency installation.

`scripts/bake-matrix.mjs` derives the publication images and tags from Bake for
the reusable workflow. Normal builds publish the existing Docker Hub and GHCR
tags; pull requests publish the existing numbered `-ci-test` images to GHCR.
Publishing still requires a token with package write access, and normal builds
use `DOCKER_HUB_USERNAME` and `DOCKER_HUB_PASSWORD`. Fork pull requests do not
receive those publishing credentials. Composer authentication is passed as a
BuildKit secret through the reusable workflow.

Validate the matrices locally with `node --test scripts/bake-matrix.test.mjs`
(requires Docker Buildx; no images are built or pushed).

Run `node scripts/update-php-matrix.mjs` from the repository root to update the
PHP patch versions in the family-specific Bake files.
