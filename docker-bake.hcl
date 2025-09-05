variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
  default = ""
}

variable "phpMatrix" {
  default = [ "8.1.33", "8.2.29", "8.3.25", "8.4.12" ]
}

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
    tags = [
        "shopware/docker-caddy${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-caddy",
        "shopware/docker-caddy${imageSuffix}:${tagPrefix}php${php}-caddy",

        "ghcr.io/shopware/docker-caddy${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-caddy",
        "ghcr.io/shopware/docker-caddy${imageSuffix}:${tagPrefix}php${php}-caddy"
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
    tags = [
        "shopware/docker-caddy${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-caddy-otel",
        "shopware/docker-caddy${imageSuffix}:${tagPrefix}php${php}-caddy-otel",

        "ghcr.io/shopware/docker-caddy${imageSuffix}:${tagPrefix}php${substr(php, 0, 3)}-caddy-otel",
        "ghcr.io/shopware/docker-caddy${imageSuffix}:${tagPrefix}php${php}-caddy-otel"
    ]
}

target "caddy-dev" {
    name = "caddy-dev-${replace(substr(php, 0, 3), ".", "-")}-${node}"
    context = "./dev"
    matrix = {
        "php"  = phpMatrix
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
