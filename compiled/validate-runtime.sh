#!/bin/sh
set -eu

# shellcheck disable=SC1091
. /etc/os-release
release() {
    # Alpine patch images remain ABI-compatible within a release branch.
    if [ "$ID" = alpine ]; then
        printf '%s:%s\n' "$ID" "$(printf '%s' "$VERSION_ID" | cut -d. -f1,2)"
    else
        printf '%s:%s\n' "$ID" "$VERSION_ID"
    fi
}
runtime_os=$(release)
# shellcheck disable=SC1091
. /compiled/os-release
compiled_os=$(release)
test "$runtime_os" = "$compiled_os" || {
    echo "Compiled artifacts require $compiled_os; runtime is $runtime_os" >&2
    exit 1
}
test "$(uname -m)" = "$(cat /compiled/architecture)"
if [ -n "${PHP_VERSION:-}" ]; then
    test "$PHP_VERSION" = "$(cat /compiled/php-version)"
fi
