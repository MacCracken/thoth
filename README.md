# thoth

A sovereign agentic coding TUI — written in [Cyrius](https://github.com/MacCracken/cyrius).

thoth is the user-facing front-end for the end-user dev workflow on AGNOS: an
interactive REPL/TUI driver that reads a task, plans, edits files, runs tools,
and iterates. Its signature move is being a **model-switching scribe** — it can
switch the backing model mid-session, routing a turn to a different LLM, tier,
or provider when that serves the work.

**scribe additions with agnosai** 

SCRIBE = Self-Correcting Reasoning Intelligence with Bounded Execution

> **Status: 0.38.6 (pre-1.0).** The full AGNOS spine is wired, the agentic loop closes, and thoth reads *and
> writes* code. Real and usable daily; SemVer `0.x` while the surface still moves.

**The loop.** A free-text turn drives a **model-driven agentic loop**: thoth advertises **daimon**'s MCP tools to
**hoosh**, the backing model calls them, thoth executes each through daimon (speaking **bote**, the vendored MCP
protocol) under **t-ron** authorization — deny is final, and no policy means a fail-closed confirm — looping results
back until the model answers. Streaming (SSE), with parallel tool calls.

**The signature move.** Switch the backing model mid-session through hoosh (`/model`, `/models`, or the Ctrl-P
picker). The **persona** is sourced from **avatara** and switches mid-session too (`/persona`), with a
trait-derived **role** axis (`/role`).

**Three surfaces, one view-model** — each degrading **closed**:

- **Rich TUI** (the default on a capable terminal; `--tier=simple|rich|auto`) — amber palette, syntax-highlighted
  diffs + fenced code, structural markdown incl. **tables**, a soft-wrapping feed, a word-wrapping composer, a
  file-tree pane (Ctrl-B), feed search (Ctrl-F), themes (`/theme dark|light|rainbow`), a reasoning-effort control
  + persistent per-turn thinking fold, and a live spine-health + token/cost + git-branch status bar.
- **Native desktop GUI** (`thoth gui`) — thoth's OWN sovereign Cyrius Wayland window (draw-command IR → kashi CPU
  rasterizer → wl_shm → a puka-forked present shell; live-confirmed on a real compositor): the same status strip,
  structural-markdown replies, per-turn tool-call + colored diff cards, and a conversation sidebar (Ctrl+K).
- **Shell citizen** — a one-shot/argv front door (`thoth 'task'`, `git diff | thoth 'review'`), `--json` for jq/CI,
  `-o`/`--out` tee, completion (`--completion bash|zsh`), `[alias]` macros, `/dry` request preview — on a
  byte-identical plain line-mode floor when piped/CI.

**Reads and writes the project it's launched in.** Default-on jailed `read_file`/`list_dir` + `@file` mentions
(`/allow` widens the jail); **opt-in** jailed `edit` / `create_file` / `shell` tools (each t-ron-gated, off by
default) so the model can change code, not just read it; a git producer (`/git`); `web_fetch` / `web_search` via
daimon + bote.

**Keeps the thread.** Named **multi-conversation management** (`/new`, `/switch`, `/rename`, `/delete`, `/search`),
persisted across restarts with each reply's model, cited sources, and tool calls; `/save` exports (markdown, JSON,
plain); honest history-overflow accounting with optional summarize-on-overflow; and a **memory seam** consuming
**mneme** (the AGNOS memory/RAG domain) when daimon hosts it — `/remember` writes notes, each turn recalls the
relevant ones (semantic `mneme_search`, sources cited `[N]`, green/amber/red grounding), `/notes` browses the vault
— degrading to a local `.thoth/memory/` file otherwise.

Config lives in a discoverable `.thoth/` home (`.thoth/config.cyml`;
[ADR-0016](docs/adr/0016-thoth-home-dir-config-memory-discovery.md)). Multi-target: Linux ships; aarch64 builds;
macOS builds + runs; AGNOS/Windows staged on named upstream floor gaps. See
[`docs/development/state.md`](docs/development/state.md) and
[`docs/development/roadmap.md`](docs/development/roadmap.md) for the live picture.

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

When AGNOS owns a domain, thoth consumes it and never reimplements it. The
"Thoth" archetype pulled from avatara is the personality overlay for
thoth-the-tool — name, archetype, and function aligned on purpose.

**All five seams are wired.** hoosh and daimon are consumed as
running HTTP services — they ship no linkable crate — reached over the stdlib
`sandhi` transport and configured via `.thoth/config.cyml` (`[hoosh].url`,
`[daimon].url`). bote, t-ron, and avatara bind **in-process**
as vendored dist bundles (`src/vendor/`): bote is the MCP protocol, t-ron
authorizes every gated action (binding when `[tron].policy` loads, else a
fail-closed confirm), and avatara supplies the persona. Any seam left
unconfigured degrades honestly — `/seams` shows the live ladder.

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
cyrius build src/main.cyr build/thoth    # compile (x86_64 Linux)
cyrius test                              # run [build].test + tests/*.tcyr
./build/thoth                            # start the interactive TUI / REPL
```

thoth is also a non-interactive shell citizen — run one task and exit, so it
composes in pipes and scripts:

```sh
thoth 'review this diff'                 # run one task, print the answer, exit
git diff | thoth 'review this'           # piped stdin is appended to the task
thoth --json 'summarize' | jq .response  # one JSON object per turn (for jq/CI)
thoth -o out.md 'draft a README'         # tee the answer to a file as well as stdout
source <(thoth --completion bash)        # tab-complete thoth's flags (bash or zsh)
thoth --help                             # the full one-shot reference
```

For multi-target builds use the driver — `./scripts/build.sh [linux|macos|win|aarch64|agnos|all]`
(Linux ships; other targets are staged, see
[ADR-0008](docs/adr/0008-multi-target-builds.md)).

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
