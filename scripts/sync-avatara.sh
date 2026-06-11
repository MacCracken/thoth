#!/usr/bin/env bash
# Re-sync the vendored avatara archetype bundle.
#
# avatara is consumed as a single committed file, src/vendor/avatara.cyr,
# the same vendored-dist pattern as bote-core / t-ron / libro (see
# scripts/sync-tron.sh). It supplies the Thoth / Librarian persona — thoth
# READS the emitted archetype profile (egyptian_thoth() + the prof_* accessors)
# and authors only profile->string glue; it never reimplements archetype logic
# (ADR-0003). The off-AGNOS overlay over the same contract.
#
# NOTE: the bundle's only non-builtin stdlib need is the `math` module
# (f64_le / f64_ge — the other f64 ops are compiler builtins), so thoth's
# cyrius.cyml [deps].stdlib declares `math`. The bundle also carries a benign
# `ERR_NONE = 0` that matches the vendored libro's identical constant (same
# value; last definition wins) and its own self-contained `xalloc` (an OOM
# guard over stdlib alloc — defined nowhere else). No fn/type collisions with
# the other bundles, the stdlib, or thoth's own source.
#
# Usage: ./scripts/sync-avatara.sh [tag]   (default: 2.7.1)
set -euo pipefail

TAG="${1:-2.7.1}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/avatara.cyr"
URL="https://raw.githubusercontent.com/MacCracken/avatara/${TAG}/dist/avatara.cyr"

echo "Syncing avatara $TAG from $URL"
mkdir -p "$REPO_ROOT/src/vendor"
curl -sSf "$URL" -o "$DEST"

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
