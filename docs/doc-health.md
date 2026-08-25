---
name: thoth Documentation Health
description: Living state of doc currency in the thoth repo — fresh / durable / stale / open — refreshed as docs are touched
type: state
---

# Documentation Health — thoth

> **Last refresh**: 2026-08-25 (**full doc sweep at 0.43.0/0.43.1**). Six parallel auditors over README+CLAUDE.md, roadmap+gap-review, state.md, architecture+ADRs, guides+examples, and the root meta files — each cross-checking claims against **re-run measurements**, not against the previous reading.
> guides+examples, architecture, ADRs, and `state.md`'s current-state block against the live 0.33.7 state, then
> applied. Fixes: **roadmap** — "Where we are" re-anchored `0.31.5`→`0.33.7`; the shipped 0.32.x memory + 0.33.x
> chat-management arcs collapsed to a one-line "shipped so far" pointer; the sequenced heading advanced to 0.34.x;
> the stale "scheduled 0.32.x arc" phrasing fixed. **README** — the multi-conversation-management feature line +
> the full `build.sh` target set. **getting-started.md** — the command table gained the memory + 0.33.x commands
> (`/notes`, `/conversations`, `/new`, `/switch`, `/rename`, `/delete`, `/search`); the source layout gained
> `src/memlog.cyr` + `src/gui/{gmem,gconv}` + the `session.cyr` conversation store + the mneme memory-seam reframe.
> **architecture/002 + README** — the mneme ladder row/prose corrected: binds **remote-client via daimon** (full
> when hosted), the local `.thoth/memory` reader is the *degraded fallback* (was wrongly "native/degraded, awaits
> Cyrius port"). **adr/0017** — two `0.31.6`→`0.32.0` version-tag fixes. **adr/0012** — an "Update (0.32.x — native
> branch now live)" addendum. **state.md** — the frozen ~465-line `## Source`/`## Tests`/`## Next` per-module block
> (frozen at ~0.11.x, a drift-prone duplicate of the version log + CHANGELOG + the getting-started source map)
> **replaced** with a concise current "Surface at a glance" + the live 1675-assertion test summary + a current
> "Next"/v1.0-gate block. CLAUDE.md + `examples/` were already current. **Prior full sweep**: 2026-07-12 (0.31.5 —
> this ledger created). Between the two sweeps the **0.32.x memory arc** and **0.33.x chat-management arc** shipped
> via per-release refreshes (each cut: README stamp + CHANGELOG + state.md version-log entry + a roadmap trim — see
> CHANGELOG for the per-version detail).

> **Since that sweep** (per-release refreshes only, per the routine at the bottom of this file): the **0.34.x–0.38.x**
> cuts each landed a README stamp + CHANGELOG + `state.md` version entry. **0.38.6** additionally corrected two
> `state.md` blocks that had gone stale *without* being flagged here, both found by re-measuring rather than
> re-reading: the **`## Toolchain`** pin still read `6.4.78` (two pins behind — 0.38.5 bumped to 6.5.20 and never
> updated it), and the **`## Targets (build matrix)`** table was anchored at **0.6.4/0.6.6** across all five lanes.
> The matrix is now re-verified at 0.38.6 on real hardware for each lane, including a macOS row that flipped from
> "builds + runs" to **does not build** — a regression that had been invisible for ~30 releases because the row was
> never re-tested, only re-read. **Lesson for the next sweep**: a doc that states a *measurement* (a pin, a build
> status, a byte count) cannot be audited by reading it — the audit is re-running the measurement. Rows like these
> belong in a "re-measure" bucket, not "fresh".

> **0.43.0/0.43.1 sweep.** The 0.38.6 lesson above paid out twice. (1) The README claimed **"macOS builds
> + runs"** while the roadmap said the lane was broken — the README had never been re-tested, only
> re-read. Re-running it on real Apple Silicon confirmed BROKEN and let both files be re-stamped at
> 0.43.0 with current line numbers, replacing a claim five releases stale. (2) A figure this project had
> already **published** turned out to be a misread: 0.43.0's "preprocessor overflowed by 5,370 bytes" was
> the size at which expansion *aborted*, not a total, so a bigger probe file yields a bigger number for
> the same tree. Headroom is now measured by summing the include graph. **A number that came out of a
> tool is not automatically a measurement of the thing you think it measures** — check what the tool is
> reporting, not just that it reported something.
>
> The sweep also produced a **security fix**: documenting the parallel executor closely enough to describe
> it surfaced that `hooks_pre_tool` and the tool events lived only in the serial one, while
> `[hoosh].parallel` defaults ON. Shipped as 0.43.1. Worth recording as a reason to sweep docs at all —
> the audit was not the point, but reading the code to describe it truthfully was.
>
> Audited clean and worth stating: **roadmap.md and gap-review.md carried no completed work still narrated
> as open** — all nine numbered gaps and every carried-forward roadmap item re-verified open against
> source. The separation rule (roadmap supersedes gap-review, no item in both) holds.

> **0.39.0–0.42.0** each landed the routine refresh. **0.42.0** additionally **restructured the development
> docs on the user's instruction**: `roadmap.md` was rewritten forward-facing only, a new `gap-review.md` +
> `gap-review.html` pair now carries ONLY gaps the roadmap has *not* claimed, and
> `agentic-improvements-review.md` was **retired** (its tiers had shipped or been promoted). The separation
> rule is now explicit in both files: **the roadmap supersedes the gap review.** Applying the 0.38.6 lesson
> above, every *measurement* in the roadmap was re-run rather than re-read — the `CYRIUS_STATS` table
> (`fn_table` 8467/32768, identifiers 269459/524288, `var_table` 4856/8192, static data 1,001,720 B), the
> `--agnos` lane's actual warning output (which does NOT print "zero undefined symbols" as the gate claimed —
> three dead-path sit sign placeholders remain by design), and hoosh's real endpoint surface (the
> model-picker item claimed "if hoosh ever exposes it"; hoosh 2.6.3 already serves
> `/v1/health/providers`). Gate 3 was also re-pinned: it read "not scheduled" while the 0.39.0 audit had
> already swept two of its three areas.

