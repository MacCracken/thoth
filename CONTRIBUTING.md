# Contributing to thoth

thoth is an AGNOS first-party project. It follows the
[First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/first-party/first-party-standards.md)
and [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/first-party/first-party-documentation.md)
standards. Read the genesis repo's
[`CLAUDE.md`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
and this repo's [`CLAUDE.md`](CLAUDE.md) before starting.

> **Status: 0.43.4 — built and shipping (pre-1.0).** thoth has a real interactive TUI (rich by
> default) / REPL, a native Wayland GUI (`thoth gui`), and a one-shot/argv front-door with
> `--json` / `--events`; the full AGNOS spine wired; mid-session model / persona / role
> switching; jailed project read tools + `@file` mentions and the gated `edit` / `create_file` /
> `shell` write tools with `/rewind` checkpoints; a git producer, project memory (mneme via
> daimon), `web_fetch`/`web_search`, MCP resources/prompts, subagent delegation, and the
> operator-side controls — `[hooks]`, `[toolpin]`, `[guard]`, `[redact]`, `[verify]` — plus a
> comprehensive unit suite; x86_64 Linux ships (see `docs/development/state.md` for the full
> target status). The remaining road to v1.0 is dominated by AGNOS lighting up, not feature work — see
> [`docs/development/roadmap.md`](docs/development/roadmap.md) and
> [`docs/development/state.md`](docs/development/state.md). Contributions follow the one rule
> below: drive the AGNOS spine, never fork it.

## Build and test

```sh
cyrius deps                              # resolve stdlib deps
cyrius build src/main.cyr build/thoth    # compile
cyrius test                              # run [build].test + tests/*.tcyr
```

The toolchain version is pinned in `cyrius.cyml` (`[package].cyrius`) — that pin
is the single source of truth. Do not hardcode it anywhere else.

## The one rule that defines thoth

**Port the floor; never fork the spine.** thoth is a driver that owns **no**
domain logic of its own. Inference, the MCP protocol, MCP security,
orchestration, and personality each live in exactly one AGNOS crate
(hoosh / bote / t-ron / daimon / avatara) and thoth **consumes** them. Do not
add — or vendor, or reimplement — any of those domains in this repo. For every
change, ask: *is this substrate (portable, OS-level) or capability (bind to the
spine)?* See [ADR-0001](docs/adr/0001-os-agnostic-agnos-primary.md),
[ADR-0002](docs/adr/0002-consume-the-agnos-stack.md), and
[architecture note 001](docs/architecture/001-consumer-only-no-domain-logic.md).

## Where things go

- **Why we chose X over Y** → a new ADR in [`docs/adr/`](docs/adr/) using
  [`template.md`](docs/adr/template.md). Zero-padded 4 digits, never renumber,
  index it in the ADR README.
- **A non-obvious invariant about the code** → a numbered note in
  [`docs/architecture/`](docs/architecture/) (3 digits, never renumber, indexed).
- **How to do a task** → [`docs/guides/`](docs/guides/).
- **Volatile status** (version, deps, surface) → `docs/development/state.md`.
- **Sequencing** → `docs/development/roadmap.md`.
- **What changed in a version** → [`CHANGELOG.md`](CHANGELOG.md)
  ([Keep a Changelog](https://keepachangelog.com/) format).

## Conventions

- One change at a time — never bundle unrelated changes.
- Test after every change, not after the feature is "done".
- Validate all external data (file / network / args); bound every buffer
  (`var buf[N]` = N **bytes**); never `sys_system()` with unsanitized input.
- Do not modify `lib/` (vendored stdlib / dep symlinks).
- Maintainers handle all git operations and releases.

## Reporting security issues

Do **not** open a public issue for a vulnerability. See [`SECURITY.md`](SECURITY.md).
