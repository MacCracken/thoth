#!/usr/bin/env bash
# Multi-target build driver for thoth (M6).
#
# thoth is OS-agnostic at the substrate layer: ONE source tree, the target picked
# at build time. Targets are built the way the AGNOS ecosystem builds them
# (ai-hwaccel, daimon, sakshi): each OS where it builds, NATIVE where the object
# format requires it, and BEST-EFFORT cross lanes for known stdlib portability
# gaps. We never remove a feature and never edit the vendored floor (lib/).
#
# Target matrix — see docs/adr/0008-multi-target-builds.md:
#
#   linux    x86_64 Linux — native `cyrius build`. SHIPPING.        build/thoth
#   macos    Apple Silicon — built NATIVE on a macOS host: cyrius emits Mach-O
#            there, and the macOS floor defines the epoll constant so the whole
#            sandhi stack (server code included) compiles. Cross-emitting Mach-O
#            from Linux is NOT the path (the ecosystem uses a macOS runner).
#                                                                    build/thoth_macos
#   win      Windows x86_64 — cross via cycc_win (`cyrius build --win`).
#            BEST-EFFORT: the Windows floor lacks POSIX primitives the stdlib
#            composes on — `SYS_FUTEX` (patra's mutex; Win uses WaitOnAddress)
#            surfaces first under the 6.2.15 floor, behind it the sandhi/epoll
#            gap. Both are by-design Win32 differences with no raw-syscall
#            equivalent; this lane WARNS on those specific symbols and continues
#            — no feature removed; the .exe ships when the floor gates them.
#                                                                    build/thoth.exe
#   aarch64  aarch64 Linux — cross via --aarch64. BUILDS as of cyrius 6.2.15
#            (the cycc #pure/pass-1 scanner gap closed in v6.2.2); still run as a
#            best-effort lane so a future floor regression stays visible.
#                                                                    build/thoth_aarch64
#   agnos    AGNOS (early-demo OS) — staged (0.6.3); its floor still lacks lseek
#            (filed: agnos 2026-06-16-cyrius-patra-lseek-syscall-gap) — and, behind
#            it, futex. BEST-EFFORT.                                build/thoth_agnos
#
# Usage:
#   ./scripts/build.sh                 # host-appropriate default (macos on a Mac, else linux)
#   ./scripts/build.sh linux|macos|win|aarch64|agnos
#   ./scripts/build.sh all             # every lane; gates fail, best-effort lanes warn
#
# Exit codes: a SHIPPING lane (linux; macos on a Mac) that fails, fails the
# script. A BEST-EFFORT lane that fails ONLY on its known stdlib gap warns and
# returns 0; ANY OTHER failure on it still fails — regressions stay visible.

set -uo pipefail

cd "$(dirname "$0")/.."

SRC="src/main.cyr"
OUT="build"
mkdir -p "$OUT"

# The known, sanctioned stdlib portability gaps a best-effort lane may ride
# (and ONLY these). A lane that fails on one of these warns + continues; any
# other error fails the lane. Keep this list tight so real breakage surfaces.
KNOWN_GAP='SYS_EPOLL_CREATE1|SYS_EPOLL_WAIT|SYS_EPOLL_CTL|SYS_LSEEK|SYS_FUTEX'

is_macos_host() { [ "$(uname -s 2>/dev/null)" = "Darwin" ]; }

# _run <label> <outfile> <cyrius build args...> — build a SHIPPING lane. Streams
# cyrius output; fails the script on any error.
_run() {
    local label="$1" out="$2"; shift 2
    echo "==> $label: cyrius build $* -> $out"
    if cyrius build "$@" "$SRC" "$out"; then
        echo "    ok -> $out"
        return 0
    fi
    echo "    FAILED: $label" >&2
    return 1
}

# _run_best_effort <label> <outfile> [ENV=v ...] -- <cyrius build args...> — a
# best-effort lane. Captures output; if it failed ONLY on a KNOWN_GAP symbol,
# warns and returns 0; any other failure returns 1.
_run_best_effort() {
    local label="$1" out="$2"; shift 2
    local -a env=()
    while [ "${1:-}" != "--" ]; do env+=("$1"); shift; done
    shift  # drop --
    echo "==> $label (best-effort): ${env[*]:-} cyrius build $* -> $out"
    local log; log="$(env "${env[@]}" cyrius build "$@" "$SRC" "$out" 2>&1)"
    local rc=$?
    if [ $rc -eq 0 ] && [ -f "$out" ]; then
        echo "    ok -> $out  (gap appears closed!)"
        return 0
    fi
    if echo "$log" | grep -qE "undefined variable '($KNOWN_GAP)'"; then
        local sym; sym="$(echo "$log" | grep -oE "($KNOWN_GAP)" | head -1)"
        echo "    BEST-EFFORT SKIP: known stdlib gap ($sym not on this floor) — no binary this run."
        echo "    Nothing removed; lane lights up when the floor/stdlib gates it. See ADR-0008."
        return 0
    fi
    echo "    FAILED (not a known gap):" >&2
    echo "$log" | grep -E "^error" | head -5 >&2
    return 1
}

build_linux()   { _run "linux (x86_64)" "$OUT/thoth" ; }
build_aarch64() { _run_best_effort "aarch64 (linux)" "$OUT/thoth_aarch64" -- --aarch64 ; }
build_win()     { _run_best_effort "windows (x86_64 PE)" "$OUT/thoth.exe" -- --win ; }
build_agnos()   { _run_best_effort "agnos (x86_64)" "$OUT/thoth_agnos" -- --agnos ; }

# macOS is a SHIPPING lane on a Mac (native Mach-O) and a no-op elsewhere — we do
# not pretend to cross-emit Mach-O from Linux.
build_macos() {
    if is_macos_host; then
        _run "macos (native Mach-O)" "$OUT/thoth_macos"
    else
        echo "==> macos: SKIPPED on $(uname -s) — built natively on a macOS runner."
        echo "    (cyrius emits Mach-O on the Mac; cross-emit from Linux is not the path. ADR-0008)"
        return 0
    fi
}

target="${1:-$(is_macos_host && echo macos || echo linux)}"
case "$target" in
    linux)   build_linux ;;
    macos)   build_macos ;;
    win)     build_win ;;
    aarch64) build_aarch64 ;;
    agnos)   build_agnos ;;
    all)
        rc=0
        # Shipping lane for this host first (it gates the run).
        if is_macos_host; then build_macos || rc=1; else build_linux || rc=1; fi
        # Best-effort + cross lanes: failures here never gate, except a non-gap regression.
        build_win     || rc=1
        build_aarch64 || rc=1
        build_agnos   || rc=1
        is_macos_host || build_macos   # announce the macOS lane on non-Mac hosts
        exit $rc
        ;;
    *)
        echo "usage: $0 [linux|macos|win|aarch64|agnos|all]" >&2
        exit 2
        ;;
esac
