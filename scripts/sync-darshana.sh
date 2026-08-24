#!/usr/bin/env bash
# Re-sync the vendored darshana TTY bundle.
#
# darshana is consumed as a single committed file, src/vendor/darshana.cyr, the
# same vendored-dist pattern as avatara / bote-core / t-ron / libro (see
# scripts/sync-avatara.sh). It supplies the T2 rich-TUI's terminal substrate —
# raw/cooked termios, alt-screen, winsize/SIGWINCH via signalfd, cursor moves
# and SGR colour. thoth READS that surface and authors only the paint glue in
# src/tui.cyr / src/ui.cyr; it never reimplements the termios or ANSI geometry.
#
# Until 0.38.6 this file was hand-vendored with NO script — the gap
# docs/development/state.md recorded. This script closes it.
#
# NOTE: the bundle is self-contained over the stdlib (`syscalls` for the raw
# `syscall()` numbers, nothing else new), so adopting it adds no [deps].stdlib
# entry. thoth installs its OWN cooked-termios save buffer in src/intr.cyr
# rather than going through tty_raw/tty_cooked — deliberate, so the Ctrl-C
# handler owns its state independently of whatever the TUI has done.
#
# ⚠ COLLISION NOTE (darshana >= 1.0.0): the bundle NO LONGER defines
# `var SYS_IOCTL = 16;`. Through 0.9.0 it did, which is a hazard rather than a
# convenience — thoth's own src/intr.cyr and src/ui.cyr call
# `syscall(SYS_IOCTL, ...)` and the correct number is arch-dependent (16 on
# x86_64, **29 on aarch64**, per lib/syscalls_*_linux.cyr). With darshana's
# copy gone the stdlib's per-arch definition is the only one, which is the
# right answer on every target. Do NOT reintroduce a local SYS_IOCTL.
#
# Usage: ./scripts/sync-darshana.sh [tag]   (default: 1.0.0)
set -euo pipefail

TAG="${1:-1.0.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/src/vendor/darshana.cyr"

# For pre-release / offline dev, point at a local checkout's working-tree dist:
#   DARSHANA_LOCAL=/path/to/darshana ./scripts/sync-darshana.sh
if [ -n "${DARSHANA_LOCAL:-}" ]; then
    echo "Syncing darshana $TAG from local $DARSHANA_LOCAL/dist/darshana.cyr"
    mkdir -p "$REPO_ROOT/src/vendor"
    cp "$DARSHANA_LOCAL/dist/darshana.cyr" "$DEST"
else
    URL="https://raw.githubusercontent.com/MacCracken/darshana/${TAG}/dist/darshana.cyr"
    echo "Syncing darshana $TAG from $URL"
    mkdir -p "$REPO_ROOT/src/vendor"
    curl -sSf "$URL" -o "$DEST"
fi

grep -q "^# Version: ${TAG}\$" "$DEST" || {
    echo "WARN: $DEST header does not report Version: $TAG"; }
[ "$(grep -cE '^var SYS_IOCTL\b' "$DEST")" = "0" ] || \
    echo "WARN: $DEST defines SYS_IOCTL — collides with the stdlib's per-arch value (see header)"

echo "  wrote $DEST ($(wc -l < "$DEST") lines)"
echo "  remember to bump the tag in the include comments and CHANGELOG"
