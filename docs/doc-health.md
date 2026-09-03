---
name: thoth Documentation Health
description: Living state of doc currency in the thoth repo — fresh / durable / stale / open — refreshed as docs are touched
type: state
---

# Documentation Health — thoth

> **Touched at 0.44.3** (2026-09-03, not a full sweep): the release added
> [`docs/adr/0021-authority-keys-are-global-only.md`](adr/0021-authority-keys-are-global-only.md) and
> indexed it in `adr/README.md`; marked **ADR-0019 superseded in part** (its "a project t-ron policy"
> example is retracted); updated `CHANGELOG.md`, `docs/development/state.md` (version block, Tests
> counts, the Toolchain block re-measured with `CYRIUS_STATS` **after the last edit**, the Targets
> matrix — macOS now BUILDS+RUNS, Windows blocked outside thoth's source — and two new
> Surface-at-a-glance rows for `term`/`budget`), `docs/development/roadmap.md` (v1.0 gate 3's
> concurrency half **closed**; the macOS/Windows ⛔ limitation replaced with what actually remains; a
> new ⛔ for the hooks-argv exposure; the `[ui].theme` polish item removed as shipped; the GUI
> slash-command item re-valued), `docs/development/gap-review.md` **and its `.html` twin in lockstep**
> (budget enforcement shipped → removed), `README.md` (status stamp),
> `.thoth/config.cyml.example` (`[budget]`, `[ui].theme`, and the now-false "no budget enforcement"
> line inside `[subagent]`), and `docs/guides/getting-started.md` (source layout: `term.cyr`,
> `budget.cyr`). Filed upstream:
> `cyrius/docs/development/issues/2026-09-03-macos-getenv-always-null-no-proc.md`.
> The rows below still carry their 0.43.2 sweep status.
>
> **Touched at 0.44.2** (2026-08-27, not a full sweep): the release updated `CHANGELOG.md`,
> `docs/development/state.md` (version block, Tests counts, the Front-doors/Observability surface rows),
> `docs/development/roadmap.md` (a new ⛔ carried limitation — hoosh dropping SSE frames and laundering
> provider errors into an empty 200 stream), `README.md` (status stamp), `.thoth/config.cyml.example`
> (`[hoosh].timeout_ms`, and `--logs` documented in the `[log]` block), `docs/examples/README.md` (a new
> §4b on capturing a session that crashes or hangs) and `docs/guides/getting-started.md` (`--logs` in the
> CLI list + a paragraph on it and `timeout_ms`). The rows below still carry their 0.43.2 sweep status.
>
> **Last full refresh**: 2026-08-25 — **full doc sweep at 0.43.2**, run as six parallel reviewers (repo
> hygiene, cross-doc consistency, the config/legacy-path surface, recently-changed code, the scripts,
> the test suite), each finding handed to an independent skeptic before it was acted on. Every claim was
> checked against the file it describes, and every *measurement* was re-run rather than re-read.
>
> **Prior full sweeps**: 0.43.0/0.43.1 (prose only — see the lessons below), 0.33.7, 0.31.5 (this ledger
> created).

## The three lessons this ledger exists to carry

These are the reason the file is worth keeping. Each was paid for.

1. **A doc that states a MEASUREMENT cannot be audited by reading it — the audit is re-running the
   measurement.** (0.38.6.) The `## Toolchain` pin sat two versions behind and the `## Targets` matrix
   was anchored at 0.6.4/0.6.6 across all five lanes. Re-running them flipped the macOS row from
   "builds + runs" to **does not build** — a regression invisible for ~30 releases because the row was
   re-read, never re-tested. Rows like these belong in a "re-measure" bucket, not "fresh".

2. **A number that came out of a tool is not automatically a measurement of the thing you think it
   measures.** (0.43.1.) 0.43.0 *published* "the preprocessor overflowed by 5,370 bytes". That was the
   size at which expansion **aborted**, not a total — so a bigger probe file yields a bigger number for
   the same tree. Headroom is measured by summing the include graph. The retraction had to chase the
   figure through `roadmap.md` and `gap-review.md`, which had both already built arguments on it.

