# 0004 — SemVer 0.x in pre-release, not CalVer

**Status**: Accepted
**Date**: 2026-06-09

## Context

The first-party standards version consumer apps and binaries with CalVer
(`YYYY.M.D[-N]`) and shared library crates with SemVer. thoth is a binary, so
the standard's default is CalVer. The identity docs drafted 2026-06-08 recorded
a "CalVer cutover at the first real release."

thoth's first real release — `0.1.0`, the M2 driver core — is deliberately a
pre-1.0, surface-moving release: the entire capability spine is absent, the
command set and seam interface will change, and the project announces "early /
fermenting" loudly. The maintainer chose to keep SemVer `0.1.0` for this
release rather than cut to CalVer now.

## Decision

thoth uses **SemVer `0.x`** throughout its pre-1.0 phase. The `VERSION` file
holds a SemVer number and the binary ships under it.

In scope: every `0.x` release while the surface is still moving. Out of scope:
the post-1.0 scheme — whether thoth adopts CalVer at 1.0 (per the binary
standard) or stays SemVer — which is deferred to a later ADR, decided when 1.0
is in sight.

## Consequences

- **Positive** — the version honestly signals pre-1.0 instability (`0.x` = the
  surface still moves), which a CalVer date cannot express; it matches how the
  project already describes itself.
- **Negative** — a deliberate deviation from the first-party binary-CalVer
  standard. A reader who knows the standard will (correctly) ask why; this ADR
  is the answer. The post-1.0 scheme is left open.
- **Neutral** — `docs/development/state.md` and `roadmap.md` carry the live
  scheme; the earlier "CalVer at first release" note is superseded by this ADR.

## Alternatives considered

**CalVer `2026.6.9` now** (the standard's default for binaries) — rejected for
this release: a CalVer date can't express pre-1.0 instability and implies a
maturity thoth doesn't yet claim. Reconsidered at 1.0.

**Commit to SemVer forever** — premature. The post-1.0 choice is genuinely open
and is deferred rather than decided here.
