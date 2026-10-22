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

Derived images use internal Bake targets that select the Dockerfiles' `build`
stages. Bake builds these dependencies automatically; publishing base images first
is not required. Internal `*-build` targets are not published.

Every published image ends with a `runtime` stage that upgrades installed OS
packages using `apk upgrade` or `apt-get upgrade --with-new-pkgs`. Bake passes the
current UTC date as `OS_PACKAGES_REFRESH`, refreshing this layer once per day while
reusing the PHP, gRPC and other extension compilation layers. Derived images use
the stages before this upgrade, so a daily refresh does not invalidate their
compilation cache either. Changes to other build inputs can still rebuild these
layers.

To force another package refresh on the same day, override `osPackagesRefresh`:

```sh
osPackagesRefresh="$(date -u +%Y-%m-%d)-2" phpMinor=8.4 \
    docker buildx bake -f docker-bake.hcl -f docker-bake.fpm.hcl fpm
```

When invoking `docker buildx build` directly, pass
`--build-arg OS_PACKAGES_REFRESH="$(date -u +%Y-%m-%d)"` explicitly. OS upgrades
add replacement files over the cached layers, increasing image size. They do not
update source-built PHP/extensions or libraries statically linked into them;
those still require rebuilding their compilation stages. Compiled extensions must
remain compatible with upgraded runtime libraries.

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

CI uses the shared `.github/action/build-bake-publish` composite action, rather than
reusable workflows. Each PHP minor runs in a single job, setting up Namespace's
remote builder once with layer caching enabled. Sequential Bake steps publish each
image group, reusing internal build stages across steps. Both CPU
architectures and dev Node variants stay together in Bake. Tags and registry
destinations come directly from the Bake files. The FPM job also runs the existing
checks for the applicable PHP minor, sharing application smoke-test steps through
`.github/action/test-webserver`.
