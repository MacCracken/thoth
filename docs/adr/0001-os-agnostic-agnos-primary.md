# 0001 — OS-agnostic reach, AGNOS-primary home

**Status**: Accepted
**Date**: 2026-06-08

## Context

thoth is a sovereign agentic coding TUI written in Cyrius: an interactive REPL/TUI driver that reads a task, plans, edits files, runs tools, and iterates, with the signature ability to switch the backing model mid-session. It is the user-facing front-end/driver for the end-user dev workflow on AGNOS and owns NO domain logic of its own — it consumes hoosh (LLM inference + mid-session routing), daimon (agent orchestration + MCP tool execution + host registry), bote (the MCP protocol), t-ron (MCP per-tool authorization), and avatara (the Thoth/Librarian archetype overlay), and is distinct from each as the thing that drives them.

The project sets two goals that appear to pull against each other. First, the AGNOS first-party standards make "own the stack" a core principle: when AGNOS has a crate for a domain, depend on it and never reimplement — which for thoth means consuming hoosh/daimon/bote/t-ron/avatara rather than building inference, orchestration, protocol, security, or personality of its own. Second, the project's stated design goal (set 2026-06-08) is to be OS-agnostic with AGNOS as the primary home: thoth should run across operating systems but be first-class and fully-realized on AGNOS. A coding agent lives or dies by adoption, and developers work on heterogeneous machines (Linux, macOS, Windows) as well as AGNOS, so reach is a first-order UX concern — a tool the dev cannot launch is a tool the dev cannot adopt.

Two project facts make this a real decision rather than a default. (a) The vendored Cyrius stdlib already carries cross-OS substrate — syscalls_x86_64_agnos, syscalls_x86_64_linux, syscalls_aarch64_linux, syscalls_macos, syscalls_windows, plus alloc_/args_/process_ variants for agnos/macos/windows — all behind one stable interface, so portability is structurally cheap and tempting at the substrate level, and we will inherit one posture whether we choose it or not. (b) The capability spine thoth must own is itself AGNOS-native, so naive portability would pressure contributors to reimplement or bundle OS-specific substitutes for hoosh/daimon/bote/t-ron/avatara on platforms where those hosts are less convenient to reach — silently forking AGNOS's ownership of those domains, and (most sharply for t-ron) leaving an agent that edits files and runs shell commands without its native authorization sandbox.

thoth is long-horizon and FERMENTING: scaffolded via cyrius init, VERSION 0.1.0, no feature code yet, no real deps declared (cyrius.cyml carries stdlib only). This ADR fixes IDENTITY and POSTURE now — which way thoth leans on the portability-vs-sovereignty axis and how the two are kept from colliding — before any code can entrench the wrong shape. It is not implementation.

## Decision

thoth is OS-agnostic at the substrate layer and AGNOS-sovereign at the capability layer: the identical agent UX runs as a portable baseline on every supported OS, while the hoosh/daimon/bote/t-ron/avatara spine is single-sourced and consumed (never reimplemented or per-OS-forked), with AGNOS as the primary, fully-realized home and other operating systems as capability-gated reach targets that run the same spine as clients.

In scope:

1. the core driver loop (read/plan/edit/run/iterate) and mid-session model switching are platform-neutral and ship on every supported OS — the signature switch is a routing concern, OS-independent by construction;
2. compiling thoth for AGNOS (primary), Linux, macOS, and Windows via the per-target Cyrius stdlib behind one portable interface, with all thoth code written against that portable interface rather than per-OS files;
3. each AGNOS-owned domain (hoosh/daimon/bote/t-ron/avatara) is reached through a thin capability seam with two binding modes — AGNOS-native (canonical, co-resident, sandboxed) and portable-fallback (the same contract reached as a client, degraded). This ADR governs *where the seam binds*; the consume-not-reimplement mandate the seam enforces is ADR-0002;
4. capability-gating with a documented ladder declaring, per dependency, what "full" vs "degraded" vs "absent" means;
5. security degradation FAILS CLOSED — absent t-ron means a conservative built-in deny/prompt policy, never silent allow — and absence of any capability is announced to the user, never faked.

Out of scope: any OS-specific reimplementation, bundling, or substitute for a domain AGNOS already owns (inference, MCP protocol, MCP security, orchestration, archetype) — including "offline" or "embedded" forks that dodge hoosh/daimon/bote/t-ron/avatara; a divergent per-OS agent UX or a separate "AGNOS edition" fork; any guarantee that off-AGNOS reaches feature parity (parity is explicitly an AGNOS-only promise); committing to specific off-AGNOS provider implementations now; and — because thoth is fermenting — declaring those crates as real cyrius.cyml deps (they stay prose in state/roadmap; the manifest keeps stdlib deps only). The off-AGNOS reach transport is deferred to a later ADR once that work is real.

The bright-line invariant: portability may swap what is BENEATH thoth (the syscall/host substrate) but may never fork what is ABOVE thoth (the hoosh/daimon/bote/t-ron/avatara spine). Port the floor; never fork the spine.

## Consequences

### Positive

