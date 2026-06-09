# thoth — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.
>
> **Status: fermenting.** thoth is a long-horizon idea-log, not yet
> built into feature code. Everything below M0 is **provisional** —
> the ordering, the version labels, and the dep gates will move as the
> design settles. Treat this as direction, not commitment.

## Framing (read first)

thoth is **OS-agnostic at the substrate layer and AGNOS-sovereign at the
capability layer**. The two never collide because they govern different
layers:

- **The floor — portable.** Syscalls, allocation, argv, process spawn,
  terminal I/O. The vendored Cyrius stdlib already fans this out across
  one shared codebase to multiple targets behind one stable interface
  (`syscalls_x86_64_agnos` / `syscalls_x86_64_linux` /
  `syscalls_aarch64_linux` / `syscalls_macos` / `syscalls_windows`, plus
  matching `alloc_` / `args_` / `process_` variants). thoth writes
  against the portable interface and picks the target at build time —
  never against a per-OS file.
- **The spine — sovereign.** Model routing and mid-session switching
  (hoosh), agent orchestration + MCP tool execution + the host registry
  (daimon), the MCP protocol (bote), per-tool authorization (t-ron), and
  the Thoth/Librarian archetype overlay (avatara). thoth owns **no**
  domain logic of its own; it consumes this spine and never reimplements
  any part of it.

The bright line: **port the floor; never fork the spine.** thoth may
abstract the OS beneath it, but it must never re-create above it anything
AGNOS already owns. AGNOS is the primary, fully-realized home (native,
co-resident, sandboxed end to end); other operating systems run the
**same** spine reached as a client over a portable transport,
capability-gated. The posture: **everywhere capable, AGNOS canonical** —
portability owns the floor (it always runs), AGNOS owns the ceiling (it
runs best), and the gap between them is an explicit, documented contract.

See [ADR-0001](../adr/0001-os-agnostic-agnos-primary.md) for the full reasoning, [ADR-0002](../adr/0002-consume-the-agnos-stack.md) for the consume-the-stack mandate, and [architecture note 001](../architecture/001-consumer-only-no-domain-logic.md) for the invariant.

## v1.0 criteria

_Provisional — to be ratified as the design settles. v1.0 is an **AGNOS
gate**: the downstream-green criterion is satisfied on AGNOS, where the
whole spine is native._

- [ ] Core driver loop (read → plan → edit → run → iterate) usable on
      AGNOS and at least one off-AGNOS target
- [ ] Mid-session model switch routes turns through hoosh
- [ ] MCP tool execution via daimon + bote, gated by t-ron on AGNOS
- [ ] Off-AGNOS security **fails closed** — absent t-ron degrades to a
      conservative built-in deny/prompt, never silent allow; absence is
      announced, never faked
- [ ] avatara Thoth/Librarian archetype overlay applied
- [ ] Capability ladder documented and honest (per dependency:
      native vs. remote-client vs. absent; full / degraded / absent
      semantics)
- [ ] At least one downstream consumer green **on AGNOS**
- [ ] CHANGELOG complete from the first real release onward
- [ ] Security review pass
- [ ] First real release tagged under **CalVer (`YYYY.M.D`)** — see
      Versioning below

## Versioning

thoth is a **consumer app / binary**, so per the first-party standards it
uses **CalVer (`YYYY.M.D[-N]`)** at its first real release. The current
`VERSION` (SemVer `0.1.0`) is a fermenting placeholder and stays
**untouched** until thoth leaves the fermenting stage — do not force the
switch now. The CalVer cutover happens at the first tagged release, not
before.

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-06-08

- `cyrius init` scaffold landed
- Doc-tree per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/first-party/first-party-documentation.md)
- ADRs / architecture notes / guides / examples folders ready

### M1 — Identity & posture fixed (fermenting) — ✅ 2026-06-08

Lock the standards/identity shape before any code can entrench the wrong
one. No feature code — docs and manifest hygiene only.

- ✅ Identity ADR ([0001](../adr/0001-os-agnostic-agnos-primary.md)):
  OS-agnostic substrate + AGNOS-sovereign spine, with the bright line
  "port the floor, never fork the spine"; plus
  [0002](../adr/0002-consume-the-agnos-stack.md) (consume the stack) and
  [0003](../adr/0003-wear-the-avatara-thoth-archetype.md) (wear the
  avatara archetype)
- ✅ Architecture note
  [001](../architecture/001-consumer-only-no-domain-logic.md) recording
  the invariants: thoth holds no domain logic; portability comes from
  capability-seam fallbacks, never in-tree reimplementation; security
  degrades **closed**