3. **Prose that is prepended rather than merged leaves the file contradicting itself.** (Found at
   0.43.2.) The 0.43.0/0.43.1 sweep wrote a new "Last refresh" block on top of the 0.33.7 one and never
   re-stamped the tables below — so every Tier row still said "this sweep:" about work done ten releases
   earlier, and a dangling sentence fragment sat at the seam. The ledger asserted freshness it had not
   checked, which is precisely how `getting-started.md` and `CONTRIBUTING.md` drifted unnoticed. **If a
   sweep does not re-stamp the tables, it did not happen.**

## What the 0.43.2 sweep actually found

47 confirmed findings. The ones that mattered most, recorded so the next sweep knows where to look:

- **A security defect the read-only review could not have found** — it needed the binary run. Piped
  stdin (`git diff | thoth 'review'`, advertised in `--help`) reached `cmd_task`, whose second act is
  the **unjailed** `@mention` reader; a `@/path` line inside third-party piped content was read and
  POSTed to the gateway, silently. Fixed by splitting the task by provenance. **Reviewing source is not
  the same as exercising the program.**
- **Two docs disagreeing is a defect, not a style issue.** `state.md`'s `## Next` still said "macOS
  builds+runs" — the exact claim the previous sweep records itself as having corrected in the README —
  120 lines from its own Targets matrix saying the opposite.
- **`gap-review.html` had drifted a release behind `gap-review.md`.** Two copies of one document always
  drift. They are now labelled as twins with an explicit "edit both, or neither".
- **Three files had no row in this ledger at all** (`CONTRIBUTING.md`, `SECURITY.md`,
  `CODE_OF_CONDUCT.md`) while the sweep prose claimed the root meta files were covered. CONTRIBUTING was
  17 releases stale; SECURITY told a reporter no tagged release existed, against 158 tags. **An absent
  row is worse than a stale one — nothing will ever flag it.**

## At a glance

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh — touched this sweep** | ~16 | README, CLAUDE.md, CHANGELOG, VERSION, CONTRIBUTING, SECURITY, state.md, roadmap.md, gap-review.md + .html, doc-health.md, getting-started, adr/0017, adr/README — current as of **0.43.2**. |
| 🔵 **Durable — decisions/invariants, re-read not rewrite** | ~19 | ADRs 0001–0016 + 0018 + 0020 + template, architecture/001 — point-in-time decisions, correct as history; re-read on a principle change, not per release. |
| 🟡 **Stale — refresh in place** | 0 | None outstanding after this sweep. |
| 🟠 **Read-through / gap** | 1 | `docs/examples/` is a usage cheat-sheet, not runnable programs. **Closed by rewording** at 0.43.2 (README + CLAUDE.md now say "usage cheat-sheet"); the row stays until real examples exist or the dir is retired. |
| ❓ **Open question** | 0 | None. |

## Tier 1 — Structural / root

