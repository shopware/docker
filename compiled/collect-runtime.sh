#!/bin/sh
set -eu

mkdir -p /artifacts/usr

if command -v apk >/dev/null; then
    apk add --no-cache --virtual .runtime-scan pax-utils
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local > /tmp/runtime-needed
    tr ',' '\n' < /tmp/runtime-needed \
        | sort -u \
        | awk 'NF && system("test -e /usr/local/lib/" $1) != 0 { print "so:" $1 }' \
        > /artifacts/runtime-dependencies.txt
else
    # Scan extensions too, including files without an executable bit.
    find /usr/local -type f \( -perm /0111 -o -name '*.so*' \) \
        -exec ldd '{}' ';' > /tmp/runtime-linkage 2>/dev/null
    if grep -q 'not found' /tmp/runtime-linkage; then
        cat /tmp/runtime-linkage >&2
        exit 1
    fi
    awk '/=> \// { print $(NF-1) }' /tmp/runtime-linkage \
        | sort -u > /tmp/runtime-libraries
    while IFS= read -r library; do
        case "$library" in /usr/local/*) continue ;; esac
        # Account for merged-/usr paths in both ldd and the package database.
        library=${library#/usr}
        # dpkg-query also emits diversion notices; only owner records end their
        # first field with a colon (possibly after an architecture qualifier).
        owners=$(dpkg-query --search "*$library")
        packages=$(printf '%s\n' "$owners" | awk 'sub(":$", "", $1) { print $1 }')
        test -n "$packages" || {
            echo "No runtime package owns $library" >&2
            exit 1
        }
        printf '%s\n' "$packages"
    done < /tmp/runtime-libraries > /tmp/runtime-packages
    sort -u /tmp/runtime-packages > /artifacts/runtime-dependencies.txt
fi

test -s /artifacts/runtime-dependencies.txt
cp /etc/os-release /artifacts/os-release
uname -m > /artifacts/architecture
php-config --version > /artifacts/php-version

# Do not copy distro libraries or their package database. Locally built libraries
# (for example libphp and FrankenPHP's watcher) stay with the binaries using them.
cp -a /usr/local /artifacts/usr/local
rm -f /artifacts/usr/local/bin/collect-runtime

# Preserve docker-php-source / docker-php-ext-install compatibility for users
# extending the published images, without carrying any installed compiler tools.
mkdir -p /artifacts/usr/src
cp /usr/src/php.tar.xz /artifacts/usr/src/php.tar.xz
