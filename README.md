# thoth

A sovereign agentic coding TUI — written in [Cyrius](https://github.com/MacCracken/cyrius).

thoth is the user-facing front-end for the end-user dev workflow on AGNOS: an
interactive REPL/TUI driver that reads a task, plans, edits files, runs tools,
and iterates. Its signature move is being a **model-switching scribe** — it can
switch the backing model mid-session, routing a turn to a different LLM, tier,
or provider when that serves the work.

> **Status: 0.44.1 (pre-1.0).** The full AGNOS spine is wired, the agentic loop closes, and thoth reads *and
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

**Reads and writes the project it's launched in.** Default-on jailed `read_file` / `list_dir` / `search`
(a grep+glob project search) plus `@file` mentions (`/allow` widens the jail); **opt-in** jailed `edit` /
`create_file` / `shell` tools (each t-ron-gated, off by default) so the model can change code, not just read
it; a git producer (`/git`); `web_fetch` / `web_search` via daimon + bote. Every model write is snapshotted
first — **`/rewind`** undoes a turn's file changes, and a write that cannot be snapshotted is refused rather
than performed.

**Delegates its own busywork.** The opt-in **`delegate`** tool (`[subagent]`) hands a self-contained sub-task
to a **scoped child agent**: the same tools and the same policy, but its own empty context, returning one
short answer. Locating a symbol in an unfamiliar tree is the most expensive thing a coding agent does, and
this is how that cost stops landing in your conversation. Depth-capped at 1, and the child's tool calls run
through the *same* gate, hook, jail and audit chain as the parent's — there is exactly one dispatch path
([ADR-0018](docs/adr/0018-subagent-delegation-scoped-child-context.md)).

**Security you can point at.** A t-ron-gated tool spine with a fail-closed confirm when no policy is loaded;
**`[redact]`** strips secrets from tool results before they reach the feed, the transcript or the next
request; **`[guard]`** marks untrusted prose (file reads, recalled notes, MCP resources) as data rather than
instructions; **`[hooks]`** gives the operator a blocking `pre_tool` deny a prompt cannot argue with;
**`[toolpin]`** pins every MCP tool definition on first sight and *withholds* one whose definition changes
underneath you (CVE-2025-54136); **`[verify]`** runs your project's own check after a model write and feeds
the result back. `/audit` surfaces the hash-linked libro chain of every gated action and `/audit export`
writes it out. The honest half: the shell glob filter is a pre-filter, not a sandbox, and the project jail is
a boundary, not a sandbox — thoth says so where it matters.

**Speaks MCP's three nouns.** Not just tools: **`/resources`** lists what a server publishes and
**`/resource <uri>`** pulls one into the conversation (redacted and guard-wrapped like any tool result), and
server-published **prompts become slash commands** — a server offering `deploy(env)` gives you
`/deploy staging`. Built-ins and your own `[alias]` entries always win over a server's name.

**Keeps the thread.** Named **multi-conversation management** (`/new`, `/switch`, `/rename`, `/delete`, `/search`),
persisted across restarts with each reply's model, cited sources, and tool calls; `/save` exports (markdown, JSON,
plain); honest history-overflow accounting with optional summarize-on-overflow; and a **memory seam** consuming
**mneme** (the AGNOS memory/RAG domain) when daimon hosts it — `/remember` writes notes, each turn recalls the
relevant ones (semantic `mneme_search`, sources cited `[N]`, green/amber/red grounding), `/notes` browses the vault
— degrading to a local `.thoth/memory/` file otherwise.

