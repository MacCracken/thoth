#!/usr/bin/env bash
# agnos-run — does thoth, cross-built --agnos, actually LOAD + RUN in ring 3 on AGNOS?
#
# `scripts/build.sh agnos` proves the SOURCE is agnos-shaped: it emits a valid
# statically-linked x86_64-AGNOS ELF with no unresolved symbol. That is v1.0
# gate 1's build half, and it says nothing about whether the thing runs — the
# ELF targets the AGNOS syscall ABI, so a Linux host cannot exercise it.
#
# This script closes that loop. It does NOT contain a runner: AGNOS already owns
# one, it is parameterised, and it NAMES thoth —
#
#     agnos/scripts/smoke/basestack-run-smoke.sh   "Reusable across aegis/bote/phylax/hoosh/thoth"
#
# driven by the kernel's BASESTACK_SELFTEST hook, which execs `/bin/probe --version`
# deterministically (no agnsh keystrokes — sendkey drops chars on multi-MB targets).
# We SHELL OUT to it. Copying it here would be forking the spine for a domain AGNOS
# owns — the same rule that makes thoth consume hoosh/daimon/bote/t-ron/avatara
# rather than reimplement them. Invoking it is the consume pattern; vendoring it
# would be the violation.
#
# What a PASS actually proves (gnoboot + OVMF booting the real kernel under QEMU):
# the multi-MB ELF streams off ext2 via exec-from-disk, elf_load maps it, ring-3
# code reaches write(1), and the process exits cleanly without faulting the box.
#
# ⚠ WHAT IT DOES NOT PROVE. v1.0 gate 1's criterion is "the spine native and a
# consumer green end to end". A `--version` print-and-exit exercises NEITHER: no
# hoosh, no daimon, no turn. This is rung 1 of that gate — necessary, not
# sufficient. Do not report a PASS here as gate 1 cleared. See docs/development/roadmap.md.
#
# RUNG 2 (--turn, 0.55.0). The same consume pattern, one rung up: agnos/scripts/smoke/spine-turn-smoke.sh stages thoth,
# hoosh and daimon on one image, starts the services, and drives real one-shot turns against a model on the host, a tool
# round through t-ron and daimon among them. Its launcher sits in the /bin/agnsh slot on a PLAIN kernel, so this needs no
# hook. The three binaries are built here, in copies under build/agnos-spine: nothing writes into a sibling. HOOSH_BIN or
# DAIMON_BIN names a binary to use as it stands.
#
# Usage:
#   ./scripts/agnos-run.sh              # build the agnos lane, then run it
#   ./scripts/agnos-run.sh --no-build   # run whatever is already at build/thoth_agnos
#   ./scripts/agnos-run.sh --private    # build the selftest kernel in a throwaway copy of the agnos tree; agnos's own
#                                       # build/ is never touched. Combines with --no-build.
#   ./scripts/agnos-run.sh --classify LOG   # say whether a serial log's boot reached the kernel (no run)
#   ./scripts/agnos-run.sh --turn       # rung 2: a real turn through hoosh and daimon on one image. Always a plain kernel in a
#                                       # private copy. Combines with --no-build, which reuses build/thoth_agnos.
#
# Env:
#   AGNOS_REPO   path to the agnos checkout   (default: ../agnos relative to this repo)
#   QEMU_TIMEOUT seconds to dwell for the prompt, passed through (harness default: 120)
#   ARK_NO_KVM   set to force TCG instead of KVM (slow on a multi-MB load)
#   AGNOS_RUN_BOOTS  boots to try when one dies BEFORE the kernel (default 3; see below)
#
# ⚠ A BOOT THAT NEVER REACHED THE KERNEL IS NOT A THOTH RESULT (0.52.2). gnoboot calls ExitBootServices once and
# gives up when the firmware refuses a stale memory-map key (`gnoboot: fail @ EBS` in the serial log — the roadmap's
# gnoboot row), which at 0.52.1 took two of three boots. The harness then printed "FAIL: 'thoth 0.52.1' not found —
# thoth did not produce its expected ring-3 output", about a binary that was never loaded. A serial log with
# gnoboot's failure line, or with no kernel log line at all, is classified pre-kernel: the boot is retried (said so),
# and when every boot dies there the run is a SKIP — nothing was executed — never a FAIL.
#
# Exit: 0 PASS · 1 the run FAILED · 2 a prerequisite is missing, or no boot reached the kernel (nothing was run).
# A missing prerequisite is deliberately NOT a pass — this lane degrades closed and
# announces, like every other capability thoth cannot reach.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

AGNOS_REPO="${AGNOS_REPO:-$ROOT/../agnos}"
HARNESS="$AGNOS_REPO/scripts/smoke/basestack-run-smoke.sh"
KERNEL="$AGNOS_REPO/build/agnos"
ELF="$ROOT/build/thoth_agnos"

