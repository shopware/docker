# Shared settings; load with v1/fpm/docker-bake.hcl or v1/frankenphp/docker-bake.hcl.

variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

# Commit of https://github.com/shopwareLabs/docker-php-library (our fork of
# docker-library/php) whose Dockerfiles are used to build PHP from source, so
# new PHP releases do not have to wait for Docker Hub.
variable "phpLibraryRef" {
    default = "427a0345cba2b98113ab7e6993099c1c823e2a69"
}

# github-builder supplies the value through its build-secrets input.
# Local builds can provide the same optional secret via COMPOSER_AUTH.
target "_build-secrets" {
    secret = ["id=composer_auth,env=COMPOSER_AUTH"]
}
