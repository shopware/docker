# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + (Caddy or Nginx), which you can use to build your docker image with your code.

[Documentation can be found here](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html)

The Nginx, Caddy and FrankenPHP configurations send `script-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'` for static SVG files and existing HTML files under `public/media` and `public/thumbnail`. Application-rendered HTML and bundled HTML applications retain their own response policies. Custom static documents must work without scripts, embedded documents, base URL overrides or form submissions; images and styles remain permitted. Development images inherit the corresponding server configuration.

## Building images

Bake settings are split into shared variables in `docker-bake.hcl` and targets
in `docker-bake.fpm.hcl` and `docker-bake.frankenphp.hcl`. Load the shared file
alongside the family you want to build:

```sh
docker buildx bake -f docker-bake.hcl -f docker-bake.fpm.hcl fpm
docker buildx bake -f docker-bake.hcl -f docker-bake.frankenphp.hcl frankenphp
```

FPM targets include `fpm`, `fpm-otel`, `caddy`, `caddy-otel`, `nginx`,
`nginx-otel`, `caddy-dev` and `nginx-dev`. FrankenPHP targets are `frankenphp`
and `frankenphp-otel`. Add `--print` to inspect the build configuration.

Derived images use published base images. When changing a base image, build and
push it before building its dependents, as the CI workflows do.

The FPM and FrankenPHP workflows build independently when their files change.
Changes to shared Bake settings or the publishing action trigger both families.
Both workflows also support manual runs and daily rebuilds.

Each workflow derives its PHP minor-version matrix from Bake and runs an independent
build chain per minor version. Failures in one PHP version do not block the others.
Both CPU architectures remain in each build. The existing application smoke tests
run on PHP 8.3, and the dev image check runs on PHP 8.4.

To build only one PHP minor version locally:

```sh
phpMinor=8.4 docker buildx bake -f docker-bake.hcl -f docker-bake.fpm.hcl fpm
phpMinor=8.4 docker buildx bake -f docker-bake.hcl -f docker-bake.frankenphp.hcl frankenphp
```

CI uses the shared `.github/action/build-bake-publish` action to submit each Bake
build to Namespace's remote builder, with layer caching enabled. Both architectures
are built in one job; dev targets also build their Node variants together using
the Bake matrix. Tags and registry destinations come directly from the Bake files.
