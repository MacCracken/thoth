# 002 — The capability ladder: binding mode × capability effect

> Non-obvious invariant — *how the world is*, not *what we chose*. The choices
> behind it are in the ADRs ([`../adr/`](../adr/)); this note states the standing
> fact a reader can't derive from the code alone, and pins where it is enforced
> so it cannot drift. It is the M6 "capability ladder, documented and honest"
> deliverable (see [`../development/roadmap.md`](../development/roadmap.md)).

## The invariant

Every spine capability thoth consumes is described by **two orthogonal
dimensions**, and the second cannot be inferred from the first:

1. **Binding mode** — *how* the seam is reached: `native` (vendored in-process,
   the AGNOS-canonical shape), `remote-client` (reached over a portable transport
   when `.thoth/config.cyml` declares an endpoint), or `absent` (no binding).
2. **Capability effect** — *what the user actually gets*: `full`, `degraded`
   (a reduced, fail-closed fallback stands in), or `absent` (the capability is
   gone — announced, never faked).

The two are distinct because **a seam can be `absent` at the binding layer yet
`degraded` (not `absent`) at the capability layer** — when thoth stands a
built-in fallback in its place. The whole point of "fails closed, announced,
never faked" lives in that gap.

## The ladder (per seam)

Derived live from `seam_status` in [`../../src/seams.cyr`](../../src/seams.cyr);
this table is the prose mirror, not a second source of truth.

| Seam | Binds | When | Effect when bound | Effect otherwise |
|---|---|---|---|---|
| **hoosh** | remote-client | `[hoosh].url` set | **full** — turns route to a backing model; mid-session `/model` switch | **absent** — no model turns; local REPL commands only (announced) |
| **daimon** | remote-client | `[daimon].url` set | **full** — `/tools` registry, `/call` execution, the agentic loop | **absent** — no tools; `/tools`/`/call`/loop report absent |
| **bote** | native | always (vendored) | **full** — MCP protocol framing, in-process | — (never absent) |
| **t-ron** | native | `[tron].policy` loads | **full** — per-tool authz on `/run`/`/write`/`/call`; deny is final | **degraded** — built-in fail-closed confirm gate (deny/prompt); **never** a silent allow |
| **avatara** | native | always (vendored) | **full** — the Thoth/Librarian archetype steers every turn | — (never absent) |
| **mneme** | native | `[memory].enabled` + `.thoth/memory/` present | **degraded** — the local `.thoth/memory` flat-file reader injects facts (full semantic recall awaits mneme's Cyrius port) | **absent** — no memory injected |
| **sit** | native | a git repo at the working dir | **full** — branch/status + per-file diff (`/git`, the `/state` row, the status-bar branch) | **absent** — no repo; the git surface reports absent |

The rows that make the two-dimension model necessary are **t-ron** and **mneme** —
in both, the capability effect can't be read off the binding mode. t-ron's binding
goes `native → absent` while its effect goes `full → degraded` (never `absent`):
there is no reachable state in which an action is silently allowed — security
degrades **closed**. mneme *binds* `native` yet its effect is only `degraded` (the
local reader stands in for mneme's not-yet-ported engine). Neither the "safe" nor
the "reduced" state can be inferred from whether the seam is bound.

## What it affects

- **The ladder is computed, not narrated.** `seam_cap_state(id)` resolves the
  effect from the live binding status; `/seams` renders both dimensions. A reader
  (or a release) must not assert a capability state by hand — read it from the
  registry, or the doc and the binary drift apart. This table exists only to
  explain the model; `src/seams.cyr` decides it.
- **Adding a seam or a fallback** means extending `seam_cap_state` /
  `seam_cap_full` / `seam_cap_fallback` together, with a unit test asserting the
  effect (see `test_capability_ladder` in [`../../tests/thoth.tcyr`](../../tests/thoth.tcyr)).
  A new degraded fallback in particular must be fail-closed and announced — the
  t-ron pattern, never a silent stand-in.
- **Never collapse the two dimensions.** "absent binding" is not "absent
  capability." Anyone tempted to report t-ron's missing policy as simply "off"
  is erasing the fail-closed gate that is actually standing in — a security
  misstatement, not a simplification.

See [001](001-consumer-only-no-domain-logic.md) for why thoth holds none of these
domains itself, and [ADR-0008](../adr/0008-multi-target-builds.md) for the
target/build matrix (the *substrate* ladder, below thoth) that this *capability*
ladder (above thoth) sits orthogonal to.
