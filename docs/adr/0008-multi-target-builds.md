# 0008 — Multi-target builds: one source tree, target picked at build time (Linux first)

**Status**: Accepted
**Date**: 2026-06-12

## Context

[ADR-0001](0001-os-agnostic-agnos-primary.md) fixed the posture: thoth is
OS-agnostic at the substrate layer and AGNOS-sovereign at the capability layer —
*port the floor; never fork the spine*. The driver writes against the portable
Cyrius floor (syscalls / alloc / args / process / terminal I/O) and the target
is selected at **build time**, never by a per-OS source file. Through 0.6.2 that
posture was only ever exercised for one target: the default `cyrius build`
produces an x86_64 Linux binary, and CI/release built exactly that. M6 begins to
make the multi-target reach real. This ADR covers the first slice — wiring the
build machinery and bringing up the **Linux** target as a named, first-class
target — and records the state of the **AGNOS** target honestly.

The toolchain already supports the targets: `cyrius build` takes
`--agnos` / `--aarch64` / `--win`, each selecting the matching floor variant
(`syscalls_x86_64_agnos.cyr`, etc.) behind the one portable interface. No thoth
source changes per target; the source is already portable by construction.

AGNOS — the primary, most-capable home — does **not link today**, and the cause
is upstream in the floor, not in thoth. The dependency chain:

> thoth → **t-ron** audit chain (vendored) → **libro** `patra_store` (vendored,
> the SQL-backed audit persistence) → **patra** (stdlib embedded store) →
> `_pt_seek` → **`SYS_LSEEK`**

`SYS_LSEEK` is defined in the Linux, macOS, Windows, and aarch64 syscall floors
but is **absent from `syscalls_x86_64_agnos.cyr` in every toolchain version
checked (Cyrius 6.1.38 → 6.2.0)** — the AGNOS kernel ABI as exposed by the
stdlib has no file-seek syscall yet, and patra (an embedded SQL store) must seek
within its database file to persist libro's audit ledger. Corroboration: the
first-party projects that *do* ship AGNOS builds (`kriya`, `klug`) depend on no
`patra`; only `hoosh` and `thoth` do.

This is a **floor** gap. Fixing it means adding the syscall to the Cyrius stdlib
(out of this repo) — not forking the floor inside thoth, and not dropping the
t-ron audit chain on the target that is supposed to be the most capable. Neither
is thoth's call to make unilaterally.

## Decision

- **One build driver, `scripts/build.sh`**, is the single entry point that fans
  the one source tree out to targets: `linux` (default), `agnos`, `all`. It
  encodes the target matrix and its honesty in one place.
- **Linux (x86_64) ships** as the named host target → `build/thoth`, built,
  tested (186 assertions), and released exactly as before — now via the driver
  rather than an inline `cyrius build`.
- **AGNOS is staged, wired, and announced as blocked upstream**, never faked.
  The driver attempts `cyrius build --agnos` and surfaces the real result: the
  honest `SYS_LSEEK` link error today, a `build/thoth_agnos` the moment the
  floor catches up. `./scripts/build.sh all` builds Linux (the release gate)
  and then *attempts* AGNOS without letting the known block fail the run.
- **Out of scope, explicitly**: any fix to the Cyrius floor (it lives in another
  repo and is not thoth's to change without sign-off), and any capability cut
  (e.g. dropping patra / the libro audit store on AGNOS) to force a link. The
  AGNOS binary is not claimed until it actually links against an unmodified
  floor.

macOS, Windows, and aarch64 are future M6 slices: the floor variants exist, but
each is wired only once verified.

## Consequences

- **Positive** — the multi-target machinery exists and is honest; the Linux
  target is first-class and reproducible from one script; AGNOS lights up with
  zero thoth changes the instant the floor gains `lseek`. The capability/target
  matrix has one authoritative home (`scripts/build.sh` + this ADR + `state.md`).
- **Negative** — the headline "multi-target" is, today, one shipped target plus
  one staged-and-blocked target. We carry a known-red AGNOS path that a reader
  must understand is *upstream-blocked*, not *broken-in-thoth*.
- **Neutral** — follow-on: the upstream floor fix (tracked, not done here),
  bringing up macОS/Windows/aarch64, and the capability-ladder matrix that M6
  also owns. CI gains a Linux build via the driver; an AGNOS CI lane is deferred
  until it can be green.

## Alternatives considered

- **Fork the floor inside thoth** (define `SYS_LSEEK` in a thoth-owned AGNOS
  shim). Rejected: forbidden by ADR-0001 ("never fork the spine"/port-not-fork),
  and it would mean *guessing* the AGNOS lseek syscall number — a silent
  data-corruption risk in the audit ledger.
- **Drop patra / the libro audit store on AGNOS** to make thoth link without the
  seek dependency. Rejected: a security-capability cut on the target that is
  meant to be the *most* capable, and a unilateral architecture decision that is
  not thoth's to make here.
- **Ship Linux-only and say nothing about AGNOS.** Rejected: silent omission
  reads as "not attempted"; the honest-ladder doctrine wants the block named,
  with its cause, so it can't quietly mislead.
