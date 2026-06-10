# thoth

A sovereign agentic coding TUI — written in [Cyrius](https://github.com/MacCracken/cyrius).

thoth is the user-facing front-end for the end-user dev workflow on AGNOS: an
interactive REPL/TUI driver that reads a task, plans, edits files, runs tools,
and iterates. Its signature move is being a **model-switching scribe** — it can
switch the backing model mid-session, routing a turn to a different LLM, tier,
or provider when that serves the work.

> **Status: 0.2.0 — the hoosh seam (pre-1.0).** The interactive REPL/TUI loop is
> real and usable, and the signature feature is wired: thoth routes a turn to a
> backing model and switches the model mid-session through **hoosh**, reached as
> an OpenAI-compatible HTTP gateway (transported by sandhi, configured via
> `thoth.cyml`). The rest of the spine (daimon/bote/t-ron/avatara) is still
> **absent** and degrades honestly (`/seams` shows the ladder). SemVer `0.x`
> while the surface moves. See
> [`docs/development/state.md`](docs/development/state.md) and
> [`docs/development/roadmap.md`](docs/development/roadmap.md) for the live
> picture.

## What thoth is

thoth is a **driver**, not a domain. It owns no inference, no protocol, no
security policy, no personality of its own — it drives the AGNOS capability
spine and wraps it in an interactive coding-agent experience. The name is from
the Egyptian Thoth, god of writing, scribes, and wisdom.

Backronym: **T**hinks, **H**andles, **O**rchestrates, **T**ransforms, **H**eals
(code).

## Why use it

- **A model-switching scribe** — route the current turn to a different model,
  tier, or provider mid-session, without leaving the loop.
- **A front-end that owns nothing it shouldn't** — every heavy domain lives in
  a dedicated AGNOS crate that thoth consumes, so there's one implementation of
  each, not a fork buried in a TUI.
- **Everywhere capable, AGNOS canonical** — runs across operating systems,
  first-class on AGNOS (see the stance below).

## Place in the AGNOS stack

thoth is the user-facing coding-agent driver. It owns no domain logic of its
own; it **consumes** the AGNOS spine and is distinct from each part as the
thing that drives them:

| Dependency | Domain it owns |
| ---------- | -------------- |
| **hoosh**  | LLM inference gateway — model routing and mid-session switching |
| **daimon** | agent orchestration, MCP tool execution, host registry |
| **bote**   | the MCP protocol |
| **t-ron**  | MCP per-tool authorization |
| **avatara**| personality / archetype overlay (the Thoth / Librarian persona) |

When AGNOS owns a domain, thoth depends on it and never reimplements it. The
"Thoth" archetype pulled from avatara is the personality overlay for
thoth-the-tool — name, archetype, and function aligned on purpose.

**hoosh is wired** as of 0.2.0 — consumed as a running HTTP gateway (it ships no
linkable crate), reached over the stdlib `sandhi` transport. The remaining four
(daimon/bote/t-ron/avatara) are **described here as intent, not yet declared**,
and land in later milestones. When AGNOS owns a domain, thoth consumes it and
never reimplements it.

## OS-agnostic in reach, AGNOS-sovereign in spine

thoth is OS-agnostic at the substrate layer and AGNOS-sovereign at the
capability layer — the two never collide because they govern different layers.

- **The floor is portable.** Below thoth sit syscalls, allocation, argv,
  process spawn, and terminal I/O. The Cyrius toolchain already fans this out
  across one shared codebase to multiple targets behind one stable interface,
  so cross-OS reach is a posture thoth ratifies, not infrastructure it invents.
- **The spine is sovereign.** Above thoth sits the capability spine
  (hoosh/daimon/bote/t-ron/avatara). thoth owns its place in the stack
  precisely **by consuming** that spine rather than reimplementing any part of
  it.

**AGNOS is the primary, fully-realized home** — not because other operating
systems are second-class by neglect, but because on AGNOS the whole spine is
native, co-resident, and sandboxed end to end. Off AGNOS, thoth runs the *same*
sovereign spine reached as a client over a portable transport, capability-gated:
where an AGNOS service is unreachable, the matching feature degrades honestly,
announced to the user, never faked and never re-implemented. Security in
particular degrades **closed** — an absent t-ron means a conservative built-in
deny/prompt, never a silent allow.

The bright line: **port the floor; never fork the spine.** See
[`docs/adr/`](docs/adr/) for the decision that fixes this posture.

## Build / Quick Start

```sh
cyrius deps                              # resolve stdlib deps
cyrius build src/main.cyr build/thoth    # compile
cyrius test                              # run [build].test + tests/*.tcyr
```

The toolchain version is pinned in `cyrius.cyml` (`[package].cyrius`) — that
pin is the source of truth; don't hardcode it elsewhere.

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants about the code
- [`docs/guides/`](docs/guides/) — task-oriented how-tos
- [`docs/examples/`](docs/examples/) — runnable examples
- [`docs/development/state.md`](docs/development/state.md) — live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestones through v1.0

## License

GPL-3.0-only.
