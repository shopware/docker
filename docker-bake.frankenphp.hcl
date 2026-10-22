variable "frankenphpMatrix" {
    default = [ "8.2.35", "8.3.36", "8.4.27", "8.5.12" ]
}

# Frankenphp

target "frankenphp" {
    name = "frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./frankenphp"
    matrix = {
        "php" = frankenphpMatrix
    }
    args = {
        "PHP_VERSION" = php
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