- One codebase, one capability spine — the sovereign stack (hoosh/daimon/bote/t-ron/avatara) is single-sourced, so bug fixes, security posture, and the signature mid-session model switch behave identically on every target and never need per-OS re-verification of the spine. Own-the-stack is upheld by construction: there is no second implementation to drift.
- Maximum adoption surface — the model-switching scribe meets developers on the OS they already run, the strongest wedge for a user-facing coding agent and the natural downstream pull toward AGNOS.
- AGNOS gets to be genuinely first-class — native co-location of the host registry, security domain, and archetype, plus the t-ron sandbox around file-edits and shell-exec — without that being an accident of neglect elsewhere. "Full" exists only where every seam is native, giving a concrete, honest reason to prefer AGNOS rather than a marketing claim.
- Portability is cheap: the substrate fan-out (syscalls/alloc/args/process per OS) already exists in the vendored Cyrius stdlib and is now put to deliberate use rather than carried as dead weight.

### Negative

- Off-AGNOS, thoth is only as capable as its ability to REACH the spine — network, latency, or unavailable hosts can degrade or block features (mid-session switch, tool execution) that are seamless on AGNOS; thoth deliberately forgoes the easy escape hatch of a bundled local fallback, accepting a hard dependency on reaching sovereign services.
- Off-AGNOS security is genuinely weaker — fail-closed deny/prompt instead of t-ron's real per-tool authorization — and running an agent's file-edit and shell-exec actions without a native t-ron sandbox is a real security surface we now own and must gate and communicate, or users will assume AGNOS-grade safety they don't have.
- Every AGNOS-owned dependency now needs a portable-fallback path defined and maintained (roughly doubling the integration surface per seam), and the portable substrate interface becomes a contract thoth must hold itself to — resisting both the temptation to call a per-OS file directly and the temptation to reimplement an owned domain "just a little" to smooth a fallback. This must be policed in review; every new feature carries the recurring question "is this substrate or capability?"

### Neutral

- An architecture note (docs/architecture/) should record the invariants: thoth holds no domain logic; portability comes from seam fallbacks, never in-tree reimplementation; security degrades CLOSED; and the bright line "port the floor, never fork the spine."
- A capability-ladder/feature-gate matrix (per dependency: native vs remote vs absent; full / degraded / absent semantics) is now a maintenance obligation — described in prose in state/roadmap while fermenting, built once design begins, kept honest so it doesn't drift and mislead.
- roadmap.md should record that the v1.0 downstream-green gate is an AGNOS gate and that CalVer applies at first real release; the SemVer 0.1.0 in VERSION stays untouched during fermentation.
- Future cyrius.cyml git-deps (hoosh/daimon/bote/t-ron/avatara, each with tag + explicit modules list) are deferred until thoth leaves the fermenting stage, and a later ADR will define the off-AGNOS reach transport.

## Alternatives considered

**AGNOS-only (no portability)** — bind directly to native AGNOS internals; ship nowhere else. The simplest sovereignty story, since the spine is always native, co-resident, and sandboxed. Rejected: it forfeits the explicit 2026-06-08 design goal of OS-agnostic reach and strangles adoption at birth — a coding agent that cannot run on the developer's current laptop will never get the chance to pull them toward AGNOS — while discarding the multi-OS substrate already free in the vendored Cyrius stdlib. The cost of portability is low; the cost of forgoing it is high.

**Portability via reimplementation** (bundle or reimplement inference/MCP/security/archetype where the AGNOS hosts are inconvenient) — maximizes off-AGNOS autonomy and offline capability. Rejected: this is the precise failure mode this ADR exists to prevent. It directly violates own-the-stack by creating second, divergent implementations of domains AGNOS owns, turns a driver that should own NOTHING into a sprawling multi-domain codebase, multiplies the security-critical surface (a non-t-ron auth path re-rolling sandboxing around file-edits and shell-exec), and makes "thoth" mean different things on different operating systems.

**Full OS-parity-as-equal-peers** (no primary home; identical capability everywhere) — clean and even-handed. Rejected: it either drags AGNOS down to a lowest-common-denominator reachable everywhere (wasting native hoosh/daimon/bote/t-ron/avatara and the t-ron sandbox) or forces reimplementation off-AGNOS to reach parity (the rejected option above). It also dilutes the AGNOS-first identity, which is an identity commitment, not a deployment convenience — the capability-ladder/graceful-degradation model gets the same reach without throwing away the ceiling.

**Abstraction-layer-over-the-capabilities** (a thoth-owned interface that could swap hoosh/daimon/bote/t-ron/avatara for arbitrary alternative backends) — superficially flexible. Rejected: it reintroduces domain logic and policy into a front-end that is supposed to own none, invites alternative implementations behind the seam, and weakens the consume-don't-reimplement mandate. The capability seam in this decision is deliberately thinner: it binds to the SAME contract (native vs. reached-as-client), not to swappable competing backends. thoth's job is to DRIVE the AGNOS spine, not to abstract it away.

**Silent degradation** (fall back off-AGNOS without telling the user, especially on security) — rejected on safety grounds: an absent t-ron silently allowing tool calls would be a sovereignty and security regression masquerading as portability. Fail-closed-and-announce is a mandatory term of the decision, not an option.
