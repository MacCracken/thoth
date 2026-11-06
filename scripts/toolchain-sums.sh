#!/usr/bin/env bash
# Record the SHA-256 of the cyrius installer and the Linux tarball for the pin in cyrius.cyml, in scripts/toolchain.sums. Run at a pin
# bump, then read the diff: this file is what CI trusts. tests/cases/vendor.cyr holds it to the pin, so a bump without it fails the suite.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
PIN="$(grep '^cyrius = ' cyrius.cyml | head -1 | sed 's/cyrius = "\(.*\)"/\1/')"
TAR="cyrius-$PIN-x86_64-linux.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl --proto '=https' -sSfL --max-time 120 "https://raw.githubusercontent.com/MacCracken/cyrius/$PIN/scripts/install.sh" -o "$TMP/install.sh"
curl --proto '=https' -sSfL --max-time 300 "https://github.com/MacCracken/cyrius/releases/download/$PIN/$TAR" -o "$TMP/$TAR"
{
    echo "# cyrius $PIN"
    (cd "$TMP" && sha256sum install.sh "$TAR")
} > scripts/toolchain.sums
echo "toolchain-sums: cyrius $PIN"
cat scripts/toolchain.sums
