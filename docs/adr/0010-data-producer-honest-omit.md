# 0010 — Data-producer honest-omit: surface a field only when present, never fake

**Status**: Accepted
**Date**: 2026-06-25

## Context

The `Thoth.dc.html` design mockup shows a status line rich with operational
data: token count, context-%, cost (`$d.cc`), and the git branch + a real diff.
thoth ships those fields one producer at a time (the 0.10.x arc: tokens 0.10.2,
cost 0.10.3, git 0.10.4), and some producers are **gated on external work** —
cost needs an opt-in `[pricing]` table thoth can't invent, git needs **sit**'s
`.git/` read-mode (filed on sit's roadmap; sit is not vendored). Streaming hoosh
turns carry **no** `usage` unless `stream_options:{include_usage:true}` is sent,
so even tokens can be legitimately absent for a given turn.

The tempting failure is to fill a missing field with a placeholder — `0`,
`(n/a)`, a guessed cost, a branch read by a hand-rolled `.git/HEAD` parser. Every
one of those is a **fake**: it reads as "thoth has this datum" when thoth does
not, and (worse) a hand-rolled git parser would **fork the spine** (sit owns VCS).

thoth already runs this discipline on the security layer ([ADR-0001](0001-os-agnostic-agnos-primary.md):
security degrades **closed** and is **announced, never faked**) and on the
presentation tiers ([ADR-0009](0009-presentation-capability-ladder.md): faked
data the mockup shows but thoth lacks must **omit until a producer lands**). This
ADR lifts that to a first-class, recurring policy for the **information layer** so
every future producer inherits it.

## Decision

**A data field surfaces only when its producer has real data; otherwise it is
omitted entirely and its absence is announced honestly in `/state` — never
faked.** Concretely:

- **Omit, don't placeholder.** A status-bar field (tokens / cost / branch) emits
  nothing when its producer is absent — no `0`, no `(n/a)`, no guess. A guarded
  emit, never an unconditional one.
- **Announce the gap where it's diagnosable.** `/state` (and `/seams` where a
  seam is involved) carries one honest line naming *why* a datum is absent — e.g.
  `git : absent — gated on sit`, mirroring the existing absent-seam lines. The
  absence reads as "feature not present / off-AGNOS / external dep," never "thoth
  lacks the capability."
- **Consume the owner, never reimplement it.** Cost comes only from a
  user-declared `[pricing]` table × hoosh's own `usage` numbers — hoosh owns
  inference/routing/cost; thoth multiplies what it's told. Git data comes only
  from **sit**; thoth never parses `.git/` itself (that forks sit's domain). The
  existing `src/diff.cyr` is the `/write` old→new LCS diff and is **never**
  promoted into a git diff.

## Consequences

- **Positive** — a new contributor adding the next producer inherits the rule:
  omit-not-fake is doctrine, not a temporary workaround. The status line is always
  truthful: what it shows is real, what it hides is honestly explained. No fake
  datum can ship by accident, and no producer can sneak in a hand-rolled spine.
- **Negative** — the surface looks "less complete" than the mockup until each
  producer lands (the mockup is a *target*, not a contract). Accepted: a sparse,
  honest line beats a full, lying one.
- **Neutral** — turns the mockup's data fields into a small backlog of producer
  tasks (0.10.2 tokens, 0.10.3 cost, 0.10.4 git-via-sit), each shippable and
  verifiable on its own, none of them v1.0-gating.

## Alternatives considered

- **Placeholder values (`0` / `(n/a)` / a guessed cost).** Rejected: indistinguishable
  from real data at a glance — the exact "fake" the doctrine forbids.
- **Hand-roll a `.git/HEAD` reader for the branch now (don't wait for sit).**
  Rejected: forks the spine — sit owns VCS. thoth announces the gap and waits.
- **Hide the absence silently (omit with no `/state` note).** Rejected: "announce,
  never fake" is the whole point — a silently-missing field is indistinguishable
  from a bug; the honest line tells the user *why* it's absent.