Config is **two layers** ([ADR-0019](docs/adr/0019-layered-config-global-base-local-override.md)):
`~/.thoth/config.cyml` is the global base and the nearest `.thoth/config.cyml` overrides it **per key**.
Memory layers the same way. Lists that grant the model authority (`[shell].allow`, `[project].read_roots`)
are *replaced* by the local layer rather than merged, while `[shell].deny` unions — authority never
accumulates from the less-trusted side. Multi-target: x86_64 Linux ships;
aarch64 Linux and AGNOS build (all three re-measured at 0.43.0); Windows is staged on an architectural
IOCP/epoll floor gap; **macOS does not currently build**, and that one is thoth's own bug rather than a
dependency's — `src/tui.cyr` calls darshana's termios/signalfd half unguarded and darshana gates that half
to Linux (re-tested at 0.43.0 on Apple Silicon with the pinned toolchain). See
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
| **mneme**  | persistent memory / project notes (reached *through* daimon's host registry) |
| **sit**    | version control — branch / status / diff over git and `.sit` repos |
| **agnosai**| the injection heuristics behind `[guard]` and the secret patterns behind `[redact]` (its `[lib.guard]` profile) |

When AGNOS owns a domain, thoth consumes it and never reimplements it. The
"Thoth" archetype pulled from avatara is the personality overlay for
thoth-the-tool — name, archetype, and function aligned on purpose.

**All seven seams are wired.** hoosh and daimon are consumed as
running HTTP services — they ship no linkable crate — reached over the stdlib
`sandhi` transport and configured via `.thoth/config.cyml` (`[hoosh].url`,
`[daimon].url`); **mneme**, the memory seam, is reached *through* daimon's host
registry rather than directly, which is why it binds only once daimon hosts it.
bote, t-ron, avatara and sit's read profile bind **in-process** as vendored dist
bundles (`src/vendor/`): bote is the MCP protocol, t-ron authorizes every gated
action (binding when `[tron].policy` loads, else a fail-closed confirm), avatara
supplies the persona, and sit reads the working repo. Any seam left unconfigured
degrades honestly — `/seams` shows the live ladder, all seven rows.

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
thoth --events 'refactor this'           # NDJSON events AS the turn runs (watch tool use live)
thoth -o out.md 'draft a README'         # tee the answer to a file as well as stdout
source <(thoth --completion bash)        # tab-complete thoth's flags (bash or zsh)
thoth --help                             # the full one-shot reference
```

For multi-target builds use the driver — `./scripts/build.sh [linux|macos|win|aarch64|agnos|all]`
(x86_64 Linux ships; aarch64 and agnos build; macos and win are the two open lanes — see
[ADR-0008](docs/adr/0008-multi-target-builds.md)). The `macos` lane only runs on a Mac host: cyrius emits
Mach-O natively there rather than cross-compiling.

The toolchain version is pinned in `cyrius.cyml` (`[package].cyrius`) — that
pin is the source of truth; don't hardcode it elsewhere.

## Documentation

**Ask-me-back.** With `[ask].enabled`, the model can stop mid-turn and ask you a question — suggested
answers plus a free-text field — on the TUI, the desktop GUI or the line REPL; one-shot degrades
honestly rather than blocking ([ADR-0020](docs/adr/0020-ask-user-the-tool-that-runs-toward-the-operator.md)).

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants about the code
- [`docs/guides/`](docs/guides/) — task-oriented how-tos
- [`docs/examples/`](docs/examples/) — usage cheat-sheet (configs + command recipes, not runnable programs)
- [`docs/development/state.md`](docs/development/state.md) — live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestones through v1.0 (forward-facing only)
- [`docs/development/gap-review.md`](docs/development/gap-review.md) — candidate gaps thoth has *not* committed to
- [`docs/doc-health.md`](docs/doc-health.md) — the doc-currency ledger

**Design assets at the repo root**, named here so neither reads as scratch:
[`Thoth.dc.html`](Thoth.dc.html) is the T3 GUI pixel spec (its palette is `src/ui.cyr`'s; cited by
[ADR-0009](docs/adr/0009-presentation-capability-ladder.md) and the `src/gui/` headers), and
`thoth_v1.tiff` is the project emblem — a line-art ibis with the lunar disc, papyrus and uraeus.

## License

GPL-3.0-only.
