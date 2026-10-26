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