> **0.43.0** added **ADR-0018** (subagent delegation) — the first ADR in this repo written as a *fence*
> rather than a decision record: half its content is an explicit non-goals list, because the feature sits
> next to the spine rule and the risk is a future contributor stretching it into orchestration. It also
> made `roadmap.md`'s Scheduled-work section empty again (both 0.43.0 pins shipped) and revised two
> `gap-review.md` entries whose premises the release changed — structural isolation of untrusted content
> (its prerequisite now exists) and budget enforcement (delegation made it more urgent). Both were edited
> rather than left to drift, which is the discipline the separation rule exists to enforce.

## At a glance

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh — touched this sweep** | ~11 | README, CHANGELOG, VERSION, state.md, roadmap.md, doc-health.md, getting-started, architecture/002 + README, adr/0012 + 0017 — current as of **0.33.7**. |
| 🔵 **Durable — decisions/invariants, re-read not rewrite** | ~17 | The unchanged ADRs (0001–0011, 0013–0016) + template + architecture/001 — point-in-time decisions/invariants, correct as history; re-read on a principle change, not per release. |
| 🟡 **Stale — refresh in place** | 0 | None outstanding after this sweep. |
| 🟠 **Read-through / gap** | 1 | `docs/examples/` is a usage cheat-sheet (README) + a redundant `.gitkeep`, not runnable example programs — CLAUDE.md bills it "Runnable examples". Either add real examples or reword the CLAUDE.md pointer. Non-blocking. |
| ❓ **Open question** | 0 | None. |

## Tier 1 — Structural / root

