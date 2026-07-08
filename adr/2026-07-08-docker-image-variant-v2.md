# Docker Image Variant v2

## Status

Proposed — discussed in [shopware/docker#150](https://github.com/shopware/docker/issues/150)

## Context

The images built from this repository are consumed by an unknown number of production deployments that we cannot reach reliably. All published tags (e.g. `ghcr.io/shopware/docker-base:8.3-frankenphp`) are **rolling**: every rebuild overwrites the tag in place. This has several consequences:

1. **We cannot ship breaking changes safely.** Any change to the base OS, bundled extensions, or default environment variables is silently rolled out to everyone on the next pull.
2. **Users cannot roll back.** When a rebuild introduces a regression (e.g. a broken extension update), the previous image is gone unless the user happened to pin a digest.
3. **Builds are not reproducible.** Several inputs are unpinned:
   - `install-php-extensions` is fetched from the `latest` GitHub release (`fpm/Dockerfile`), so the installer itself changes between builds.
   - Most extensions (`gd`, `intl`, `redis`, `soap`, …) are installed without a version constraint and resolve to whatever PECL/upstream serves at build time. Only a few are pinned today (`apcu-5.1.27`, `zstd-0.15.2`, `xdebug@3.5.0`, `amqp` via git commit), and those pins were mostly added reactively after upstream breakage.
   - `apk upgrade` / `apt-get upgrade` pulls in whatever the distribution mirrors serve.

Additionally, the current image matrix has grown large and expensive to maintain: 8 production variants (`fpm`, `fpm-otel`, `caddy`, `caddy-otel`, `nginx`, `nginx-otel`, `frankenphp`, `frankenphp-otel`) plus dev images (`caddy`/`nginx` × Node 22/24), each across 4 PHP versions and 2 CPU architectures.

Finally, the production images are Alpine-based (except FrankenPHP, which is already Debian-based). musl brings recurring problems:

- **Performance**: musl's default allocator degrades significantly under memory-intensive and multi-threaded workloads compared to glibc (reports range from 2× up to 6× slowdowns for allocation-heavy code paths).
- **Ecosystem friction**: no official Node.js binaries for musl (the dev image copies Node out of the `node:alpine` image), and extensions such as `amqp` and `grpc` need source builds with custom patches on Alpine.

## Decision

### 1. Calendar-versioned, immutable image tags

We adopt a calendar-based versioning scheme, following the model of [pimcore/docker](https://github.com/pimcore/docker#versioning):

- `ghcr.io/shopware/docker-base:8.3-frankenphp` — rolling tag (points to the latest supported version)
- `ghcr.io/shopware/docker-base:8.3-frankenphp-v2026.1` — versioned tag

Rules:

- A **versioned tag** (`-vYYYY.N`) never receives breaking changes. It continues to be rebuilt on schedule so it picks up OS security patches, PHP patch releases and extension bugfix releases, but the contract (base OS, extension list, environment variable defaults, entrypoint behavior) is frozen for its lifetime.
- **Breaking changes only ship in a new calendar version.** Users opt in by moving the suffix.
- A new calendar version deprecates the previous one. During the deprecation window the old version keeps being rebuilt (security patches only) and its image logs a deprecation warning at container start. After the window ends, the rolling (unversioned) tag switches over to the new version and the old versioned tags stop receiving rebuilds.
- Users who need bit-exact reproducibility should additionally pin by digest; versioned tags trade strict immutability for continued security patching, which is the right default for a base image.

### 2. Debian as the only base OS

v2 images are built on Debian slim (matching the base already used by `dunglas/frankenphp`) instead of Alpine:

- glibc avoids the musl allocator/threading performance issues.
- Official upstream packages (Node.js, grpc) become usable without source builds or musl patches.
- The size difference between `debian:*-slim` and Alpine is acceptable for a PHP application image where the PHP layer dominates anyway.

### 3. One production variant: FrankenPHP, batteries included

v2 reduces the production matrix to a single variant:

- `ghcr.io/shopware/docker-base:8.3-frankenphp-v2026.1`

with **gRPC and OpenTelemetry always included** (extensions installed but loadable/configurable via environment, so the cost for non-users is disk size only, not runtime overhead). The `fpm`, `caddy`, `nginx` and all `-otel` variants are not continued in v2.

Rationale: the 8-variant matrix multiplies build time, security scanning, and support surface, while FrankenPHP covers the same use cases with a single process model (and worker mode as an upside). Users who require a plain FPM pool behind their own web server can stay on v1 during the deprecation window; if there is significant demand, an `fpm` variant can be re-added to v2 in a later calendar version — the versioning scheme makes that a non-breaking addition. (Raised in the issue discussion: nginx is the familiar entry point for newcomers. We accept this trade-off in favor of a drastically smaller matrix and will address it with documentation and a migration guide rather than by keeping the variant.)

Dev images follow the same consolidation:

- `ghcr.io/shopware/docker-dev:8.3-node22-v2026.1`
- `ghcr.io/shopware/docker-dev:8.3-node24-v2026.1`

### 4. Shopware application defaults move out of the image

The image no longer bakes Shopware application-level environment variables (`APP_ENV`, `LOCK_DSN`, `MAILER_DSN`, `SHOPWARE_*`, `INSTALL_*`, …) into `ENV` layers. `ENV` values defined in the image always win over an `.env` file loaded by the application, which surprises users and makes the image dictate application config.

- **Kept in the image**: infrastructure-level defaults that configure the runtime itself (`PHP_*` ini tuning, FrankenPHP/Caddy settings, `COMPOSER_*`).
- **Removed from the image**: everything the application reads as business/deployment config. Defaults that are genuinely required for the container to boot are documented and set in the entrypoint only if unset, so both container `env` and `.env` files can override them.

(Raised in the issue discussion: container-provided env vars should stay the single source of truth. This decision preserves that — explicitly set container env always wins; the change only removes *image-baked* defaults that currently shadow both `.env` files and sane application defaults.)

### 5. PHP extension update policy

v2 makes extension management explicit and automated instead of implicit and reactive:

- **Pin everything.** Every PECL/third-party extension is installed with an exact version (`redis-6.2.0`, `apcu-5.1.27`, …) using `install-php-extensions`' version syntax. The installer itself is pinned to a release tag instead of `latest`. Core extensions (`intl`, `gd`, …) are versioned implicitly by the pinned PHP base image.
- **Automate updates.** A scheduled workflow (extending the existing `update-php-matrix` mechanism, or Renovate with a custom regex manager over a central extension manifest) opens a PR when a new extension release is available. Updates land through review + CI, not silently at build time.
- **Single source of truth.** Extension names and versions live in one place (e.g. bake variables or a manifest file consumed by the Dockerfiles) rather than being repeated per Dockerfile, so the dev image can no longer drift from the production image.
- **Update semantics per tag class**:
  - *Versioned tags* receive extension **patch/bugfix** updates via the scheduled rebuild; **major/minor** extension bumps only ship with a new calendar version, since ABI or behavior changes in extensions are breaking from the consumer's perspective.
  - *Rolling tags* follow whatever the current calendar version ships.
- **Fewer source builds.** On Debian, `grpc` and `amqp` install from upstream packages/PECL without custom patches, removing the git-commit pins and patch files that currently make those two extensions the most fragile part of the build.

### 6. Supply-chain and Dockerfile best practices

Together with v2 we adopt the following (largely orthogonal, but cheapest to introduce at a version boundary):

- **Pin base images by digest** (`FROM dunglas/frankenphp:1.x-php8.3@sha256:…`), with automated digest bumps via the update workflow, so a rebuild of an unchanged commit produces a predictable result.
- **Publish SBOM and SLSA provenance attestations** from `docker buildx` (`--sbom=true --provenance=mode=max`) and sign images with cosign, so consumers can verify what an image contains and where it was built. The existing daily vulnerability scan workflow continues to cover published images.
- **Standard OCI labels** (`org.opencontainers.image.source`, `.revision`, `.version`, `.created`) on every image so tooling can map an image back to the exact commit.
- **`HEALTHCHECK`** built into the image (FrankenPHP/Caddy exposes an endpoint), so orchestrators get container health without per-deployment configuration.
- **Keep the non-root default** (`USER www-data`, already in place) and continue to run scheduled rebuilds so OS packages stay patched between releases.

## Consequences

### Positive

- Breaking changes become shippable: users opt in per calendar version, with a documented migration path and deprecation window instead of surprise breakage.
- Rollback becomes possible: previous calendar versions keep working while a regression in the new one is fixed.
- Reproducibility and auditability improve significantly (pins + digests + SBOM/provenance).
- The build/scan/support matrix shrinks from 8 production variants to 1, cutting CI cost and the security-scan surface roughly proportionally.
- Extension updates become reviewable PRs with CI instead of silent build-time drift; the amqp/grpc patch stack disappears.
- glibc removes a whole class of musl-specific performance and compatibility issues.

### Negative

- Users of the `fpm`, `caddy` and `nginx` variants must migrate to FrankenPHP (or stay on v1 until end of deprecation). This is the largest migration cost and needs a prominent migration guide.
- Debian-based images are somewhat larger than Alpine-based ones.
- Anyone relying on the image-baked Shopware env defaults must set them explicitly after upgrading; this must be called out in the migration guide with a complete list of removed variables.
- Maintaining rebuilds for the deprecated v1 during the transition window temporarily *increases* CI load before it decreases.
- Version pinning of extensions means we must keep the update automation healthy; a stalled bot would now mean stale extensions rather than (unnoticed) auto-updates.

### Migration outline

1. Introduce versioned tags for the **current** images (retroactively tag the existing setup as `v2025.x`) so the mechanism exists before the breaking change.
2. Publish v2 images (`-v2026.1`) alongside v1.
3. Announce deprecation of v1 variants with a fixed end date; add a startup deprecation notice to v1 images.
4. After the window: point rolling tags at v2, stop rebuilding v1.

## References

- Issue: [Docker Image Variant v2 (shopware/docker#150)](https://github.com/shopware/docker/issues/150)
- Versioning model: [pimcore/docker — Versioning](https://github.com/pimcore/docker#versioning)
- Extension installer and version pinning syntax: [mlocati/docker-php-extension-installer](https://github.com/mlocati/docker-php-extension-installer)
- musl vs glibc performance: [Chainguard — glibc vs. musl](https://edu.chainguard.dev/chainguard/chainguard-images/about/images-compiled-programs/glibc-vs-musl/), [TuxCare — musl vs glibc](https://tuxcare.com/blog/musl-vs-glibc/)
- Supply chain: [Docker — SBOM generation for container workflows](https://www.docker.com/blog/sbom-generation-for-container-workflows/), [Docker image security best practices (SBOM, non-root, provenance)](https://bell-sw.com/blog/docker-image-security-best-practices-for-production/)
- Digest pinning: [Chainguard — container image digests for reproducibility](https://edu.chainguard.dev/chainguard/chainguard-images/how-to-use/container-image-digests/)
- General build best practices: [Better Stack — Docker build best practices](https://betterstack.com/community/guides/scaling-docker/docker-build-best-practices/)
