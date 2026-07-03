#!/usr/bin/env bash
# Re-sync the vendored sit READ bundle + its sankoch (zlib) dependency.
#
# thoth consumes sit for git branch/status/diff (the 0.13.0 git producer) as
# TWO committed files, NOT a [deps.sit] block: sit's manifest declares git
# sub-deps that `cyrius deps` would resolve into a colliding compile set (same
# reason bote/t-ron are vendored). We vendor sit's LEAN read profile
# (`dist/sit-read.cyr`, the `[lib.read]` distlib profile added in sit 1.3.0) —
# not the full `dist/sit.cyr` — so thoth pulls only the read path and NOT the
# sign/wire/wire_http/serve modules, which would otherwise force shim constants
# (HSV_REQ_BUF_SIZE / TLS_OK) and unresolved wire_ssh warnings. Only the
# read-only `sit_repo_*` API is called; its command layer is dead here.
#
# sankoch (zlib/DEFLATE) is a sit dep the bundle references bare (git objects are
# zlib-compressed → even READ inflates through it). We pin sankoch **2.2.5**, NOT
# the 2.4.8 sit itself resolves: 2.4.8 declares 175 initialised `var` globals and
# thoth + sit-read + 2.4.8 blows cyrius's fixed max-1024-initialised-globals cap.
# 2.2.5 (50 globals) has both `zlib_compress`/`zlib_decompress` sit-read calls,
# base inflate is unchanged 2.2.5→2.4.8, and it keeps the absolute 16 MiB output
# cap — correct + adequately safe for read-only git-object inflate. (Proper fix:
# sankoch converting its 171 scalar `var` constants to enum members per the AGNOS
# convention; then thoth can track current sankoch. Tracked in sankoch's backlog.)
#
# Vendored-collision renames (different-semantics same-name clashes with thoth's
# established spine bundles — sit's copies are the unused ones here, so we namespace
# THEM, not thoth's). All are blunt `\b`-bounded sed on the vendored copy:
#  * sankoch `_stream_grow(ctx)` vs vyakarana `_stream_grow(s, needed)` → `_sk_stream_grow`.
#  * sit-read `entry_hash(e){return e;}` (a tree accessor) vs **libro**'s `entry_hash`
#    (the audit-chain hash getter, called 13× incl. `str_builder_add(sb, entry_hash(e))`)
#    → `_sit_entry_hash`. Without this, sit's identity fn wins the last-def and libro's
#    audit chain reads a pointer as a hash string and crashes (caught by test_tron).
#  * sit-read `ann_new(a)` (a diff-op accessor) vs **bote-core**'s `ann_new()` (0-arg,
#    called at bote 461/471) → `_sit_ann_new` — an arity mismatch that would feed bote a
#    garbage arg. (Renaming sit's ann_* also renames the diff accessors thoth doesn't call
#    in 0.13.0; a future sit_diff_path consumer uses the `_sit_`-prefixed names.)
# Also: do NOT add sankoch to `cyrius.cyml [deps].stdlib` — declaring it there breaks
# thoth's own `SANDHI_OK` (sandhi enum) resolution. Vendored-as-source only.
#
# PORTABILITY: sit_repo_open does `syscall(SYS_CHDIR, cwd)` to root its relative reads.
# AGNOS's frozen syscall floor has NO chdir (nor openat/getcwd), so that reference is a
# hard undefined-variable error on the --agnos lane — it would REGRESS the AGNOS build
# (v1.0 gate 1, cleared in 0.12.3). thoth always calls sit_repo_open(".") (chdir(".") is
# a no-op), so we neutralise the call in the vendored copy (`syscall(SYS_CHDIR, cwd)` → `0`,
# leaving the guard as a folded no-op). This KEEPS the AGNOS build and makes git actually
# WORK there — sit then reads `.git`/`.sit` relative to thoth's launch cwd (the repo root),
# no chdir needed. Contract note: the vendored sit_repo_open therefore ignores its cwd arg
# (fine — thoth only ever passes "."). Upstream ask for sit: a chdir-free open for
# cwd-relative consumers (see thoth roadmap 0.13.x / a sit backlog entry).
#
# Include order in src/main.cyr: sankoch, then sit-read, BEFORE commands.cyr (so
# thoth's cmd_reset wins the benign last-def-wins vs sit's `sit reset`).
#
# For pre-release / offline dev, point at local checkouts:
#   SIT_LOCAL=/path/to/sit SANKOCH_LOCAL=/path/to/sankoch ./scripts/sync-sit.sh
# SANKOCH_LOCAL uses `git show <tag>:dist/sankoch.cyr` so the pin is tag-exact.
#
# Usage: ./scripts/sync-sit.sh [sit_tag] [sankoch_tag]   (default: 1.3.0 2.2.5)
set -euo pipefail

SIT_TAG="${1:-1.3.0}"
SK_TAG="${2:-2.2.5}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIT_DEST="$REPO_ROOT/src/vendor/sit-read.cyr"
SK_DEST="$REPO_ROOT/src/vendor/sankoch.cyr"
mkdir -p "$REPO_ROOT/src/vendor"

# --- sit read bundle (with the entry_hash / ann_new collision renames) ---
SIT_RENAME='s/\bentry_hash\b/_sit_entry_hash/g; s/\bann_new\b/_sit_ann_new/g; s/syscall(SYS_CHDIR, cwd)/0/g'
if [ -n "${SIT_LOCAL:-}" ]; then
    echo "Syncing sit-read $SIT_TAG from local $SIT_LOCAL/dist/sit-read.cyr (renaming entry_hash/ann_new)"
    sed "$SIT_RENAME" "$SIT_LOCAL/dist/sit-read.cyr" > "$SIT_DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/sit/${SIT_TAG}/dist/sit-read.cyr"
    echo "Syncing sit-read $SIT_TAG from $URL (renaming entry_hash/ann_new)"
    curl -sSf "$URL" | sed "$SIT_RENAME" > "$SIT_DEST"
fi
grep -q "^# Version: ${SIT_TAG}\$" "$SIT_DEST" || echo "WARN: $SIT_DEST header != Version: $SIT_TAG"
[ "$(grep -cE '\b(entry_hash|ann_new)\b' "$SIT_DEST")" = "0" ] || echo "WARN: unrenamed entry_hash/ann_new remains in $SIT_DEST"

# --- sankoch (rename _stream_grow → _sk_stream_grow to avoid vyakarana's) ---
if [ -n "${SANKOCH_LOCAL:-}" ]; then
    echo "Syncing sankoch $SK_TAG from local $SANKOCH_LOCAL (git show ${SK_TAG}:dist/sankoch.cyr)"
    git -C "$SANKOCH_LOCAL" show "${SK_TAG}:dist/sankoch.cyr" | sed 's/_stream_grow/_sk_stream_grow/g' > "$SK_DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/sankoch/${SK_TAG}/dist/sankoch.cyr"
    echo "Syncing sankoch $SK_TAG from $URL (renaming _stream_grow)"
    curl -sSf "$URL" | sed 's/_stream_grow/_sk_stream_grow/g' > "$SK_DEST"
fi
grep -q "^# Version: ${SK_TAG}\$" "$SK_DEST" || echo "WARN: $SK_DEST header != Version: $SK_TAG"
[ "$(grep -c '\b_stream_grow\b' "$SK_DEST")" = "0" ] || echo "WARN: unrenamed _stream_grow remains in $SK_DEST"

echo "  wrote $SIT_DEST ($(wc -l < "$SIT_DEST") lines) + $SK_DEST ($(wc -l < "$SK_DEST") lines)"
echo "  remember to bump the tags in the include comments + CHANGELOG"
