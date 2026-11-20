variable "frankenphpMatrix" {
    default = [ "8.2.36", "8.3.37", "8.4.28", "8.5.13" ]
}

variable "frankenphpVersion" {
    default = "v1.13.5"
}

# Commit of https://github.com/php/frankenphp that frankenphpVersion points to;
# pinned so a moved tag cannot change what is built.
variable "frankenphpRef" {
    default = "a3663e9e2cc4c258018a28ee068e50cc12f3ed2d"
}

variable "goVersion" {
    default = "1.27"
}

# PHP (ZTS) and FrankenPHP built from source with the upstream Dockerfiles

target "php-zts-trixie" {
    name = "php-zts-trixie-${replace(substr(php, 0, 3), ".", "-")}"
    context = "https://github.com/shopwareLabs/docker-php-library.git#${phpLibraryRef}:${substr(php, 0, 3)}/trixie/zts"
    matrix = {
        "php" = frankenphpMatrix
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

target "frankenphp-upstream" {
    name = "frankenphp-upstream-${replace(substr(php, 0, 3), ".", "-")}"
    context = "https://github.com/php/frankenphp.git#${frankenphpRef}"
    target = "runner"
    matrix = {
        "php" = frankenphpMatrix
    }
    contexts = {
        php-base = "target:php-zts-trixie-${replace(substr(php, 0, 3), ".", "-")}"
        golang-base = "docker-image://docker.io/library/golang:${goVersion}-trixie"
    }
    args = {
        "FRANKENPHP_VERSION" = frankenphpVersion
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

# Frankenphp

target "frankenphp" {
    inherits = ["_build-secrets"]
    name = "frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./v1/frankenphp"
    matrix = {
        "php" = frankenphpMatrix
    }
    contexts = {
        base = "target:frankenphp-upstream-${replace(substr(php, 0, 3), ".", "-")}"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp"
    ]
}

target "frankenphp-otel" {
    inherits = ["_build-secrets"]
    name = "frankenphp-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./v1/frankenphp/otel"
    matrix = {
        "php" = frankenphpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp-otel"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp-otel",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp-otel",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-frankenphp-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-frankenphp-otel"
    ]
}
