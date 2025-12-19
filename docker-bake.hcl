variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

variable "phpMatrix" {
    default = [ "8.2.30", "8.3.29", "8.4.16", "8.5.1" ]
}

variable "frankenphpMatrix" {
    default = [ "8.2.29", "8.3.28", "8.4.15", "8.5.0" ]
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

# FPM

target "fpm" {
    name = "fpm-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://docker.io/library/php:${php}-fpm-alpine"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm"
    ]
}

target "fpm-otel" {
    name = "fpm-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm-otel"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm-otel"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm-otel",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm-otel",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-fpm-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm-otel"
    ]
}

# Caddy

target "caddy" {
    name = "caddy-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./caddy"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy"
    ]
}

target "caddy-otel" {
    name = "caddy-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./caddy"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm-otel"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy-otel"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy-otel",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy-otel",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-caddy-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy-otel"
    ]
}

target "caddy-dev" {
    name = "caddy-dev-${replace(substr(php, 0, 3), ".", "-")}-${node}"
    context = "./dev"
    matrix = {
        "php"  = frankenphpMatrix
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-caddy-otel"
    }
    args = {
        "NODE_VERSION" = node
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-node${node}-caddy",
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${php}-node${node}-caddy"
    ]
}

# Nginx

target "nginx" {
    name = "nginx-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./nginx"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx"
    ]
}

target "nginx-otel" {
    name = "nginx-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./nginx"
    matrix = {
        "php" = phpMatrix
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-fpm-otel"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = imageSuffix != "" ? [
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx-otel"
    ] : [
        "shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx-otel",
        "shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx-otel",

        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${substr(php, 0, 3)}-nginx-otel",
        "ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx-otel"
    ]
}

target "nginx-dev" {
    name = "nginx-dev-${replace(substr(php, 0, 3), ".", "-")}-${node}"
    context = "./dev"
    matrix = {
        "php"  = phpMatrix
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}${php}-nginx-otel"
    }
    args = {
        "NODE_VERSION" = node
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-node${node}-nginx",
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${php}-node${node}-nginx"
    ]
}
