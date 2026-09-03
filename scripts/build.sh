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
#            BEST-EFFORT. The old `SYS_GETRANDOM` transient gap cleared at the
#            6.3.38 refresh (patra ≥1.12.4 bundled), so the lane now stops on the
#            genuine ARCHITECTURAL gaps: `SYS_EPOLL_CREATE1` (and the rest of the
#            sandhi/epoll set → IOCP) and `SYS_FUTEX` (Win uses WaitOnAddress) —
#            by-design Win32 differences with no raw-syscall equivalent. This lane
#            WARNS on those symbols and continues; the .exe ships when the floor
#            gates the architectural set (an IOCP/WaitOnAddress backend).
#                                                                    build/thoth.exe
#   aarch64  aarch64 Linux — cross via --aarch64. BUILDS as of cyrius 6.2.15
#            (the cycc #pure/pass-1 scanner gap closed in v6.2.2); still run as a
#            best-effort lane so a future floor regression stays visible.
#                                                                    build/thoth_aarch64
#   agnos    AGNOS (early-demo OS) — staged (0.6.3), now BUILDING (0.12.3). Every
#            prior blocker cleared upstream: `SYS_LSEEK` (6.2.37 peer, =58) and now
#            the `SIGHUP` signal-NUMBER constant gap — the 6.3.38 agnos peer defines
#            the signal enum, so the lane compiles a valid x86_64-AGNOS ELF with zero
#            undefined symbols. This clears the BUILD half of v1.0 gate 1 (roadmap.md);
#            the RUNTIME half (a downstream consumer green on real AGNOS) is gate 2,
#            external — the ELF targets the AGNOS syscall ABI and cannot be exercised
#            on a Linux host. Kept BEST-EFFORT until an AGNOS runner verifies it.
#                                                                    build/thoth_agnos
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

# Resolve the repo root ONCE, before any cd. `$0`-relative lookups AFTER this cd are wrong for some
# invocation paths (run as `./build.sh` from inside scripts/, `$(dirname "$0")` becomes the repo root
# and `$ROOT/gen-version.sh` does not exist) — the sync-*.sh family already uses this form.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SRC="src/main.cyr"
OUT="build"
mkdir -p "$OUT"

# Symbols a best-effort lane may ride (warn + continue); any OTHER error fails the
# lane. Keep these tight so real breakage surfaces. TWO distinct classes — do not
# conflate them:
#
# ARCH_GAP — ARCHITECTURAL: a primitive the target genuinely lacks with NO
# raw-syscall equivalent. Win32 has no futex (uses WaitOnAddress) and no epoll
# (uses IOCP). These are PERMANENT by design; the lane gates closed, announced.
# 0.43.2: this pattern matched only the syscall NUMBER constants, but the toolchain now surfaces the
# epoll FLAG constants (EPOLL_CTL_ADD / EPOLLIN) and the ws2_32-routed socket calls first — so the win
# lane's genuinely architectural failure was being reported as "FAILED (not a known gap)". Same gap,
# different symbol names; the classifier, not the lane, was stale.
ARCH_GAP='SYS_EPOLL_CREATE1|SYS_EPOLL_WAIT|SYS_EPOLL_CTL|SYS_FUTEX|EPOLL_CTL_ADD|EPOLLIN|SYS_SOCKET|SYS_CONNECT'
#
# ⚠ TTY_SIGMASK_WINCH is deliberately NOT listed, and stays unlisted now that it is FIXED. It was
# thoth's OWN bug, not a floor gap: src/tui.cyr called darshana's termios/signalfd half with no
# non-Linux guard while darshana gates that half to `#ifdef CYRIUS_TARGET_LINUX`, which is why the
# macOS lane had not compiled since 0.6.4 and why this lane reported it beside its real gaps. Closed at
# 0.44.3 by src/term.cyr — every thoth caller goes through `term_*`, which exists on every target.
# Keeping the symbol off every list here makes this lane the REGRESSION TRIPWIRE: a new raw `tty_*`
# call in thoth source turns the win lane red again, which is exactly what should happen.
#
# TRANSIENT_GAP — a FIXABLE upstream bug already fixed-or-filed; present ONLY
# because thoth's vendored snapshot (lib/, synced from the cyrius toolchain) lags
# the fix. NOT a capability limit — the target CAN do these. Add a symbol here
# (pipe-separated) only while the vendored floor lags a known upstream fix, and
# DELETE it the moment `cyrius lib sync` re-bundles the fix — a stale entry would
# silently swallow a real regression of that symbol.
#
# The list is CURRENTLY EMPTY: both prior entries cleared when thoth refreshed the
# pin to Cyrius 6.3.38 (0.12.3). Kept as RESOLVED history so the pattern is reused:
#   SYS_GETRANDOM — the patra _wal_gen_salts raw-syscall bug (the Win peer omits
#     the constant by design; Windows CSPRNG is ProcessPrng via sys_getrandom()).
#     Fixed patra v1.12.4; now bundled — the win lane surfaces the genuine
#     ARCHITECTURAL SYS_EPOLL_CREATE1 (IOCP) gap instead, where it should stop.
#   SIGHUP — the agnos peer omitted the signal-NUMBER constants (the signal infra
#     itself was DONE: sigprocmask#17/signalfd#18). Now defined — the agnos lane
#     BUILDS a valid ELF (v1.0 gate 1's build blocker cleared; runtime is gate 2).
#   (The 6.2.15-era SYS_LSEEK entry cleared earlier the same way.)
TRANSIENT_GAP=''

