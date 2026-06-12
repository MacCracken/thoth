#!/usr/bin/env bash
# Multi-target build driver for thoth (M6, 0.6.3).
#
# thoth is OS-agnostic at the substrate layer: it writes against the portable
# Cyrius floor (syscalls / alloc / args / process / terminal I/O) and the target
# is picked at BUILD time, never by a per-OS source file. This script is the one
# entry point that fans the single source tree out to the supported targets.
#
# Target matrix (kept honest — see docs/adr/0008-multi-target-builds.md):
#
#   linux   x86_64 Linux — SHIPPED. The default `cyrius build` target; the
#           binary built, tested, and released today. -> build/thoth
#   agnos   AGNOS (x86_64) — STAGED, BLOCKED UPSTREAM. The build is wired here
#           and lights up automatically once the floor gap closes, but it does
#           NOT link today: thoth's t-ron audit chain persists through libro's
#           patra store, and patra's _pt_seek needs SYS_LSEEK, which the AGNOS
#           syscall floor (syscalls_x86_64_agnos.cyr) does not yet define
#           (absent across Cyrius 6.1.38 -> 6.2.0; present on linux/macos/
#           windows/aarch64). This is upstream in the Cyrius stdlib, not thoth.
#           When present, this produces -> build/thoth_agnos
#
# Future targets (M6 continues): macos, win, aarch64 — the floor variants exist;
# they are not wired here until each is verified.
#
# Usage:
#   ./scripts/build.sh            # build the linux (host) target (default)
#   ./scripts/build.sh linux      # same, explicit
#   ./scripts/build.sh agnos      # attempt the AGNOS target (known-blocked)
#   ./scripts/build.sh all        # linux, then attempt agnos
#
# Honest exit codes: a target that fails to build fails the script. `all` builds
# linux first (the release gate) and then ATTEMPTS agnos, reporting its real
# outcome without masking it — degraded honestly, never faked.

set -euo pipefail

cd "$(dirname "$0")/.."

SRC="src/main.cyr"
OUT_DIR="build"
mkdir -p "$OUT_DIR"

build_linux() {
    echo "==> linux (x86_64): cyrius build $SRC $OUT_DIR/thoth"
    cyrius build "$SRC" "$OUT_DIR/thoth"
    echo "    ok -> $OUT_DIR/thoth"
}

# build_agnos attempts the AGNOS target. It is expected to FAIL today on the
# upstream SYS_LSEEK floor gap (see the header). We surface the real result —
# success when the floor catches up, the honest error now — and never fake a
# binary. Returns the cyrius build status.
build_agnos() {
    echo "==> agnos (x86_64): cyrius build --agnos $SRC $OUT_DIR/thoth_agnos"
    echo "    NOTE: known-blocked upstream (patra SYS_LSEEK gap in the AGNOS floor)."
    if cyrius build --agnos "$SRC" "$OUT_DIR/thoth_agnos"; then
        echo "    ok -> $OUT_DIR/thoth_agnos  (floor gap appears resolved!)"
        return 0
    fi
    echo "    BLOCKED: AGNOS build did not link — see docs/adr/0008-multi-target-builds.md"
    return 1
}

target="${1:-linux}"
case "$target" in
    linux) build_linux ;;
    agnos) build_agnos ;;
    all)
        build_linux
        # Do not let the known AGNOS block fail `all` — linux is the release gate;
        # agnos is attempted and its outcome reported.
        build_agnos || echo "==> agnos target staged, blocked upstream (non-fatal)."
        ;;
    *)
        echo "usage: $0 [linux|agnos|all]" >&2
        exit 2
        ;;
esac
