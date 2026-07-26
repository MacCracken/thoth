#!/usr/bin/env bash
# Re-sync the vendored libro audit-chain bundle.
#
# libro is here ONLY because the vendored t-ron bundle calls its audit-chain
# surface (chain_new / chain_append_with_agent / chain_verify / chain_review);
# thoth has no direct libro consumer. Vendored as a committed dist file for
# the same transitive-dep reason as bote-core and t-ron (see those scripts).
# Keep the tag in lockstep with what the t-ron release pins ([deps.libro] in
# t-ron's cyrius.cyml).
#
# Usage: ./scripts/sync-libro.sh [tag]   (default: 2.8.2)
set -euo pipefail

TAG="${1:-2.8.2}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/libro.cyr"
URL="https://raw.githubusercontent.com/MacCracken/libro/${TAG}/dist/libro.cyr"

echo "Syncing libro $TAG from $URL"
mkdir -p "$REPO_ROOT/src/vendor"
curl -sSf "$URL" -o "$DEST"

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
