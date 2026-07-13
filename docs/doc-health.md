---
name: thoth Documentation Health
description: Living state of doc currency in the thoth repo — fresh / durable / stale / open — refreshed as docs are touched
type: state
---

# Documentation Health — thoth

> **Last refresh**: 2026-07-12 (**0.32.5 — GUI memory surfacing cut**: README stamp `0.32.4`→`0.32.5`, CHANGELOG +
> state.md `[0.32.5]` entries, roadmap 0.32.x trimmed (GUI surfacing shipped → remaining = notebook mode only)).
> **Prior**: 2026-07-12 (**0.32.4 — grounding indicator cut**: README stamp `0.32.3`→`0.32.4` + the grounding note,
> CHANGELOG + state.md `[0.32.4]` entries, roadmap trimmed). **Prior**: 2026-07-12 (**0.32.3 — citations cut**:
> README stamp `0.32.2`→`0.32.3` + the cited-sources note, CHANGELOG + state.md `[0.32.3]` entries). **Prior**:
> 2026-07-12 (**0.32.2 — semantic recall via mneme cut**: README
> stamp `0.32.1`→`0.32.2` + the recall line, CHANGELOG + state.md `[0.32.2]` entries, roadmap 0.32.x trimmed).
> **Prior**: 2026-07-12 (**0.32.1 — GUI pane toggles cut**:
> README stamp `0.32.0`→`0.32.1`, CHANGELOG + state.md `[0.32.1]` entries, toolchain pin `6.4.57`→`6.4.58`).
> **Prior**: 2026-07-12 (**0.32.0 — mneme memory
> seam + crash-safe atomic writes cut**). Bumped the README
> status stamp `0.31.5`→`0.32.0` + the mneme memory-seam line; **CHANGELOG**/**state.md** `[0.32.0]` entries;
> **roadmap.md** 0.32.x reframed forward-only (seam+write shipped → CHANGELOG; remaining = recall/citations/grounding
> + the daimon→mneme host prerequisite); **adr/0017** non-atomic-write residual marked RESOLVED (cyrius 6.4.57
> `file_write_atomic`/`file_create_exclusive`). **Prior**: 2026-07-12 (0.31.5 — full doc-staleness sweep + this
> ledger created). Multi-agent audit of README / guides / architecture / ADRs against the live state, then apply. Fixes: **README** status
> stamp `0.30.2` → `0.31.5` and the shipped **write tools** (`edit`/`create_file`) + GUI **tool-call + colored
> diff cards** folded into the feature narrative; **getting-started.md** dead `tests/thoth.tcyr` refs (×3) →
> the split `tests/thoth_{core,gui,render}.tcyr` + `tests/cases/*.cyr` suites, the `thoth gui` subcommand added,
> and the source-layout inventory updated (`src/edit`/`editlog`/`surface`/`intr` + the whole `src/gui/` subtree +
> the `kashi`/`sankoch`/`sit-read` vendors); **architecture/002** dead-test ref + t-ron row (added the model
> `thoth_edit`/`thoth_shell` verbs); **adr/README** index (**+ADR-0017**, dropped the volatile avatara version,
> corrected the AGNOS status from the resolved `SYS_LSEEK` gap); **ADR-0009**'s two lingering "thoth-in-puka"
> claims marked *revised*. **roadmap.md** stripped of the completed 0.27→0.31.5 per-version narrative
> (forward-facing only, per its own header). No stale item found in `docs/examples/`.

## At a glance

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh — touched this sweep** | ~9 | README, CHANGELOG, VERSION, state.md, roadmap.md, getting-started, architecture/002, adr/README, adr/0009 — current as of 0.31.5. |
| 🔵 **Durable — decisions/invariants, re-read not rewrite** | ~18 | The 16 unchanged ADRs (0001–0008, 0010–0016) + template + architecture/001 + architecture/README — point-in-time decisions/invariants, correct as history; re-read on a principle change, not per release. |
| 🟡 **Stale — refresh in place** | 0 | None outstanding after this sweep. |
| 🟠 **Read-through / gap** | 1 | `docs/examples/` is a usage cheat-sheet (README) + a redundant `.gitkeep`, not a set of runnable example programs — CLAUDE.md bills it "Runnable examples". Either add real examples or reword the CLAUDE.md pointer. Non-blocking. |
| ❓ **Open question** | 0 | None. |

## Tier 1 — Structural / root

| File | Status | Notes |
|---|---|---|
| `README.md` | ✅ Fresh | Refreshed to **0.31.5** this sweep: status stamp + the shipped write tools (`edit`/`create_file`, `thoth_edit`-gated, opt-in) + GUI tool-call/diff cards. The consumed-spine table, commands, and build/run block verified against `src/`. Update the status stamp every release. |
| `CHANGELOG.md` | ✅ Fresh | Source of truth for what shipped. Through **0.31.5**. Refreshed every release. |
| `CLAUDE.md` | ✅ Fresh | Durable preferences/process/procedures. Volatile state lives in `state.md`, not here. |
| `VERSION` | ✅ Fresh | Single source of truth (`0.31.5`); `src/version.cyr` is generated from it via `scripts/gen-version.sh`. |

## Tier 2 — Architecture (`docs/architecture/`)

| File | Status | Notes |
|---|---|---|
| `001-consumer-only-no-domain-logic.md` | 🔵 Durable | The consumer-only invariant; verified current (already reflects the shipped file-edit tools + all seven seams). |
| `002-capability-ladder.md` | ✅ Fresh | This sweep: dead `tests/thoth.tcyr` → `tests/cases/core.cyr`; t-ron row now names the model verbs (`thoth_edit`/`thoth_shell`/`thoth_remember`). Seam table matches `src/seams.cyr`. |
| `README.md` | 🔵 Durable | 001/002 summaries accurate; links resolve. |

## Tier 3 — Development (`docs/development/`)

| File | Status | Notes |
|---|---|---|
| `state.md` | ✅ Fresh | The live version ledger + current-state block. Refreshed every release (each cut appends a version entry). |
| `roadmap.md` | ✅ Fresh | **Forward-facing only** — this sweep stripped the completed 0.27→0.31.5 per-version narrative; keeps the four v1.0 gates, non-gating future, and out-of-scope. When a milestone completes, move it to CHANGELOG, do not narrate it here. |
| `doc-health.md` | ✅ Fresh | This file. Opportunistic cadence (touched when other docs are). |

## Tier 4 — ADRs (`docs/adr/`)

| File | Status | Notes |
|---|---|---|
| `README.md` (index) | ✅ Fresh | This sweep: **+0017**, dropped the volatile avatara version from the 0007 summary, corrected the 0008 AGNOS status (`SYS_LSEEK` resolved; build cleared, runtime pends a host). Add a row whenever an ADR lands. |
| `0009-presentation-capability-ladder.md` | ✅ Fresh | This sweep: the two remaining "thoth-in-puka" claims (Consequences + Alternatives) marked *revised* per the 0.30.0 addendum — T3 shipped as thoth's own Wayland app. |
| `0015` / `0017` | 🔵 Durable | Current (0015's 0.23.1 update + 0017's 0.31.3 `create_file` update are appended correctly). |
| `0001`–`0008`, `0010`–`0014`, `0016` | 🔵 Durable | Point-in-time decisions; historical version stamps + assertion counts are correct as of each decision's date — do not "refresh" them. |
| `template.md` | 🔵 Durable | The ADR starting point. |

## Tier 5 — Guides + examples (`docs/guides/`, `docs/examples/`)

| File | Status | Notes |
|---|---|---|
| `guides/getting-started.md` | ✅ Fresh | This sweep: dead `tests/thoth.tcyr` (×3) → the split suites; `thoth gui` added; source layout updated (`src/edit`/`editlog`/`surface`/`intr` + `src/gui/` + `kashi`/`sankoch`/`sit-read`); write tools noted. |
| `examples/README.md` | 🟠 Read-through | A usage cheat-sheet, verified accurate (`--json` envelope, flags, `.thoth/` discovery all match `src/`). Not a set of runnable programs — see the at-a-glance note. |
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
