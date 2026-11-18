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
    default = "b2d8ba085a7b04175b33e23c0e3603dd6b6e34a9"
}