| File | Status | Notes |
|---|---|---|
| `README.md` | ✅ Fresh | **0.33.7** this sweep: the multi-conversation-management feature line (`/new`/`/switch`/`/search`, persisted with model/citations/tool calls) + the full `build.sh` target set. Status stamp, consumed-spine table, commands, build/run all verified vs `src/`. Bump the stamp every release. |
| `CHANGELOG.md` | ✅ Fresh | Source of truth for what shipped. Through **0.33.7**. Refreshed every release. |
| `CLAUDE.md` | ✅ Fresh | Durable preferences/process/procedures; carries no volatile state (that's `state.md`). Audited clean this sweep. |
| `VERSION` | ✅ Fresh | Single source of truth (`0.33.7`); `src/version.cyr` is generated from it via `scripts/gen-version.sh`. |

## Tier 2 — Architecture (`docs/architecture/`)

| File | Status | Notes |
|---|---|---|
| `001-consumer-only-no-domain-logic.md` | 🔵 Durable | The consumer-only invariant; verified current (reflects the write tools + all seven seams). |
| `002-capability-ladder.md` | ✅ Fresh | This sweep: the **mneme** row + prose corrected — binds remote-client via daimon (full when hosted), local reader is the degraded fallback. Seam table matches `src/seams.cyr`. |
| `README.md` | ✅ Fresh | This sweep: the mneme summary corrected to match 002 (remote-client via daimon, not native). |

## Tier 3 — Development (`docs/development/`)

| File | Status | Notes |
|---|---|---|
| `state.md` | ✅ Fresh | The live version log + current-state block. This sweep **replaced** the frozen ~465-line per-module `## Source`/`## Tests`/`## Next` block with a concise current "Surface at a glance" + the 1675-assertion test summary. Refreshed every release (a version-log entry per cut). |
| `roadmap.md` | ✅ Fresh | **Forward-facing only**, rewritten at **0.42.0**: v1.0 gates + version-pinned scheduled work + non-gating work + known limitations. When a milestone completes, move it to CHANGELOG, don't narrate it here. **It supersedes `gap-review.*`.** Its measurements were re-run at 0.42.0, not re-read. |
| `gap-review.md` / `.html` | ✅ Fresh | **New at 0.42.0**, replacing the retired `agentic-improvements-review.md`. Carries ONLY candidate gaps thoth has NOT committed to — anything on the roadmap is deliberately absent. The `.html` is the same content on the house design system (Artifact-shaped: starts at `<title>`, no doctype). |
| `doc-health.md` | ✅ Fresh | This file. This sweep also trimmed the bloated per-cut "Last refresh" trail. Opportunistic cadence. |

## Tier 4 — ADRs (`docs/adr/`)

| File | Status | Notes |
|---|---|---|
| `README.md` (index) | ✅ Fresh | Index verified complete this sweep — all 17 ADRs (0001–0017) have a row. Add a row whenever an ADR lands. |
| `0012-memory-seam-omit-until-mneme.md` | ✅ Fresh | This sweep: an "Update (0.32.x — native branch now live)" addendum (mneme Cyrius-ported + consumed via daimon; the producer swap completed). Historical decision unchanged. |
| `0017-model-edit-tool-jailed-gated-opt-in.md` | ✅ Fresh | This sweep: two `0.31.6`→`0.32.0` version-tag fixes (the atomic edit/create-write residual shipped in 0.32.0 on cyrius 6.4.57). |
| `0009` / `0015` | 🔵 Durable | Current (0009's 0.30.0 T3 addendum + 0015's appended update). |
| `0001`–`0008`, `0010`–`0011`, `0013`–`0014`, `0016` | 🔵 Durable | Point-in-time decisions; historical version stamps + assertion counts are correct as of each decision's date — do not "refresh" them. |
| `template.md` | 🔵 Durable | The ADR starting point. |

## Tier 5 — Guides + examples (`docs/guides/`, `docs/examples/`)

| File | Status | Notes |
|---|---|---|
| `guides/getting-started.md` | ✅ Fresh | This sweep: the command table gained the memory + 0.33.x chat-management commands; the source layout gained `src/memlog.cyr`, `src/gui/{gmem,gconv}`, the `session.cyr` conversation store, and the mneme memory-seam reframe. |
| `examples/README.md` | 🟠 Read-through | A usage cheat-sheet, re-verified accurate this sweep (`--json` envelope, flags, `.thoth/` discovery match `src/`). Not runnable programs — see the at-a-glance note. |
| `examples/.gitkeep` | 🔵 Durable | Redundant (the README already tracks the dir); harmless. |

## Refresh procedure

When docs are touched:

1. Find the affected row in the relevant tier table and update its **Status** / **Notes**.
2. Bump the version stamp in any Tier-1 doc that carries one (README status line; state.md/roadmap "Where we are").
3. Re-anchor the **Last refresh** line at the top; keep a one-line **Prior** trail if a full sweep ran.
4. When a milestone/version completes, record it in `CHANGELOG.md` (+ a `state.md` version entry) — **not** in `roadmap.md`, which is forward-only.

Cadence is **opportunistic** (touched when other docs are), not periodic — but a full sweep is worth running at a minor closeout or when a release burst has piled up drift.

## What this file is NOT

- Not the [`state.md`](development/state.md) version ledger (which holds the per-version log + current-state block).
- Not a CHANGELOG (which records what shipped, not where each doc stands).
- Not a TODO list (open work lives in [`development/roadmap.md`](development/roadmap.md)).