# boot_reached_kernel LOG: 0 when the serial log shows the AGNOS kernel running (a `[ seconds.micros ]` log line) and
# no bootloader failure; 1 otherwise, with the reason on stdout. `strings`, because the log carries firmware escapes.
boot_reached_kernel() {
    local fail
    fail="$(strings "$1" 2>/dev/null | grep -m1 -E 'gnoboot: fail @')"
    if [ -n "$fail" ]; then echo "the bootloader failed ($fail)"; return 1; fi
    if ! strings "$1" 2>/dev/null | grep -q -E '\[ *[0-9]+\.[0-9]{6}\]'; then
        echo "no kernel log line in the serial log"; return 1
    fi
    return 0
}

DO_BUILD=1
PRIVATE=0
TURN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) DO_BUILD=0 ;;
        --private)  PRIVATE=1 ;;
        --turn)     TURN=1; PRIVATE=1 ;;
        --classify)
            [ -f "${2:-}" ] || { echo "usage: $0 --classify SERIAL_LOG" >&2; exit 2; }
            if why="$(boot_reached_kernel "$2")"; then echo "kernel-ran"; else echo "pre-kernel: $why"; fi
            exit 0 ;;
        *) echo "usage: $0 [--no-build] [--private] [--turn] | --classify LOG" >&2; exit 2 ;;
    esac
    shift
done

# The expected console string is thoth's OWN version, read from the single source of
# truth. A literal here would silently keep passing against a stale binary after a
# version bump — the harness only greps for the string it is handed.
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null)"
[ -n "$VERSION" ] || { echo "ERROR: cannot read $ROOT/VERSION" >&2; exit 2; }
EXPECT="thoth $VERSION"

miss() { echo "  ⚠ $1" >&2; }

[ "$TURN" -eq 1 ] && HARNESS="$AGNOS_REPO/scripts/smoke/spine-turn-smoke.sh"
if [ ! -f "$HARNESS" ]; then
    echo "SKIP: no AGNOS runner — nothing was executed." >&2
    miss "expected the harness at $HARNESS"
    miss "set AGNOS_REPO=/path/to/agnos, or clone it beside this repo."
    exit 2
fi

if [ "$DO_BUILD" -eq 1 ]; then
    echo "==> building the agnos lane"
    ./scripts/build.sh agnos || { echo "ERROR: the agnos lane did not build — nothing to run." >&2; exit 2; }
fi

if [ ! -f "$ELF" ]; then
    echo "SKIP: no $ELF — nothing was executed." >&2
    miss "run ./scripts/build.sh agnos first (or drop --no-build)."
    exit 2
fi

# --private: the hook is a build flag, so a run used to mean replacing the operator's build/agnos and putting it back
# after. A copy of the tree takes the selftest build instead, under thoth's gitignored build/, and goes with the run.
# A failed run keeps the copy: the serial log the harness names is inside it.
if [ "$PRIVATE" -eq 1 ]; then
    command -v rsync >/dev/null 2>&1 || { echo "SKIP: --private needs rsync — nothing was executed." >&2; exit 2; }
    SIBLINGS_ROOT="${SIBLINGS_ROOT:-$(cd "$AGNOS_REPO/.." && pwd)}"
    GNOBOOT_ROOT="${GNOBOOT_ROOT:-$SIBLINGS_ROOT/gnoboot}"
    export SIBLINGS_ROOT GNOBOOT_ROOT
    PRIV="$ROOT/build/agnos-private.$$"
    KEEP_PRIV=0
    trap '[ "$KEEP_PRIV" -eq 1 ] || rm -rf "$PRIV"' EXIT
    echo "==> building a selftest kernel in a private copy of $AGNOS_REPO"
    mkdir -p "$PRIV/build"
    rsync -a --exclude build --exclude .git "$AGNOS_REPO/" "$PRIV/" || { echo "SKIP: could not copy $AGNOS_REPO — nothing was executed." >&2; exit 2; }
    KBUILD="BASESTACK_SELFTEST=1"
    [ "$TURN" -eq 1 ] && KBUILD="BASESTACK_SELFTEST="      # rung 2 runs on the kernel as it ships
    if ! ( cd "$PRIV" && env "$KBUILD" sh scripts/build.sh ) > "$PRIV/build/selftest-build.log" 2>&1; then
        tail -5 "$PRIV/build/selftest-build.log" >&2
        echo "SKIP: the kernel did not build — nothing was executed." >&2
        exit 2
    fi
    AGNOS_REPO="$PRIV"
    HARNESS="$AGNOS_REPO/scripts/smoke/basestack-run-smoke.sh"
    KERNEL="$AGNOS_REPO/build/agnos"
fi

