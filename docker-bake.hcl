# Shared settings; load with docker-bake.fpm.hcl or docker-bake.frankenphp.hcl.

variable "imageSuffix" {
    default = ""
}

variable "tagPrefix" {
    default = ""
}

variable "phpLibraryRef" {
    default = "e3eaff845f7a9f7259c31da54dce0320b47a3bbd"
}

# Leave empty to build all supported PHP minor versions.
variable "phpMinor" {
    default = ""
}