| File | Status | Notes |
|---|---|---|
| `README.md` | ✅ Fresh | **0.43.2**: status stamp; a stray unfinished editing note removed from the front page (an orphaned "SCRIBE" backronym competing with the project's own, plus an agnosai claim the gap review had declined); `docs/examples/` reworded off "runnable examples"; the two root design assets (`Thoth.dc.html`, `thoth_v1.tiff`) named so neither reads as scratch. Bump the stamp every release. |
| `CHANGELOG.md` | ✅ Fresh | Source of truth for what shipped. Through **0.43.2**. Refreshed every release. |
| `CLAUDE.md` | ✅ Fresh | Durable preferences/process/procedures; carries no volatile state (that is `state.md`). **0.43.2**: the `docs/examples/` pointer reworded. |
| `CONTRIBUTING.md` | ✅ Fresh | **NEW ROW at 0.43.2** — it had none, and was stamped **0.26.0**, seventeen releases stale, with a feature list predating the write tools, `/rewind`, `[redact]`/`[guard]`/`[hooks]`/`[toolpin]`/`[verify]`, `--events`, subagents and MCP resources. Re-stamped 0.43.2. **It is the first file a new contributor reads — bump it on any feature-surface change.** |
| `SECURITY.md` | ✅ Fresh | **NEW ROW at 0.43.2** — it claimed "no tagged release exists yet" against 158 tags, and pointed at a "first CalVer release" that [ADR-0004](adr/0004-semver-pre-release.md) formally rejected. Now: pre-1.0 SemVer `0.x`, fixed-forward support, and a live link to `docs/audit/`. |
| `CODE_OF_CONDUCT.md` | 🔵 Durable | **NEW ROW at 0.43.2.** Carries no version-bound claims; re-read on a policy change, not per release. |
| `VERSION` | ✅ Fresh | Single source of truth (`0.43.2`); `src/version.cyr` is generated from it via `scripts/gen-version.sh` (which `scripts/build.sh` runs before every build — and which, until 0.43.2, could silently fail to resolve and let the build ship a stale version string). |

## Tier 2 — Architecture (`docs/architecture/`)

| File | Status | Notes |
|---|---|---|
| `001-consumer-only-no-domain-logic.md` | 🔵 Durable | The consumer-only invariant; verified current (reflects the write tools + all seven seams). |
| `002-capability-ladder.md` | ✅ Fresh | Re-verified at 0.43.2: the seam table still matches `src/seams.cyr` on all seven seams. |
| `003-two-roots-project-jail-vs-mcp-host.md` | ✅ Fresh | **New at 0.44.1.** thoth's project jail (launch cwd) vs an MCP host's own root (`$BOTE_FS_ROOT`) — two roots, one description, and the registry advertised first. Written from a reproduced live failure, not from reading the code. Records what was tried and **removed** (a prose note on tool descriptions, measured as no-effect). |
| `README.md` | ✅ Fresh | Re-verified at 0.44.1; indexes 001-003. |

## Tier 3 — Development (`docs/development/`)

| File | Status | Notes |
|---|---|---|
| `state.md` | ✅ Fresh | The live version log + current-state block. **0.43.2 fixed five stale claims that contradicted this same file**: `## Next` said "macOS builds+runs" (its own matrix says otherwise); `## Posture` said "all five seams" (`SEAM_COUNT = 7`), pinned avatara at 2.14.0 (the bundle says 2.14.1), and named the legacy `thoth.cyml` as the binding config; `## Tests` reported 1675 assertions "as of 0.33.7"; the Targets matrix was anchored at 0.38.6 with stale `src/tui.cyr` line numbers. **Re-measure, do not re-read.** |
| `roadmap.md` | ✅ Fresh | **Forward-facing only.** When a milestone completes, move it to the CHANGELOG — do not narrate it here. **It supersedes `gap-review.*`.** **0.43.2**: the `CYRIUS_STATS` table re-run (not re-read), and the retracted "over by 5,370 bytes" figure replaced with the include-graph measurement — including withdrawing the "most likely thing to block the next feature" claim that was derived from it. |
| `gap-review.md` | ✅ Fresh | Carries ONLY candidate gaps thoth has **not** committed to; anything on the roadmap is deliberately absent. **0.43.2**: the `~96 %` ceiling figure (same retracted misread) corrected; two references to the subagent ADR as forthcoming work fixed (it shipped at 0.43.0); open question Q3 restated on a premise that still exists; gap 4 updated to five untrusted-prose inlets. |
| `gap-review.html` | ✅ Fresh | **The rendered twin of `gap-review.md`, not an older draft** — same content on the house design system, Artifact-shaped (starts at `<title>`, no doctype). It had drifted a release behind (three inlets, no subagent strength, the pre-retraction ceiling figure) and was re-synced at 0.43.2. ⚠ **Edit both, or neither.** |
| `doc-health.md` | ✅ Fresh | This file. Rewritten at 0.43.2 — the previous version's tables were still the 0.33.7 sweep's rows under 0.43.0/0.43.1 prose. Opportunistic cadence. |

## Tier 4 — ADRs (`docs/adr/`)

| File | Status | Notes |
|---|---|---|
| `README.md` (index) | ✅ Fresh | Index verified complete at 0.43.2 — **all 18 ADRs (0001–0018)** have a row. (The previous ledger row asserted "all 17 (0001–0017)"; the index itself was correct and already carried 0018 — the ledger's verification claim was the stale part.) Add a row whenever an ADR lands. |
| `0017-model-edit-tool-jailed-gated-opt-in.md` | ✅ Fresh | **0.43.2**: fixed the doc set's only broken relative link — a "filed and shipped" link pointed at `docs/development/issues/`, a directory that does not exist in this repo (the issue lives in cyrius). Now a plain repo-qualified path, matching how `roadmap.md` cites the same class of cross-repo issue. |
| `0018-subagent-delegation-scoped-child-context.md` | 🔵 Durable | The first ADR here written as a **fence** rather than a decision record — half its content is an explicit non-goals list, because the feature sits next to the spine rule. Its swap-set claim ("the complete list … provable by enumeration") was **tested and found incomplete at 0.43.2** (memory recall + citations were missing); the ADR's reasoning stands, its enumeration was extended. |
| `0009` / `0012` / `0015` / `0016` | 🔵 Durable | Current (each carries its own dated addendum). |
| `0001`–`0008`, `0010`–`0011`, `0013`–`0014` | 🔵 Durable | Point-in-time decisions; historical version stamps + assertion counts are correct as of each decision's date — **do not "refresh" them.** |
| `template.md` | 🔵 Durable | The ADR starting point. |

## Tier 5 — Guides + examples (`docs/guides/`, `docs/examples/`)

| File | Status | Notes |
|---|---|---|
| `guides/getting-started.md` | ✅ Fresh | **Was marked Fresh while anchored at 0.33.7** — the exact failure lesson 3 describes. **0.43.2**: "five spine seams" → seven; the 12 missing `src/*.cyr` modules added to the source layout (checkpoint, events, guard, hooks, mcpres, mdmodel, reasonlog, redact, search, subagent, toolpin, verify) — a scripted check now confirms **all 48 modules** have an entry; and the command reference gained `/context`, `/compact`, `/rewind`, `/fork`, `/grants`, `/resources`, `/resource`, `/prompts`. |
| `examples/README.md` | 🟠 Read-through | A usage cheat-sheet, re-verified accurate. Not runnable programs — README and CLAUDE.md were reworded at 0.43.2 to stop promising otherwise (the ledger had previously named only CLAUDE.md, under-scoping its own finding). |
| `examples/.gitkeep` | 🔵 Durable | Redundant (the README already tracks the dir); harmless. |

## Refresh procedure

When docs are touched:

1. Find the affected row in the relevant tier table and update its **Status** / **Notes**.
2. Bump the version stamp in any Tier-1 doc that carries one (README status line, CONTRIBUTING status
   line, `state.md`/`roadmap.md` "Where we are").
3. Re-anchor the **Last refresh** line at the top — and **re-stamp the tables in the same pass**. Prose
   prepended over un-updated tables is lesson 3.
4. **Re-run every measurement the docs state** (`CYRIUS_STATS`, suite counts, build-lane status, byte
   counts, line numbers in quoted errors). Re-reading one is not auditing it.
5. When a milestone/version completes, record it in `CHANGELOG.md` (+ a `state.md` version entry) —
   **not** in `roadmap.md`, which is forward-only.
6. If a file has no row here, **add one** rather than assuming it is covered.

Cadence is **opportunistic** (touched when other docs are), not periodic — but a full sweep is worth
running at a minor closeout or when a release burst has piled up drift.

## What this file is NOT

- Not the [`state.md`](development/state.md) version ledger (which holds the per-version log +
  current-state block).
- Not a CHANGELOG (which records what shipped, not where each doc stands).
- Not a TODO list (open work lives in [`development/roadmap.md`](development/roadmap.md)).
