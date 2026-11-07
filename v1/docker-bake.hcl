# Shared settings; load with v1/fpm/docker-bake.hcl or v1/frankenphp/docker-bake.hcl.

variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

# github-builder supplies the value through its build-secrets input.
# Local builds can provide the same optional secret via COMPOSER_AUTH.
target "_build-secrets" {
    secret = ["id=composer_auth,env=COMPOSER_AUTH"]
}
