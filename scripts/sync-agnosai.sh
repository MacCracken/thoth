#!/usr/bin/env bash
# Re-sync the vendored agnosai OUTPUT-GUARD bundle.
#
# agnosai is a full multi-agent orchestration engine — 111 modules, a 37,595-line `dist/agnosai.cyr`.
# thoth vendors NONE of that. It takes exactly one lean profile, `[lib.guard]` (agnosai 2.0.7+), which is
# two pure modules and ~530 lines: `src/units.cyr` + `src/server/output_filter.cyr`. That supplies the
# secret/PII scanner and redactor behind thoth's `[redact]` surface (0.40.0, T1-3).
#
# ⚠ WHY A PROFILE AND NOT THE FULL BUNDLE. Two independent reasons, both measured:
#  1. `dist/agnosai.cyr`'s dependency contract is INCOMPLETE. `dist/agnosai.deps` names 45 stdlib leaves
#     and omits the six `[deps.X]` git bundles the fold actually calls into — `kavach_*` (62 refs),
#     `ratelimit_*`, `sha256`, `dispatcher_*`, `accel_*`, `rng_uniform` are used in the dist and defined
#     nowhere in it. The full bundle does not link standalone.
#  2. Even if it did, taking it would collide with seams thoth already consumes: agnosai's LLM layer is a
#     second (weaker, non-streaming, tool-call-less) hoosh client whose own header names thoth's
#     `src/hoosh.cyr` as its reference implementation; its tool registry competes with daimon's; its audit
#     chain duplicates the vendored libro. See docs/development/gap-review.md.
#
# ⚠ WHY NOT HAND-EXTRACT THE TWO FILES. Because that is a fork by another name — it goes stale silently
# and the next upstream fix never reaches thoth. The `[lib.guard]` profile was added to agnosai 2.0.7 at
# thoth's request precisely so this stays ONE source of truth, the same arrangement sit's `[lib.read]` and
# sankoch's `[lib.zlib]` already give thoth.
#
# NOTE: the bundle needs the `unicode` stdlib leaf (`_uc_decode_utf8`), which is why thoth's
# `cyrius.cyml [deps].stdlib` gained `unicode` at 0.40.0. Its other leaves (alloc/io/str/string/vec/
# sakshi) were already declared.
#
# Usage: ./scripts/sync-agnosai.sh [tag]   (default: 2.0.7)
set -euo pipefail

TAG="${1:-2.0.7}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/agnosai-guard.cyr"

# For pre-release / offline dev, point at a local checkout's working-tree dist:
#   AGNOSAI_LOCAL=/path/to/agnosai ./scripts/sync-agnosai.sh
if [ -n "${AGNOSAI_LOCAL:-}" ]; then
    echo "Syncing agnosai-guard $TAG from local $AGNOSAI_LOCAL/dist/agnosai-guard.cyr"
    mkdir -p "$REPO_ROOT/src/vendor"
    cp "$AGNOSAI_LOCAL/dist/agnosai-guard.cyr" "$DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/agnosai/${TAG}/dist/agnosai-guard.cyr"
    echo "Syncing agnosai-guard $TAG from $URL"
    mkdir -p "$REPO_ROOT/src/vendor"
    curl -sSf "$URL" -o "$DEST"
fi

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }

# The whole premise of taking the profile is that it drags in no orchestration. Enforce it rather than
# trusting it: if a future profile edit pulls the engine in, this fails loudly here instead of surfacing
# as a link error or a 1.6 MB binary.
for sym in agnosai_crew agnosai_task_ agnosai_llm_ agnosai_sandbox kavach_ ratelimit_ dispatcher_; do
    if grep -q "$sym" "$DEST"; then
        echo "WARN: $DEST references '$sym' — the guard profile should carry NO orchestration/engine surface"
    fi
done
grep -q "^fn agnosai_output_redact" "$DEST" || echo "WARN: $DEST does not define agnosai_output_redact — wrong profile?"

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