- ✅ CLAUDE.md, `cyrius.cyml`, README aligned to the canonical framing and
  the first-party/ standards path
- ✅ Intended spine deps (hoosh / daimon / bote / t-ron / avatara)
  described in **prose only** here and in `state.md`; `cyrius.cyml` keeps
  **stdlib deps only** while fermenting

### M2 — REPL/TUI driver core (provisional)

The platform-neutral skeleton: read a task, plan, present a turn loop,
edit files, run tools, iterate. No spine bindings yet — a local,
self-contained loop that proves the driver shape.

- Interactive REPL/TUI over the portable terminal-I/O interface (no
  per-OS terminal code)
- Driver loop: read → plan → edit → run → iterate
- Capability-seam scaffolding (thin seams where the spine will bind),
  with every seam reporting **absent** honestly for now

### M3 — hoosh inference + mid-session model switch (provisional)

The signature feature. Route a turn to a backing model; switch the
backing model mid-session. Routing is OS-independent by construction.

- Turn inference routed through hoosh
- Mid-session model / tier / provider switch
- AGNOS: hoosh reached natively/co-resident. Off-AGNOS: hoosh reached as
  a remote/networked gateway over the same contract, capability-gated;
  unreachable host degrades the feature **honestly and announced**

### M4 — MCP tool execution: daimon + bote + t-ron (provisional)

Give the agent real hands — tool execution under authorization. This is
the security-critical seam.

- Tool execution via daimon (orchestration + MCP tool host + host
  registry) speaking bote (the MCP protocol)
- **t-ron** wraps the very file-edits and shell commands the agent runs
- **Fail-closed** off AGNOS: absent t-ron ⇒ conservative built-in
  deny/prompt around file-edit and shell-exec; never silent allow; absence
  surfaced to the user

### M5 — avatara personality overlay (provisional)

Pull the Thoth / scribe / Librarian persona straight from avatara — the
on-the-nose case where name = archetype = function align.

- Thoth/Librarian archetype overlay applied from avatara on AGNOS
- Off-AGNOS: overlay reduced to a static bundled persona descriptor over
  the same contract (a descriptor, **not** a reimplementation of avatara)

### M6 — OS-agnostic build targets + capability ladder (provisional)

Ratify the reach posture and make degradation explicit.

- Build thoth for AGNOS (primary), Linux, macOS, Windows via the
  per-target Cyrius stdlib behind the one portable interface
- Capability-ladder / feature-gate matrix: per dependency, native vs.
  remote-client vs. absent, with **full / degraded / absent** semantics
  defined and kept honest so it can't drift and mislead
- Confirm: identical agent UX everywhere; AGNOS is the only parity promise

### M7 — Release readiness (provisional)

- Satisfy the v1.0 criteria above (AGNOS downstream-green gate)
- Security review pass
- CalVer cutover at the first real tag

## Out of scope (for v1.0)

The deliberate non-goals — these keep future contributors from forking
the spine or diluting the identity by accident.

- **Any OS-specific reimplementation, bundling, or substitute** for a
  domain AGNOS already owns — inference (hoosh), MCP protocol (bote), MCP
  security (t-ron), orchestration / tool host (daimon), or archetype
  (avatara). No "offline" / "embedded" forks that dodge the spine.
- **A bundled local inference path** to escape hoosh, a **hand-rolled MCP
  client** to escape bote, or an **ad-hoc auth shim** to escape t-ron.
  These are the precise failure modes the identity ADR exists to prevent.
- **A swappable-backend abstraction** that lets the spine be replaced with
  arbitrary alternative implementations — the capability seam binds to the
  **same contract** (native vs. reached-as-client), not to competing
  backends. thoth drives the AGNOS spine; it does not abstract it away.
- **Off-AGNOS feature parity.** Parity is an AGNOS-only promise;
  elsewhere thoth runs a faithful, capability-gated baseline.
- **Silent degradation** of any capability, especially security. Missing
  capabilities fail closed and are announced — never faked.
- **A separate per-OS agent UX or "AGNOS edition" fork.** One driver, one
  UX, many substrates.
- **Declaring the spine crates as real `cyrius.cyml` deps** while
  fermenting. Future git-deps (hoosh / daimon / bote / t-ron / avatara,
  each with a tag + explicit `modules = [...]` list) are deferred until
  thoth leaves the fermenting stage; the **off-AGNOS reach transport** is
  deferred to a later ADR once that work is real.