# VENDOR_GAP — a symbol reached ONLY from a vendored upstream bundle (src/vendor/**), which the target
# floor does not define and which thoth has NO call site for. Distinct from ARCH_GAP (a primitive the
# target genuinely lacks, reached from thoth's own code or the stdlib) and from TRANSIENT_GAP (a fix
# that exists upstream and has not been re-vendored yet). It is listed so a best-effort lane reports
# what it is actually blocked on instead of one class masking another — NOT to excuse a thoth defect.
#
# ⚠ The test for adding a symbol here is EVIDENCE, not convenience: `grep -rn <sym> src/ | grep -v
# vendor` must be empty, and the call site must live in src/vendor/. If thoth's own source reaches it,
# it belongs in ARCH_GAP or, more likely, it is a bug to fix — which is exactly what
# `TTY_SIGMASK_WINCH` was through 0.44.2, and why it is deliberately absent from every list here.
#
#   SIGHUP, SIG_BLOCK — src/vendor/t-ron.cyr's signal.cyr (SIGHUP-driven policy hot-reload). Windows
#     has no POSIX signals, so the floor defines neither constant. thoth has ZERO callers of
#     `sighup_init` — the code is dead in this consumer. Upstream fix: t-ron gating its signal half to
#     Linux, or publishing a [lib.X] profile without it. Tracked in roadmap.md's known limitations.
#   sys_rmdir — src/vendor/sit-read.cyr's sf_rmdir. lib/syscalls_windows.cyr defines no `sys_rmdir`
#     (it routes DeleteFileW and MoveFileExW but not RemoveDirectoryW). A cyrius Windows-floor gap
#     reached through a vendored bundle, not a thoth call. Upstream fix: cyrius.
VENDOR_GAP='SIGHUP|SIG_BLOCK|sys_rmdir'

# Guard the empty case: "$ARCH_GAP|" (trailing pipe) would match the empty string
# in grep -qE and swallow EVERY failure as a "known gap". Only union when non-empty.
KNOWN_GAP="$ARCH_GAP|$VENDOR_GAP"
if [ -n "$TRANSIENT_GAP" ]; then KNOWN_GAP="$KNOWN_GAP|$TRANSIENT_GAP"; fi

is_macos_host() { [ "$(uname -s 2>/dev/null)" = "Darwin" ]; }

