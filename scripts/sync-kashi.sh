#!/usr/bin/env bash
# Re-sync the vendored kashi console-font core.
#
# ⚠ THIS ONE IS NOT A dist/ BUNDLE. Every other sync-*.sh pulls
# `dist/<name>.cyr`; kashi's published bundle (`dist/kashi.cyr`, ~161 KB) is the
# stdlib-using LIBRARY FACE — PSF/BDF/PCF import, the runtime font registry, the
# whole loader surface. thoth's T3 GUI needs none of it: it wants bitmap glyph
# rows for a fixed 8x16 cell and nothing else. So thoth vendors kashi's
# FREESTANDING CORE, `src/font_data.cyr` (~43 KB, 13 fns), which per kashi's
# ADR-0001 uses no stdlib, no heap and no syscalls — only store8/load8 and
# integer arithmetic. That contract is why it can sit under src/gui/graster.cyr
# without dragging a loader in.
#
# Consequence: the vendored file carries NO `# Version:` header, because it is a
# module source rather than a generated bundle. Nothing self-checks it — which
# is exactly why this script exists (until 0.38.6 kashi was hand-vendored with
# no script at all, the gap docs/development/state.md recorded). Provenance
# lives in the include comment in src/main.cyr and in the CHANGELOG; this script
# is the thing that makes the claim re-checkable.
#
# ⚠ kashi gitignores /dist/, so `git show <tag>:dist/kashi.cyr` does NOT resolve
# even at a tagged release. src/font_data.cyr IS tracked — hence the raw URL
# below points at src/, not dist/.
#
# HISTORY: the core has been BYTE-IDENTICAL across the entire 1.0.x line
# (verified at 1.0.2 / 1.0.3 / 1.0.4 / 1.0.5 / 1.0.6), so a kashi version bump is
# usually a no-op on this file. Re-run the script anyway on a refresh — a no-op
# that is checked beats a no-op that is assumed.
#
# Usage: ./scripts/sync-kashi.sh [tag]   (default: 1.0.6)
set -euo pipefail

TAG="${1:-1.0.6}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/kashi.cyr"
PREV="$(mktemp)"
trap 'rm -f "$PREV"' EXIT
[ -f "$DEST" ] && cp "$DEST" "$PREV"

# For pre-release / offline dev, point at a local checkout's working tree:
#   KASHI_LOCAL=/path/to/kashi ./scripts/sync-kashi.sh
if [ -n "${KASHI_LOCAL:-}" ]; then
    echo "Syncing kashi $TAG core from local $KASHI_LOCAL/src/font_data.cyr"
    mkdir -p "$REPO_ROOT/src/vendor"
    cp "$KASHI_LOCAL/src/font_data.cyr" "$DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/kashi/${TAG}/src/font_data.cyr"
    echo "Syncing kashi $TAG core from $URL"
    mkdir -p "$REPO_ROOT/src/vendor"
    curl -sSf "$URL" -o "$DEST"
fi

# The freestanding contract is the whole reason we take src/font_data.cyr rather
# than dist/kashi.cyr — enforce it rather than trusting it.
[ "$(grep -cE '^\s*include ' "$DEST")" = "0" ] || \
    echo "WARN: $DEST has include lines — the freestanding core must have none (kashi ADR-0001)"
grep -q '^fn kashi_font_init' "$DEST" || \
    echo "WARN: $DEST does not define kashi_font_init — wrong file?"

if [ -s "$PREV" ] && cmp -s "$PREV" "$DEST"; then
    echo "  $DEST unchanged at $TAG (expected — the core is stable across 1.0.x)"
else
    echo "  $DEST CHANGED at $TAG — re-check src/gui/graster.cyr's glyph assumptions"
fi
echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
