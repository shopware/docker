# v2026.1 images — built alongside v1 (see adr/2026-07-08-docker-image-variant-v2.md)
#
# Build from the repository root: docker buildx bake -f v2026.1/docker-bake.hcl <target>
# NOTE: bake resolves relative context paths against the working directory,
# not this file — paths below are therefore relative to the repository root.

variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

# Calendar version of this contract (ADR section 1) — matches the directory name
variable "imageVersion" {
    default = "v2026.1"
}

# Lifecycle dates baked into every image (ADR section 7).
# Empty = not scheduled yet. Format: YYYY-MM-DD.
variable "securityOnlyDate" {
    default = ""
}

variable "eolDate" {
    default = ""
}

# Set by CI for OCI labels
variable "gitSha" {
    default = ""
}

variable "buildDate" {
    default = ""
}

# Updated by update-php-matrix.mjs. The digest pins the multi-arch manifest
# list of dunglas/frankenphp:php<version> so rebuilds are reproducible (ADR section 6).
variable "frankenphpDigestMatrix" {
    default = [
        { php = "8.2.33", digest = "sha256:ab7284dddea6f9430986918b270d09adf751e8edb2053ab2cac50240a39959bb" },
        { php = "8.3.33", digest = "sha256:b603d870b1b741bac8e509fa865a8e0901d760805a972de640a97b0d1f6fed69" },
        { php = "8.4.24", digest = "sha256:96560b9b3ec5be4f4784ebde460d4c176d7d05d801091b871bad56636bd822ab" },
        { php = "8.5.9", digest = "sha256:e2fb833fac0135f9a070647a8c70eb80ba282de4a035de56b6a3371cb555eca0" }
    ]
}

# Single source of truth for the PHP extension set (ADR section 5).
# Core extensions are versioned implicitly by the pinned PHP base image.
variable "installPhpExtensionsVersion" {
    default = "2.11.12"
}

variable "coreExtensions" {
    default = "bcmath gd intl mysqli pdo_mysql pcntl sockets bz2 gmp soap zip ftp ffi opcache xsl"
}

variable "pinnedExtensions" {
    default = "redis-6.3.0 apcu-5.1.28 amqp-2.2.0 zstd-0.18.0"
}

# Installed but not loaded by default (ADR section 3);
# enabled via PHP_EXTENSION_GRPC=1 / PHP_EXTENSION_OPENTELEMETRY=1
variable "optionalExtensions" {
    default = "grpc-1.83.0 opentelemetry-1.2.1"
}

variable "devPinnedExtensions" {
    default = "xdebug-3.5.3"
}

target "frankenphp" {
    name = "frankenphp-${replace(substr(item.php, 0, 3), ".", "-")}"
    context = "./v2026.1/frankenphp"
    matrix = {
        "item" = frankenphpDigestMatrix
    }
    args = {
        "PHP_BASE_IMAGE" = "dunglas/frankenphp:php${item.php}@${item.digest}"
        "INSTALL_PHP_EXTENSIONS_VERSION" = installPhpExtensionsVersion
        "PHP_CORE_EXTENSIONS" = coreExtensions
        "PHP_PINNED_EXTENSIONS" = pinnedExtensions
        "PHP_OPTIONAL_EXTENSIONS" = optionalExtensions
        "IMAGE_VERSION" = imageVersion
        "IMAGE_SECURITY_ONLY_DATE" = securityOnlyDate
        "IMAGE_EOL_DATE" = eolDate
    }
    labels = {
        "org.opencontainers.image.source" = "https://github.com/shopware/docker"
        "org.opencontainers.image.revision" = gitSha
        "org.opencontainers.image.version" = imageVersion
        "org.opencontainers.image.created" = buildDate
        "com.shopware.image.version" = imageVersion
        "com.shopware.image.security-only" = securityOnlyDate
        "com.shopware.image.eol" = eolDate
    }
    attest = [
        "type=sbom",
        "type=provenance,mode=max"
    ]
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(item.php, 0, 3)}-frankenphp-${imageVersion}",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${item.php}-frankenphp-${imageVersion}"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(item.php, 0, 3)}-frankenphp-${imageVersion}",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${item.php}-frankenphp-${imageVersion}",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(item.php, 0, 3)}-frankenphp-${imageVersion}",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${item.php}-frankenphp-${imageVersion}"
    ]
}

target "dev" {
    name = "dev-${replace(substr(item.php, 0, 3), ".", "-")}-${node}"
    context = "./v2026.1/dev"
    matrix = {
        "item" = frankenphpDigestMatrix
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${item.php}-frankenphp-${imageVersion}"
    }
    args = {
        "NODE_VERSION" = node
        "PHP_DEV_PINNED_EXTENSIONS" = devPinnedExtensions
    }
    labels = {
        "org.opencontainers.image.source" = "https://github.com/shopware/docker"
        "org.opencontainers.image.revision" = gitSha
        "org.opencontainers.image.version" = imageVersion
        "org.opencontainers.image.created" = buildDate
        "com.shopware.image.version" = imageVersion
        "com.shopware.image.security-only" = securityOnlyDate
        "com.shopware.image.eol" = eolDate
    }
    attest = [
        "type=sbom",
        "type=provenance,mode=max"
    ]
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}${substr(item.php, 0, 3)}-node${node}-${imageVersion}",
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}${item.php}-node${node}-${imageVersion}"
    ]
}
