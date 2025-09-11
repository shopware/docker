variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

variable "shopwareVersions" {
  default = [
    {
        version = "6.7.2.1"
        tag = "latest"
    },
    {
        version = "6.7.2.1"
        tag = "6.7.2"
    },
    {
        version = "6.7.1.2"
        tag = "6.7.1"
    },
    {
        version = "6.7.0.1"
        tag = "6.7.0"
    },
    {
        version = "6.6.10.6"
        tag = "6.6.10"
    },
    {
        version = "6.6.9.0"
        tag = "6.6.9"
    }
  ]
}

target "demo" {
    name = "demo-${replace(item.tag, ".", "-")}"
    context = "./demo"
    platforms = [ "linux/amd64", "linux/arm64" ]
    matrix = {
        item = shopwareVersions
    }
    args = {
      "SHOPWARE_VERSION" = item.version
    }
    contexts = {
        base = "docker-image://ghcr.io/shopware/docker-base${imageSuffix}:${tagPrefix}8.3-caddy"
    }
    tags = [
        "ghcr.io/shopware/demo${imageSuffix}:${tagPrefix}${item.tag}",
    ]
}
