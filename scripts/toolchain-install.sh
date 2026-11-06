#!/bin/sh
# Install the cyrius pin in cyrius.cyml on a fresh machine, from files whose SHA-256 this tree records (scripts/toolchain.sums).
#
# On a fresh runner `curl .../install.sh | sh` checks nothing that matters: there is no cyrsign yet, so the installer trusts a sum from the
# tarball's own origin, and a cut download of a script piped to sh exits 0 half-applied (audit B-1, B-8). Here both files are downloaded first,
# checked against the tree, and only then run: CYRIUS_INSTALL_TARBALL has the installer take the checked tarball as it stands.
#
# A pin bump needs scripts/toolchain-sums.sh, and this refuses until it has run. Linux x86_64 only: it is what CI runs on.
set -eu
PIN="$(grep '^cyrius = ' cyrius.cyml | head -1 | sed 's/cyrius = "\(.*\)"/\1/')"
SUMS="$(pwd)/scripts/toolchain.sums"
HAVE="$(sed -n 's/^# cyrius //p' "$SUMS")"
if [ "$HAVE" != "$PIN" ]; then
    echo "toolchain-install: cyrius.cyml pins $PIN but scripts/toolchain.sums records $HAVE: run scripts/toolchain-sums.sh" >&2
    exit 1
fi
TAR="cyrius-$PIN-x86_64-linux.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl --proto '=https' -sSfL --max-time 120 "https://raw.githubusercontent.com/MacCracken/cyrius/$PIN/scripts/install.sh" -o "$TMP/install.sh"
curl --proto '=https' -sSfL --max-time 300 "https://github.com/MacCracken/cyrius/releases/download/$PIN/$TAR" -o "$TMP/$TAR"
(cd "$TMP" && grep -v '^#' "$SUMS" | sha256sum -c --quiet -)
CYRIUS_VERSION="$PIN" CYRIUS_INSTALL_TARBALL="$TMP/$TAR" sh "$TMP/install.sh"
