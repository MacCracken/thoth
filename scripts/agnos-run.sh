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
# ⚠ WHAT IT DOES NOT PROVE. v1.0 gate 2's criterion is "the spine native and a
# consumer green end to end". A `--version` print-and-exit exercises NEITHER: no
# hoosh, no daimon, no turn. This is rung 1 of that gate — necessary, not
# sufficient. Do not report a PASS here as gate 2 cleared. See docs/development/roadmap.md.
#
# Usage:
#   ./scripts/agnos-run.sh              # build the agnos lane, then run it
#   ./scripts/agnos-run.sh --no-build   # run whatever is already at build/thoth_agnos
#
# Env:
#   AGNOS_REPO   path to the agnos checkout   (default: ../agnos relative to this repo)
#   QEMU_TIMEOUT seconds to dwell for the prompt, passed through (harness default: 120)
#   ARK_NO_KVM   set to force TCG instead of KVM (slow on a multi-MB load)
#
# Exit: 0 PASS · 1 the run FAILED · 2 a prerequisite is missing (nothing was run).
# A missing prerequisite is deliberately NOT a pass — this lane degrades closed and
# announces, like every other capability thoth cannot reach.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

AGNOS_REPO="${AGNOS_REPO:-$ROOT/../agnos}"
HARNESS="$AGNOS_REPO/scripts/smoke/basestack-run-smoke.sh"
KERNEL="$AGNOS_REPO/build/agnos"
ELF="$ROOT/build/thoth_agnos"

DO_BUILD=1
case "${1:-}" in
    --no-build) DO_BUILD=0 ;;
    "")         ;;
    *) echo "usage: $0 [--no-build]" >&2; exit 2 ;;
esac

# The expected console string is thoth's OWN version, read from the single source of
# truth. A literal here would silently keep passing against a stale binary after a
# version bump — the harness only greps for the string it is handed.
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null)"
[ -n "$VERSION" ] || { echo "ERROR: cannot read $ROOT/VERSION" >&2; exit 2; }
EXPECT="thoth $VERSION"

miss() { echo "  ⚠ $1" >&2; }

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
    miss "rebuild it:  BASESTACK_SELFTEST=1 sh scripts/build.sh   (in $AGNOS_REPO)"
    miss "without the hook the box boots to agnsh and never execs /bin/probe, so the"
    miss "harness would report a FAIL about the kernel's flags, not about thoth."
    exit 2
fi

echo "==> handing build/thoth_agnos to the AGNOS runner (expecting: '$EXPECT')"
sh "$HARNESS" "$ELF" "$EXPECT" thoth
rc=$?

echo ""
if [ "$rc" -eq 0 ]; then
    echo "agnos-run: PASS — thoth $VERSION loads and runs in ring 3 on AGNOS."
    echo "  This is v1.0 gate 2 RUNG 1 only. Gate 2 wants the spine native and a"
    echo "  consumer green end to end; a --version print exercises neither."
else
    echo "agnos-run: FAIL — see the serial log named above."
fi
exit "$rc"
