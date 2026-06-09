# 0002 — Consume the AGNOS stack, do not reimplement

**Status**: Accepted
**Date**: 2026-06-08

## Context

thoth is a sovereign agentic coding TUI written in Cyrius: an interactive REPL/TUI driver that reads a task, plans, edits files, runs tools, and iterates, with the signature ability to switch the backing model mid-session. It is the user-facing front-end/driver for the end-user dev workflow on AGNOS, and it owns NO domain logic of its own.

The capability spine thoth needs is already owned by sibling crates in the AGNOS stack:

- **hoosh** — LLM inference gateway: model routing and mid-session switching.
- **daimon** — agent orchestration, MCP tool execution, and the host registry.
- **bote** — the MCP protocol.
- **t-ron** — MCP per-tool authorization (the security gate around tool calls).
- **avatara** — personality / archetype overlay, including the Thoth / Librarian persona thoth wears.

The AGNOS first-party standards make "own the stack" a core principle: when AGNOS has a crate for a domain, depend on it and never reimplement. For thoth that mapping is direct — LLM inference -> hoosh, MCP protocol -> bote, MCP security -> t-ron, archetype overlay -> avatara, orchestration / tool-host -> daimon. These are Cyrius libraries and protocol clients that thoth links or speaks to; none of them is an OS facility, so none has a per-OS version to diverge.

This is a real decision rather than a default because the alternatives are tempting. A coding agent lives or dies by adoption, and the easy path off AGNOS — or even on it — is to vendor a provider's inference SDK, hand-roll an MCP client, or bundle an ad-hoc authorization shim so the tool "just works" without reaching a sibling host. Each such shortcut would quietly fork a domain AGNOS already owns, turn a driver that should own nothing into a sprawling multi-domain codebase, and — most sharply for t-ron — leave an agent that edits files and runs shell commands without its native authorization sandbox.

thoth is long-horizon and FERMENTING: scaffolded via `cyrius init`, VERSION 0.1.0, no feature code yet, and `cyrius.cyml` carries stdlib deps only. This ADR fixes the dependency posture now, before any code can entrench the wrong shape. It is identity, not implementation.

## Decision

thoth depends on the AGNOS sibling crates for every domain it touches — hoosh for LLM inference and mid-session model switching, daimon for agent orchestration and MCP tool execution and the host registry, bote for the MCP protocol, t-ron for per-tool authorization, and avatara for the personality / archetype overlay — and builds NONE of that logic itself, per the standards "own the stack" principle.

In scope:

- thoth is a pure front-end / driver. Its own code is the driver loop (read / plan / edit / run / iterate), the REPL/TUI, and the seams that reach the spine. The signature mid-session model switch is a routing concern handed to hoosh, not an inference path thoth owns.
- Each AGNOS-owned domain is reached through a thin capability seam that binds to the sibling crate's contract — never to a competing in-tree implementation of that domain.
- t-ron remains the authorization gate around every tool call (file edits and shell commands included); thoth does not roll its own security around the actions the agent performs.
- The Thoth / Librarian persona is pulled from avatara as the personality overlay, not encoded as a thoth-local archetype. (That the program's name, the archetype, and the function all coincide is the on-the-nose design here, not a name collision.)

Out of scope:

- Any in-tree reimplementation, vendoring, or substitute for a domain AGNOS already owns — inference, MCP protocol, MCP security, orchestration, or archetype — including "offline" or "embedded" forks that dodge a sibling crate.
- Declaring those crates as real `cyrius.cyml` dependencies now. Because thoth is fermenting, the manifest keeps stdlib deps only; the intended sibling deps are described in prose in `docs/development/state.md` and `docs/development/roadmap.md`, and are added later — each with a tag and an explicit `modules` list — once design begins.
- The mechanics of reaching these crates off AGNOS (locality, transport, capability-gating). That is governed by ADR-0001 (OS-agnostic substrate, AGNOS-sovereign spine) and deferred in its specifics to a later ADR.

## Consequences

**Positive**

- **Sovereignty by construction** — the spine is single-sourced. Bug fixes, the security posture, and the mid-session model switch behave identically wherever thoth runs, because there is no second implementation to drift. Own-the-stack is upheld structurally, not by discipline alone.
- **No duplication** — thoth stays a small driver. Inference, protocol, orchestration, security, and personality each live in exactly one place — their owning crate — so thoth never carries, tests, or re-verifies that domain logic.
- **Security through t-ron** — per-tool authorization wraps the agent's file edits and shell commands at the source, in the crate that owns that domain, rather than in a hand-rolled shim thoth would have to keep correct on its own.

**Negative**

- **Coupling to sibling release cadence** — thoth's capabilities track hoosh / daimon / bote / t-ron / avatara. A change or regression in a sibling crate is felt in thoth, and thoth must move with their tags rather than independently.
- **Off-AGNOS hosts must run or reach these crates in user space** — where the spine is not native and co-resident, thoth is only as capable as its ability to reach it. thoth deliberately forgoes the escape hatch of a bundled local fallback, accepting a hard dependency on reaching sovereign services rather than reimplementing them.

**Neutral / follow-on**

- An architecture note (`docs/architecture/`) should record the invariant that thoth holds no domain logic and that every capability is reached through a seam to its owning crate, never reimplemented in-tree.
- Future `cyrius.cyml` git-deps for hoosh / daimon / bote / t-ron / avatara — each with a tag and explicit `modules` list — are deferred until thoth leaves the fermenting stage; until then they live as prose in state and roadmap.

## Alternatives considered

**Vendor provider SDKs / inference paths directly** — pull a provider's client library into thoth and call models from inside the driver. Rejected: this reimplements the domain hoosh owns, bypasses mid-session routing as a first-class concern, and turns a front-end that should own nothing into the owner of inference logic, credentials, and provider quirks — a direct violation of own-the-stack. hoosh exists precisely so thoth does not carry this.

**Reimplement (or hand-roll a client for) the MCP protocol** — build an in-tree MCP client instead of speaking through bote. Rejected: it duplicates a protocol AGNOS already owns, creates a second implementation to drift from the canonical one, and — paired with the temptation to bolt on an ad-hoc auth shim — re-rolls the security-critical surface that belongs to t-ron, around the very file-edit and shell-exec actions an agent performs. bote owns the protocol and t-ron owns the gate; thoth speaks to both.

**A thoth-owned abstraction layer over the capabilities** — a generic interface that could swap hoosh / daimon / bote / t-ron / avatara for arbitrary alternative backends. Rejected: it reintroduces domain logic and policy into a driver that is supposed to own none, invites competing implementations behind the seam, and weakens the consume-don't-reimplement mandate. The capability seam in this decision is deliberately thinner — it binds to the SAME contract of the owning crate, not to swappable competing backends. thoth's job is to DRIVE the AGNOS spine, not to abstract it away.
