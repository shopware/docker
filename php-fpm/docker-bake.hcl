variable "phpMinor" { default = "" }
# PHP release versions and verification inputs are maintained locally.
variable "phpMatrix" {
    default = [
        {
            version = "8.2.35"
            sha256 = "5737b98601fe5ab1b8c5db0c82ed3158acb9283ed3081ffe2faffb9ac81455e6"
            gpgKeys = "39B641343D8C104B2B146DC3F9C39DC0B9698544 E60913E4DF209907D8E30D96659A97C9CF2A795A 1198C0117593497A5EC5C199286AF1F9897469DC"
        },
        {
            version = "8.3.36"
            sha256 = "dd54693aa334c5c4d72e9aee96b082c2473750a18a6c1d105789c93a3b1692fd"
            gpgKeys = "1198C0117593497A5EC5C199286AF1F9897469DC C28D937575603EB4ABB725861C0779DC5C0A9DE4 AFD8691FDAEDF03BDF6E460563F15A9B715376CA"
        },
        {
            version = "8.4.27"
            sha256 = "dcf93923b0e38e0d5252b25b796520b5a47761a08b3488b6d0b5d1115764d3f0"
            gpgKeys = "AFD8691FDAEDF03BDF6E460563F15A9B715376CA 9D7F99A0CB8F05C8A6958D6256A97AF7600A39A6 0616E93D95AF471243E26761770426E17EBBB3DD"
        },
        {
            version = "8.5.12"
            sha256 = "08bc2eba2a588654ade1357174aa646b761556c862dda0678345ee29ed481209"
            gpgKeys = "1198C0117593497A5EC5C199286AF1F9897469DC 49D9AF6BC72A80D6691719C8AA23F5BE9C7097D4 D95C03BC702BE9515344AE3374E44BC9067701A5"
        }
    ]
}
variable "alpineVersion" { default = "3.24" }
variable "imageSuffix" { default = "" }
variable "tagPrefix" { default = "" }

target "fpm" {
    target = "artifacts"
    name = "fpm-${replace(substr(php.version, 0, 3), ".", "-")}"
    context = "./php-fpm"
    matrix = { php = [for php in phpMatrix : php if phpMinor == "" || substr(php.version, 0, 3) == phpMinor] }
    args = {
        ALPINE_VERSION = alpineVersion
        PHP_VERSION = php.version
        PHP_SHA256 = php.sha256
        GPG_KEYS = php.gpgKeys
    }
    platforms = [ "linux/amd64", "linux/arm64" ]
    tags = [
        "ghcr.io/shopware/docker-php-fpm${imageSuffix}:${tagPrefix}${substr(php.version, 0, 3)}",
        "ghcr.io/shopware/docker-php-fpm${imageSuffix}:${tagPrefix}${php.version}"
    ]
}