# _run <label> <outfile> <cyrius build args...> — build a SHIPPING lane. Streams
# cyrius output; fails the script on any error.
_run() {
    local label="$1" out="$2"; shift 2
    echo "==> $label: cyrius build $* -> $out"
    rm -f "$out"        # an absent binary must always mean "this lane produced nothing"
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
    # rm first: without it a gapped lane prints "no binary this run" while a MONTHS-OLD binary still
    # sits at exactly the path just named — and release.yml publishes `build/*`, so a stale 0.20.1
    # thoth_agnos would ship as a release asset. `${env[@]+...}` guards the empty-array expansion under
    # `set -u`, which is an error on bash < 4.4 — including the 3.2 on the macOS build host.
    rm -f "$out"
    local log; log="$(env ${env[@]+"${env[@]}"} cyrius build "$@" "$SRC" "$out" 2>&1)"
    local rc=$?
    if [ $rc -eq 0 ] && [ -f "$out" ]; then
        echo "    ok -> $out  (gap appears closed!)"
        return 0
    fi
    # ⚠ 0.43.2: this implements the "failed ONLY on a KNOWN_GAP symbol" the header promises. It used to
    # be a single `grep -q` for ANY known symbol, so one architectural gap in the log classified the whole
    # lane as expected — masking every OTHER undefined symbol in the same build, including thoth's own
    # bugs. The win lane was the live case: it reports the architectural epoll/ws2_32 gaps AND
    # TTY_SIGMASK_WINCH, which is thoth's un-guarded call into darshana's Linux-only TTY half (the same
    # root cause that breaks the macOS lane). Under the old test that defect was invisible.
    # 0.44.3: collect undefined FUNCTIONS as well as undefined variables. The classifier only ever read
    # `undefined variable`, so a lane blocked on a reachable undefined FUNCTION — the error cyrius
    # actually refuses to emit on ("refusing to emit binary with N reachable undefined function(s)") —
    # was invisible to it. Through 0.44.2 the win lane hid ELEVEN of them behind two undefined variables.
    #
    # ⚠ READ THE SUFFIX THE RIGHT WAY ROUND. cyrius prints EVERY undefined function bare during the
    # compile pass, then re-prints the REACHABLE ones after the "N unreachable fns" note, hedged
    # "(call site may be unreachable)". So the hedged list is the one that blocks the binary — its
    # length is exactly the N in the refusal — and the bare list is mostly dead references. Matching
    # the bare form instead reports the dead ones as blockers: it named `load_signing_seed` and the two
    # other documented sit dead-path placeholders, which have never blocked any lane.
    local undef_v; undef_v="$(echo "$log" | grep -oE "undefined variable '[A-Za-z_][A-Za-z0-9_]*'" | sed -E "s/.*'(.*)'/\1/" | sort -u)"
    local undef_f; undef_f="$(echo "$log" | grep -E "undefined function '[A-Za-z_][A-Za-z0-9_]*' \(call site may be unreachable\)" | grep -oE "'[A-Za-z_][A-Za-z0-9_]*'" | tr -d "'" | sort -u)"
    local undef; undef="$(printf '%s\n%s\n' "$undef_v" "$undef_f" | grep -v '^$' | sort -u)"
    if [ -n "$undef" ]; then
        local unexpected; unexpected="$(echo "$undef" | grep -vE "^($KNOWN_GAP)$" || true)"
        if [ -z "$unexpected" ]; then
            echo "    BEST-EFFORT SKIP: known stdlib gap ($(echo "$undef" | paste -sd, -) not on this floor) — no binary this run."
            echo "    Nothing removed; lane lights up when the floor/stdlib gates it. See ADR-0008."
            return 0
        fi
        echo "    FAILED (not a known gap): $label" >&2
        echo "      architectural gaps present: $(echo "$undef" | grep -E "^($KNOWN_GAP)$" | paste -sd, - || echo none)" >&2
        echo "      UNEXPECTED undefined symbols: $(echo "$unexpected" | paste -sd, -)" >&2
        echo "$log" | tail -20 >&2
        return 1
    fi
    # SIZE_GAP — a target with a fixed cyrius output-size cap (the aarch64 lane caps at
    # 16 MiB) that thoth+the vendored sit read bundle tips over (0.13.0). NOT a capability
    # limit and NOT a regression in thoth's own code — the binary is dominated by static
    # data (sigil + sankoch tables). Best-effort only; the shipping _run lane has no cap
    # and still hard-fails on anything. Lane lights up on a static-data reduction (a
    # decompress-only sankoch, or sigil trimming) or a cyrius cap raise.
    if echo "$log" | grep -qE "output too large"; then
        local sz; sz="$(echo "$log" | grep -oE "output too large \([0-9]+/[0-9]+ bytes\)" | head -1)"
        echo "    BEST-EFFORT SKIP: over the target output-size cap ($sz) — no binary this run."
        echo "    thoth+sit exceeds this target's fixed output cap; unblocks on static-data reduction"
        echo "    (decompress-only sankoch / sigil trim) or a cyrius cap raise. See ADR-0008."
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

# Regenerate src/version.cyr from VERSION (single source of truth) before any build,
# so thoth_version() can never drift from the VERSION file. See scripts/gen-version.sh.
"$ROOT/scripts/gen-version.sh" || { echo "FAILED: gen-version.sh — refusing to build a stale src/version.cyr" >&2; exit 1; }

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
