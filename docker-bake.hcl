# Empty phpMinor builds the complete supported matrix.
variable "phpMinor" { default = "" }
variable "compiledRegistry" { default = "ghcr.io/shopware/docker-php-artifacts" }
variable "compiledKey" { default = "local" }
# Local builds follow the compilation graph; CI consumes published artifact images.
variable "compiledSource" { default = "local" }
variable "compiledRevision" { default = "1" }
variable "osPackagesRefresh" { default = formattimestamp("YYYY-MM-DD", timestamp()) }

function "artifactContext" {
    params = [variant, php]
    result = compiledSource == "local" ? "target:artifacts-${variant}-${replace(substr(php, 0, 3), ".", "-")}" : "docker-image://${compiledRegistry}:${compiledKey}-${variant}-${php}"
}

variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

variable "phpMatrix" {
    default = [ "8.2.35", "8.3.36", "8.4.27", "8.5.12" ]
}

variable "frankenphpMatrix" {
    default = [ "8.2.35", "8.3.36", "8.4.27", "8.5.12" ]
}

variable "phpLibraryRef" {
    default = "e3eaff845f7a9f7259c31da54dce0320b47a3bbd"
}

variable "alpineVersion" {
    default = "3.24"
}

variable "frankenphpRef" {
    default = "v1.13.2"
}

variable "goVersion" {
    default = "1.27"
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
        artifacts = artifactContext("frankenphp", php)
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
    args = {
        PHP_VERSION = php
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
    }
}

target "frankenphp-otel" {
    name = "frankenphp-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./frankenphp"
    matrix = {
        "php" = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        artifacts = artifactContext("frankenphp", php)
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
    args = {
        ENABLE_OTEL = "1"
        PHP_VERSION = php
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
    }
}

# FPM

target "fpm" {
    name = "fpm-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        artifacts = artifactContext("fpm", php)
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
    args = {
        PHP_VERSION = php
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
    }
}

target "fpm-otel" {
    name = "fpm-otel-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./fpm"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        artifacts = artifactContext("fpm", php)
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
    args = {
        ENABLE_OTEL = "1"
        PHP_VERSION = php
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
    }
}

# Caddy

target "caddy" {
    name = "caddy-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./caddy"
    matrix = {
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-${replace(substr(php, 0, 3), ".", "-")}"
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
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-otel-${replace(substr(php, 0, 3), ".", "-")}"
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
        "php"  = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "target:caddy-otel-${replace(substr(php, 0, 3), ".", "-")}"
    }
    args = {
        "NODE_VERSION" = node
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
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
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-${replace(substr(php, 0, 3), ".", "-")}"
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
        "php" = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:fpm-otel-${replace(substr(php, 0, 3), ".", "-")}"
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
        "php"  = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
        "node" = [ "22", "24" ]
    }
    contexts = {
        base = "target:nginx-otel-${replace(substr(php, 0, 3), ".", "-")}"
    }
    args = {
        "NODE_VERSION" = node
        ALPINE_VERSION = alpineVersion
        OS_PACKAGES_REFRESH = osPackagesRefresh
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-node${node}-nginx",
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${php}-node${node}-nginx"
    ]
}

# Heavy compilation is published separately from the daily runtime images.

target "compiled-fpm" {
    name = "compiled-fpm-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./compiled"
    dockerfile = "fpm.Dockerfile"
    matrix = {
        php = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:php-fpm-alpine-${replace(substr(php, 0, 3), ".", "-")}"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

target "artifacts-fpm" {
    name = "artifacts-fpm-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./compiled"
    matrix = {
        php = [for php in phpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:compiled-fpm-${replace(substr(php, 0, 3), ".", "-")}"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [ "${compiledRegistry}:${compiledKey}-fpm-${php}" ]
}

target "compiled-frankenphp" {
    name = "compiled-frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./compiled"
    dockerfile = "frankenphp.Dockerfile"
    matrix = {
        php = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:frankenphp-upstream-${replace(substr(php, 0, 3), ".", "-")}"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
}

target "artifacts-frankenphp" {
    name = "artifacts-frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    context = "./compiled"
    matrix = {
        php = [for php in frankenphpMatrix : php if phpMinor == "" || substr(php, 0, 3) == phpMinor]
    }
    contexts = {
        base = "target:compiled-frankenphp-${replace(substr(php, 0, 3), ".", "-")}"
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [ "${compiledRegistry}:${compiledKey}-frankenphp-${php}" ]
}

group "compiled" {
    targets = [ "artifacts-fpm", "artifacts-frankenphp" ]
}

target "_compiled-inputs" {
    args = { COMPILED_REVISION = compiledRevision }
}

group "daily" {
    targets = [ "fpm", "fpm-otel", "frankenphp", "frankenphp-otel", "caddy", "caddy-otel", "nginx", "nginx-otel", "caddy-dev", "nginx-dev" ]
}
