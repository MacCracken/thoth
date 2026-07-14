#!/usr/bin/env bash
# Re-sync the vendored anuenue HSV bundle.
#
# anuenue is consumed as a single committed file, src/vendor/anuenue.cyr, the same
# vendored-dist pattern as avatara / bote-core / t-ron / libro (see scripts/sync-avatara.sh).
# It supplies the rainbow phase model behind `/theme rainbow` — thoth READS the emitted
# hue (hsv_rainbow(phase, &rgb)) and authors only the phase->SGR glue; it never
# reimplements the HSV geometry (the spine rule: consume, never fork).
#
# NOTE: anuenue's [lib] profile (added in 1.2.0 for exactly this consumer) exports ONLY
# src/hsv.cyr — the pure geometry: one constant (ANUENUE_PHASE_MOD = 1530) and one fn
# (hsv_rainbow). It is standalone: ZERO darshana/sakshi/alloc refs, so it needs no new
# stdlib module and cannot collide with thoth's own vendored darshana. anuenue's
# filter/animate/colour/CLI machinery stays app-only and is NOT vendored here — thoth
# emits its own truecolor escapes through src/ui.cyr's existing SGR builder.
#
# Usage: ./scripts/sync-anuenue.sh [tag]   (default: 1.2.0)
set -euo pipefail

TAG="${1:-1.2.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/anuenue.cyr"
URL="https://raw.githubusercontent.com/MacCracken/anuenue/${TAG}/dist/anuenue.cyr"

echo "Syncing anuenue $TAG from $URL"
mkdir -p "$REPO_ROOT/src/vendor"
curl -sSf "$URL" -o "$DEST"

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
