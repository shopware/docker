variable "frankenphpMatrix" {
    default = [ "8.2.35", "8.3.36", "8.4.27", "8.5.12" ]
}

variable "frankenphpRef" {
    default = "v1.13.1"
}

variable "goVersion" {
    default = "1.27"
}

# PHP built from source with the upstream docker-library/php Dockerfiles

target "php-zts-trixie" {
    name = "php-zts-trixie-${replace(substr(php, 0, 3), ".", "-")}"
    context = "https://github.com/docker-library/php.git#${phpLibraryRef}:${substr(php, 0, 3)}/trixie/zts"
    matrix = {
        "php" = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

target "frankenphp-upstream" {
    name = "frankenphp-upstream-${replace(substr(php, 0, 3), ".", "-")}"
    context = "https://github.com/php/frankenphp.git#${frankenphpRef}"
    target = "runner"
    matrix = {
        "php" = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        php-base = "target:php-zts-trixie-${replace(substr(php, 0, 3), ".", "-")}"
        golang-base = "docker-image://docker.io/library/golang:${goVersion}-trixie"
    }
    args = {
        "FRANKENPHP_VERSION" = frankenphpRef
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

# Frankenphp

target "frankenphp" {
    name = "frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./frankenphp"
    matrix = {
        "php" = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
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
    name = "frankenphp-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./frankenphp-otel"
    matrix = {
        "php" = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
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
