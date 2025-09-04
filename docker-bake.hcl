variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
  default = ""
}

target "dev" {
    name = "dev-${replace(php, ".", "-")}-${node}"
    context = "./dev"
    dockerfile = "Dockerfile"
    matrix = {
        "php"  = [ "8.2", "8.3", "8.4" ]
        "node" = [ "22", "24" ]
    }
    args = {
      "PHP_VERSION" = php
      "NODE_VERSION" = node
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-dev${imageSuffix}:${tagPrefix}php${php}-node${node}"
    ]
}
