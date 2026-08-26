#!/usr/bin/env bash
# Re-sync the vendored sit READ bundle + its sankoch (zlib) dependency.
#
# thoth consumes sit for git branch/status/diff (the 0.13.0 git producer) as
# TWO committed files, NOT a [deps.sit] block: sit's manifest declares git
# sub-deps that `cyrius deps` would resolve into a colliding compile set (same
# reason bote/t-ron are vendored). We vendor sit's LEAN read profile
# (`dist/sit-read.cyr`, the `[lib.read]` distlib profile, sit 1.3.0+) — not the
# full `dist/sit.cyr` — so thoth pulls only the read path and NOT the
# sign/wire/wire_http/serve modules (which would force shim constants +
# wire_ssh warnings). Only the read-only `sit_repo_*` API is called.
#
# sankoch (zlib/DEFLATE) is a sit dep the bundle references bare (git objects are
# zlib-compressed → even READ inflates through it). We vendor sankoch's LEAN
# **zlib profile** (`dist/sankoch-zlib.cyr`, the `[lib.zlib]` distlib profile,
# sankoch 2.4.9+): just zlib_compress/zlib_decompress + closure (53 globals vs the
# full bundle's 175), so thoth tracks CURRENT sankoch and stays well under cyrius's
# fixed max-1024-initialised-globals cap. (Earlier cuts pinned the old full 2.2.5
# and neutralised a chdir; both are gone now — see below.)
#
# do NOT add sankoch to `cyrius.cyml [deps].stdlib` — declaring it there breaks
# thoth's own `SANDHI_OK` (sandhi enum) resolution. Vendored-as-source only.
#
# ONE vendored-collision rename remains (sit's own fns vs thoth's spine bundles;
# `\b`-bounded sed on the vendored sit-read copy — sit can't know thoth also
# vendors libro/bote, so this stays a thoth-side integration patch):
#  * sit-read `entry_hash(e)` (a tree accessor) vs **libro**'s `entry_hash` (the
#    audit-chain hash getter, 13 call sites incl. `str_builder_add(sb, entry_hash(e))`)
#    → `_sit_entry_hash`. Unrenamed, sit's identity fn wins the last-def and libro's
#    audit chain reads a pointer as a hash string and crashes (caught by test_tron).
#  * sit-read `ann_new(a)` (a diff-op accessor) vs **bote-core**'s `ann_new()` (0-arg,
#    called at bote 461/471) → `_sit_ann_new` — an arity mismatch that would feed bote
#    a garbage arg.
#
# DROPPED since 0.13.0 (upstream fixed the root causes):
#  * sankoch `_stream_grow` rename — GONE: the zlib profile drops stream.cyr, so the
#    `_stream_grow` that collided with vyakarana's is no longer in the bundle.
#  * `sit_repo_open` `SYS_CHDIR` neutralisation — GONE: sit 1.3.1 made sit_repo_open
#    chdir-free (reads at the process cwd), so the read profile is AGNOS-native with
#    no thoth-side patch. The whole sankoch full-bundle → 2.2.5 pin is gone too.
#
# Include order in src/main.cyr: sankoch, then sit-read, BEFORE commands.cyr (so
# thoth's cmd_reset wins the benign last-def-wins vs sit's `sit reset`).
#
# For pre-release / offline dev, point at local checkouts (uses the working-tree
# dist files — the zlib profile / 1.3.1 read bundle may not be tagged yet):
#   SIT_LOCAL=/path/to/sit SANKOCH_LOCAL=/path/to/sankoch ./scripts/sync-sit.sh
#
# ⚠ AS OF thoth 0.38.6, USE THE LOCAL PATH FOR sit. The pin of record is **1.6.2**,
# which is the fix thoth needed (sit 1.6.1's `sf_rename` named `SYS_RENAME`, which
# arm64 Linux does not define, breaking `cyrius build --aarch64` outright). That fix
# lives in sit's WORKING TREE and is not tagged/pushed yet — sit's own CLAUDE.md
# leaves git to the user — so the plain curl path will 404 on `1.6.2` until it is.
# `curl -sSf` under `set -e` makes that a loud abort rather than a silent stale file,
# which is the right failure. Until the tag exists:
#   SIT_LOCAL=/home/macro/Repos/sit SANKOCH_LOCAL=/home/macro/Repos/sankoch ./scripts/sync-sit.sh
#
# ⚠ AND KEEP THE DEFAULT ABOVE IN LOCKSTEP WITH THE PIN. Running this script with a
# stale default is a **silent DOWNGRADE** of a committed file: it exits 0, prints its
# usual success lines, and reintroduces whatever the older bundle was broken by. That
# happened during 0.38.6's own development (the default said 1.6.1 while the pin had
# moved to 1.6.2) and was caught only by `tests/cases/vendor.cyr`, which asserts the
# bundle's `# Version:` header against the pin. That test is the real gate; this
# comment is the reminder.
#
# Usage: ./scripts/sync-sit.sh [sit_tag] [sankoch_tag]   (default: 1.6.2 2.7.9)
set -euo pipefail

