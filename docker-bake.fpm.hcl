variable "phpMatrix" {
    default = [ "8.2.35", "8.3.36", "8.4.27", "8.5.12" ]
}

variable "alpineVersion" {
    default = "3.24"
}

# PHP built from source with the upstream docker-library/php Dockerfiles

target "php-fpm-alpine" {
    name = "php-fpm-alpine-${replace(substr(php, 0, 3), ".", "-")}"
    context = "https://github.com/docker-library/php.git#${phpLibraryRef}:${substr(php, 0, 3)}/alpine${alpineVersion}/fpm"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

# FPM

target "fpm" {
    inherits = [ "_package-refresh" ]
    name = "fpm-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:php-fpm-alpine-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "fpm-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm-otel"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "caddy-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./caddy"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "caddy-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./caddy"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "caddy-dev-${replace(substr(php, 0, 3), ".", "-")}-${node}"
    context = "./dev"
    matrix = {
        "php"  = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "target:caddy-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "nginx-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./nginx"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "nginx-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./nginx"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
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
    inherits = [ "_package-refresh" ]
    name = "nginx-dev-${replace(substr(php, 0, 3), ".", "-")}-${node}"
    context = "./dev"
    matrix = {
        "php"  = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "target:nginx-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
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

# Internal stages exclude the daily upgrade and are never published.

target "fpm-build" {
    name = "fpm-build-${replace(substr(php, 0, 3), ".", "-")}"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    inherits = [ "fpm-${replace(substr(php, 0, 3), ".", "-")}" ]
    target = "build"
    tags = []
    args = {
        OS_PACKAGES_REFRESH = ""
    }
}

target "fpm-otel-build" {
    name = "fpm-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    inherits = [ "fpm-otel-${replace(substr(php, 0, 3), ".", "-")}" ]
    target = "build"
    tags = []
    args = {
        OS_PACKAGES_REFRESH = ""
    }
}

target "caddy-otel-build" {
    name = "caddy-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    inherits = [ "caddy-otel-${replace(substr(php, 0, 3), ".", "-")}" ]
    target = "build"
    tags = []
    args = {
        OS_PACKAGES_REFRESH = ""
    }
}

target "nginx-otel-build" {
    name = "nginx-otel-build-${replace(substr(php, 0, 3), ".", "-")}"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    inherits = [ "nginx-otel-${replace(substr(php, 0, 3), ".", "-")}" ]
    target = "build"
    tags = []
    args = {
        OS_PACKAGES_REFRESH = ""
    }
}
