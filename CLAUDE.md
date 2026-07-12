# thoth — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported targets, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**thoth** — a sovereign agentic coding TUI. Named for the Egyptian **Thoth**,
god of writing, scribes, and wisdom; the user-given backronym reads
**T**hinks, **H**andles, **O**rchestrates, **T**ransforms, **H**eals (code).
An interactive REPL/TUI driver that reads a task, plans, edits files, runs
tools, and iterates — with the signature ability to switch the backing model
mid-session.

- **Type**: Binary (agentic coding TUI / driver)
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: <https://github.com/MacCracken/agnosticos> — read its `CLAUDE.md` first
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/first-party/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/first-party/first-party-documentation.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

thoth owns the **user-facing agentic-coding front-end / driver** for the
end-user dev workflow on AGNOS. It owns **no domain logic of its own** — it
drives the AGNOS capability spine by consuming it: **hoosh** (LLM inference,
model routing, mid-session switching), **daimon** (agent orchestration, MCP
tool execution, host registry), **bote** (the MCP protocol), **t-ron**
(per-tool MCP authorization), and **avatara** (the Thoth/Librarian archetype
overlay). thoth is OS-agnostic in its reach and AGNOS-sovereign in its spine:
the substrate beneath it (syscalls, allocation, argv, process spawn, terminal
I/O) may be abstracted across operating systems, but the capability spine above
it is single-sourced and consumed, never reimplemented or per-OS-forked. AGNOS
is the primary, fully-realized home — everywhere capable, AGNOS canonical:
**port the floor; never fork the spine.**

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, surface area, in-flight work, consumers, dep gaps.
> Refreshed every release. See also [`CHANGELOG.md`](CHANGELOG.md).

This file (`CLAUDE.md`) is durable rules.

## Quick Start

```sh
cyrius deps                          # resolve stdlib deps
cyrius build src/main.cyr build/thoth
cyrius test                          # run [build].test + tests/*.tcyr
```

## Key Principles

- **Read the genesis `CLAUDE.md` first** — the AGNOS genesis repo governs every first-party project
- **Own the stack** — consume hoosh / daimon / bote / t-ron / avatara; never reimplement LLM inference, MCP protocol, MCP security, orchestration, or personality logic
- **OS-agnostic, AGNOS-primary** — write against the portable substrate interface and pick the target at build time; never write against a per-OS file. The capability spine is reached natively on AGNOS and as a client elsewhere — the same contract, capability-gated. Security degrades **closed** (absent t-ron means a conservative deny/prompt, never silent allow) and missing capabilities are announced, never faked
- **Correctness over cleverness** — if it's wrong, the bugs own you
- Test after every change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya / existing patterns
- Build with `cyrius build`, not raw `cat file | cc5` — the manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes**, not N entries
- `&&` / `||` short-circuit; mixed expressions require explicit parens

## Rules (Hard Constraints)

- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API if needed
- **Never fork the spine** — no OS-specific reimplementation, bundling, or substitute for a domain AGNOS already owns (inference, MCP protocol, MCP security, orchestration, archetype)
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection
- Do not trust external data (file / network / args) without validation
- Do not modify `lib/` files (vendored stdlib / dep symlinks)
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Process

1. **Work phase** — features, roadmap items, bug fixes
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases; for every new feature, ask "is this substrate or capability?" — substrate ports, capability binds to the spine
5. **Documentation** — update CHANGELOG, `docs/development/state.md`, any ADR the change earned
6. **Version sync** — edit `VERSION` (the single source of truth), run `scripts/gen-version.sh` to regenerate `src/version.cyr` (`thoth_version()`; `scripts/build.sh` also does this before each build), bump the CHANGELOG header. `cyrius.cyml` already reads `VERSION` via `${file:VERSION}`; never inline the version in `.cyr` source — read `thoth_version()`.

## Scaffolding

Project was scaffolded with `cyrius init`. **Do not manually create project structure** — use the tools. If a tool is missing something, fix the tool.

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious invariants (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0 (forward-facing only)
- [`docs/doc-health.md`](docs/doc-health.md) — Doc-currency ledger (fresh/durable/stale, refreshed on doc sweeps)
