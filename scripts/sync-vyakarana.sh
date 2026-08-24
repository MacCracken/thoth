#!/usr/bin/env bash
# Re-sync the vendored vyakarana tokenizer bundle.
#
# vyakarana is consumed as a single committed file, src/vendor/vyakarana.cyr,
# the same vendored-dist pattern as avatara / bote-core / t-ron / libro (see
# scripts/sync-avatara.sh). It supplies source-code tokenization for syntax
# highlighting — `/read`, the `/git` per-file diff, and markdown fenced-code
# blocks in the reply feed. thoth READS the emitted token spans and authors
# only the span->SGR glue in src/diff.cyr / src/mdhl.cyr; it never
# reimplements a lexer.
#
# Until 0.38.6 this file was hand-vendored with NO script — the gap
# docs/development/state.md recorded. This script closes it.
#
# NOTE: the bundle is self-contained over the stdlib already in
# [deps].stdlib, so adopting it adds no new module.
#
# ⚠ COLLISION WATCH: vyakarana carries `_stream_*` helpers. Through sankoch
# 2.4.8 the FULL sankoch bundle also defined `_stream_grow` and thoth had to
# sed one of them; the lean `[lib.zlib]` profile thoth vendors today drops
# sankoch's stream.cyr, so there is no rename left to apply. If a new
# `duplicate fn` warning naming a `_stream_*` symbol ever appears in the build,
# that is this hazard returning — diff the build's warning SET before and
# after a sync, not just its pass/fail.
#
# Usage: ./scripts/sync-vyakarana.sh [tag]   (default: 2.4.0)
set -euo pipefail

TAG="${1:-2.4.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/vyakarana.cyr"

# For pre-release / offline dev, point at a local checkout's working-tree dist:
#   VYAKARANA_LOCAL=/path/to/vyakarana ./scripts/sync-vyakarana.sh
if [ -n "${VYAKARANA_LOCAL:-}" ]; then
    echo "Syncing vyakarana $TAG from local $VYAKARANA_LOCAL/dist/vyakarana.cyr"
    mkdir -p "$REPO_ROOT/src/vendor"
    cp "$VYAKARANA_LOCAL/dist/vyakarana.cyr" "$DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/vyakarana/${TAG}/dist/vyakarana.cyr"
    echo "Syncing vyakarana $TAG from $URL"
    mkdir -p "$REPO_ROOT/src/vendor"
    curl -sSf "$URL" -o "$DEST"
fi

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