SIT_TAG="${1:-1.6.2}"
SK_TAG="${2:-2.7.9}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIT_DEST="$REPO_ROOT/src/vendor/sit-read.cyr"
SK_DEST="$REPO_ROOT/src/vendor/sankoch.cyr"
mkdir -p "$REPO_ROOT/src/vendor"

# --- sit read bundle (with the entry_hash / ann_new collision renames) ---
SIT_RENAME='s/\bentry_hash\b/_sit_entry_hash/g; s/\bann_new\b/_sit_ann_new/g'
# ⚠ STAGE THEN MOVE. This is the only sync script that transforms its input, so it is the only one that
# cannot use `curl -o` / `cp` — and writing the destination through `>` means the shell TRUNCATES it
# before the producer runs. Any failure (a bad SIT_LOCAL, a 404, a dropped connection) therefore left
# the committed 415 KB src/vendor/sit-read.cyr at ZERO BYTES and aborted under `set -e`; the next
# `cyrius build` then failed on missing sit_repo_* symbols rather than on the sync. sync-sit.sh is also
# the one script the docs tell you to run with SIT_LOCAL=…, i.e. the likeliest place for a path typo.
SIT_TMP="$(mktemp)"
trap 'rm -f "$SIT_TMP"' EXIT
if [ -n "${SIT_LOCAL:-}" ]; then
    echo "Syncing sit-read $SIT_TAG from local $SIT_LOCAL/dist/sit-read.cyr (renaming entry_hash/ann_new)"
    sed "$SIT_RENAME" "$SIT_LOCAL/dist/sit-read.cyr" > "$SIT_TMP"
else
    URL="https://raw.githubusercontent.com/MacCracken/sit/${SIT_TAG}/dist/sit-read.cyr"
    echo "Syncing sit-read $SIT_TAG from $URL (renaming entry_hash/ann_new)"
    curl -sSf "$URL" | sed "$SIT_RENAME" > "$SIT_TMP"
fi
[ -s "$SIT_TMP" ] || { echo "FAILED: sit-read fetch produced no bytes — $SIT_DEST left untouched" >&2; exit 1; }
mv "$SIT_TMP" "$SIT_DEST"
grep -q "^# Version: ${SIT_TAG}\$" "$SIT_DEST" || echo "WARN: $SIT_DEST header != Version: $SIT_TAG"
[ "$(grep -cE '\b(entry_hash|ann_new)\b' "$SIT_DEST")" = "0" ] || echo "WARN: unrenamed entry_hash/ann_new remains in $SIT_DEST"
# code ref only (a non-comment line); sit 1.3.1's api.cyr mentions the token in a doc comment.
[ "$(grep -E 'syscall\(SYS_CHDIR' "$SIT_DEST" | grep -vcE '^[[:space:]]*#')" = "0" ] || echo "WARN: SYS_CHDIR code ref in $SIT_DEST (expected sit >= 1.3.1 chdir-free)"

# --- sankoch zlib profile (verbatim — no renames; the zlib profile has none) ---
if [ -n "${SANKOCH_LOCAL:-}" ]; then
    echo "Syncing sankoch-zlib $SK_TAG from local $SANKOCH_LOCAL/dist/sankoch-zlib.cyr"
    cp "$SANKOCH_LOCAL/dist/sankoch-zlib.cyr" "$SK_DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/sankoch/${SK_TAG}/dist/sankoch-zlib.cyr"
    echo "Syncing sankoch-zlib $SK_TAG from $URL"
    curl -sSf "$URL" -o "$SK_DEST"
fi
grep -q "^# Version: ${SK_TAG}\$" "$SK_DEST" || echo "WARN: $SK_DEST header != Version: $SK_TAG"
[ "$(grep -c '\b_stream_grow\b' "$SK_DEST")" = "0" ] || echo "WARN: _stream_grow in $SK_DEST (zlib profile should have dropped stream.cyr)"

echo "  wrote $SIT_DEST ($(wc -l < "$SIT_DEST") lines) + $SK_DEST ($(wc -l < "$SK_DEST") lines)"
echo "  remember to bump the tags in the include comments + CHANGELOG"
