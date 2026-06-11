#!/usr/bin/env bash
# Re-sync the vendored t-ron authorization bundle.
#
# t-ron is consumed as a single committed file, src/vendor/t-ron.cyr, rather
# than via a [deps.t-ron] block in cyrius.cyml: t-ron's manifest declares
# [deps.libro] + [deps.bote] git sub-deps, which `cyrius deps` resolves
# transitively into a colliding compile set (the same class of problem that
# made hoosh vendor bote-core — see scripts/sync-bote.sh). The dist bundle
# is consumed directly; its libro (audit chain) and bote-core (dispatcher)
# call surfaces are satisfied by the sibling vendored bundles, and glob_match
# by the stdlib `regex` dep.
#
# NOTE: t-ron's bundle carries its own chacha20_xor, colliding benignly with
# stdlib sigil's (same signature + semantics; last definition wins). Known
# and accepted in t-ron's own 2.1.5 notes.
#
# Usage: ./scripts/sync-tron.sh [tag]   (default: 2.1.5)
set -euo pipefail

TAG="${1:-2.1.5}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/t-ron.cyr"
URL="https://raw.githubusercontent.com/MacCracken/t-ron/${TAG}/dist/t-ron.cyr"

echo "Syncing t-ron $TAG from $URL"
mkdir -p "$REPO_ROOT/src/vendor"
curl -sSf "$URL" -o "$DEST"

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