# spine_bin NAME: build a sibling --agnos in a copy under build/agnos-spine, and print the binary's path. A sibling is only read.
spine_bin() {
    local src="${SIBLINGS_ROOT:-$(cd "$ROOT/.." && pwd)}/$1" dst="$ROOT/build/agnos-spine/$1"
    [ -d "$src" ] || { echo "SKIP: no $src — nothing was executed." >&2; return 1; }
    rm -rf "$dst"; mkdir -p "$dst"
    rsync -a --exclude build --exclude .git "$src/" "$dst/" || return 1
    mkdir -p "$dst/build"
    if ! ( cd "$dst" && cyrius build --agnos src/main.cyr build/agnos ) > "$dst/build.log" 2>&1; then
        tail -5 "$dst/build.log" >&2
        echo "SKIP: $1 did not build --agnos — nothing was executed." >&2
        return 1
    fi
    echo "$dst/build/agnos"
}

# Rung 2: the runner's own gates are the verdict, and its helper retries a boot that never reached the kernel.
if [ "$TURN" -eq 1 ]; then
    [ -n "${HOOSH_BIN:-}" ]  || { HOOSH_BIN="$(spine_bin hoosh)"   || exit 2; }
    [ -n "${DAIMON_BIN:-}" ] || { DAIMON_BIN="$(spine_bin daimon)" || exit 2; }
    echo "==> handing thoth, hoosh and daimon to the AGNOS runner"
    HOOSH_BIN="$HOOSH_BIN" DAIMON_BIN="$DAIMON_BIN" THOTH_BIN="$ELF" STUB_PROVIDER="$ROOT/scripts/live/stubhoosh.py" \
        SPINE_KERNEL="$KERNEL" bash "$AGNOS_REPO/scripts/smoke/spine-turn-smoke.sh"
    rc=$?
    echo ""
    case "$rc" in
        0) echo "agnos-run: PASS — a real turn ran on AGNOS, through hoosh and daimon (v1.0 gate 1 RUNG 2)." ;;
        2) echo "SKIP: no boot reached the kernel — nothing was executed." >&2 ;;
        *) echo "agnos-run: FAIL — see the logs the runner named."; KEEP_PRIV=1 ;;
    esac
    exit "$rc"
fi

# The kernel must carry the BASESTACK_SELFTEST hook; without it the box boots to
# agnsh and never execs /bin/probe, so the harness would report a FAIL that is
# about the KERNEL's build flags and not about thoth. Detect it and say which.
if [ ! -f "$KERNEL" ]; then
    echo "SKIP: the AGNOS kernel is not built — nothing was executed." >&2
    miss "build it in $AGNOS_REPO:  BASESTACK_SELFTEST=1 sh scripts/build.sh"
    miss "if that stops on a cyrius pin mismatch, agnos's own gate is telling you the"
    miss "toolchain differs from its manifest pin — read the message rather than"
    miss "forcing it; AGNOS_ALLOW_PIN_DRIFT=1 is agnos's call to make, not thoth's."
    exit 2
fi
if ! strings "$KERNEL" 2>/dev/null | grep -q 'basestack selftest'; then
    echo "SKIP: $KERNEL was built WITHOUT the selftest hook — nothing was executed." >&2
    miss "rebuild it:  BASESTACK_SELFTEST=1 sh scripts/build.sh   (in $AGNOS_REPO), or pass --private"
    miss "without the hook the box boots to agnsh and never execs /bin/probe, so the"
    miss "harness would report a FAIL about the kernel's flags, not about thoth."
    exit 2
fi

SERIAL="$AGNOS_REPO/build/basestack-run-smoke-logs/basestack-thoth.log"
BOOTS="${AGNOS_RUN_BOOTS:-3}"
boot=1
while :; do
    echo "==> handing build/thoth_agnos to the AGNOS runner (expecting: '$EXPECT'; boot $boot of $BOOTS)"
    sh "$HARNESS" "$ELF" "$EXPECT" thoth
    rc=$?
    [ "$rc" -eq 0 ] && break
    if why="$(boot_reached_kernel "$SERIAL")"; then break; fi   # the kernel ran: the harness's verdict stands
    echo ""
    echo "agnos-run: boot $boot of $BOOTS died BEFORE the kernel ran — $why."
    echo "  Nothing of thoth's was loaded; the harness's FAIL above is not about thoth (the roadmap's gnoboot row)."
    if [ "$boot" -ge "$BOOTS" ]; then
        echo "SKIP: no boot reached the kernel in $BOOTS tries — nothing was executed." >&2
        exit 2
    fi
    boot=$(( boot + 1 ))
done

echo ""
if [ "$rc" -eq 0 ]; then
    echo "agnos-run: PASS — thoth $VERSION loads and runs in ring 3 on AGNOS."
    echo "  This is v1.0 gate 1 RUNG 1 only. Gate 1 wants the spine native and a"
    echo "  consumer green end to end; a --version print exercises neither."
else
    echo "agnos-run: FAIL — see the serial log named above."
    [ "$PRIVATE" -eq 1 ] && KEEP_PRIV=1
fi
exit "$rc"
