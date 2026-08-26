# Getting started with thoth

thoth is an interactive REPL/TUI that reads a line, dispatches it, and iterates.
The full AGNOS capability spine (hoosh/daimon/bote/t-ron/avatara, plus mneme for memory and sit
for git — seven seams) is **wired**
through *seams*: a free-text turn routes to a backing model via **hoosh** and,
when **daimon** is configured, drives a model-driven agentic loop — the model
calls daimon's MCP tools, **t-ron** authorizes each, and results loop back until
the model answers. A seam that isn't configured degrades honestly; nothing is
faked (`/seams` shows the live ladder).

The two things that bind only when you point them at a service: `[hoosh].url`
(model backend) and `[daimon].url` (MCP tool host) in `.thoth/config.cyml`. Config
lives in a discoverable `.thoth/` home directory (like `.git/`), found by walking
**up** from the current dir for the nearest `.thoth/`, then `~/.thoth/`; a legacy
`./thoth.cyml` in the working dir is still read as a fallback. Copy the committed
`.thoth/config.cyml.example` to `.thoth/config.cyml` to start. Without a
`[hoosh].url` the loop still runs and says so honestly (the greeting states the
config source and whether the gateway actually answers — never a faked READY).

## Build, run, test

```sh
cyrius deps                              # resolve stdlib deps
cyrius build src/main.cyr build/thoth    # compile the binary
cyrius test                              # run the curated suites (tests/thoth_{core,gui,render}.tcyr + tests/cases/*.cyr)
./build/thoth                            # start thoth (rich TUI on a capable terminal; line REPL otherwise)
./build/thoth gui                        # open the sovereign Wayland desktop GUI (tier T3, needs a compositor)
```

The toolchain pin lives in `cyrius.cyml [package].cyrius`; CI reads it — don't
hardcode it elsewhere.

## Using thoth — interactive and one-shot

Launching `./build/thoth` on a real terminal opens the **T2 rich-TUI** (alt-screen status
bar, scrolling feed, file-tree pane, slash-command palette) — it is the **default** on a
capable terminal; piped / CI / lower tiers fall back to the **line REPL** automatically (the
prompt is `{(o> `). `--tier=simple|rich|auto` forces the mode (the old `THOTH_TIER` env var was
removed). Both drive the same dispatch loop. The prompt below is shown as `{(o> `:

```
{(o> /help               show commands
{(o> /seams              the capability ladder — which spine seams are wired
{(o> /state              session state (turns, model, context, tokens, cost, spine)
{(o> /model [id]         show the model, or switch it mid-session (routes via hoosh)
{(o> /models             list the models the hoosh gateway offers
{(o> /read <file>        print a file (safe, read-only; syntax-highlighted in the TUI)
{(o> /write <f> <text>   write a file — t-ron-gated (shows a colored diff first)
{(o> /run <cmd>          run a shell command — t-ron-gated (fail-closed)
{(o> /tools              list the MCP tools daimon hosts
{(o> /call <tool> [json] invoke an MCP tool via daimon — t-ron-gated
{(o> /dry <task>         preview the request thoth would send, without sending it
{(o> /audit              show t-ron's audit chain (gated-action log)
{(o> /reset              clear the multi-turn conversation context
{(o> /clear              clear the content window (Shift-↑/↓ scrolls history)
{(o> /theme [dark|light|rainbow] switch the color theme (⌃T toggles in the TUI)
{(o> /persona [name]     show the active persona, or switch it mid-session (from avatara)
{(o> /personas           list the available personas
{(o> /role [name]        show or set the persona's role (the trait-derived third axis)
{(o> /git [path]         the working repo — branch/status, or a per-file diff (consumes sit)
{(o> /remember <fact>    save a durable fact to project memory (mneme when hosted, else .thoth/memory/) — t-ron-gated
{(o> /notes <query>      browse the mneme knowledge base directly (needs the memory seam bound)
{(o> /conversations      list conversations (also /convos) — active marked, with message counts
{(o> /new [title]        start a new conversation
{(o> /switch <n>         switch to conversation n (see /conversations)
{(o> /rename <title>     rename the current conversation
{(o> /delete <n>         delete conversation n
{(o> /search <text>      search every conversation for text (jump with /switch)
{(o> /allow <path>       grant the agent a read root beyond the launch dir
{(o> /save <file>        export the conversation transcript
{(o> /reload             re-read .thoth/config.cyml mid-session (hot fields apply)
{(o> /context            the context window — what this turn will carry, and what is being dropped
{(o> /compact            summarize the conversation so far to reclaim context
{(o> /rewind [n]         undo the model's file writes from a checkpoint (the write tools' undo)
{(o> /fork               branch the current conversation into a new one from this point
{(o> /grants             the read roots granted this session (see /allow)
{(o> /resources          list the MCP resources daimon's hosts expose
{(o> /resource <uri>     read one resource into the conversation (wrapped as untrusted data)
{(o> /prompts            list the MCP prompts daimon's hosts expose (run one as /<name>)
{(o> @file.cyr           mention a file in a message → its contents are appended as context
{(o> write me a quicksort   free text → a coding task → the model (agentic loop if daimon is wired)
{(o> /quit               exit (or Ctrl-D / Ctrl-X)
```

thoth is also a non-interactive shell citizen (the 0.11.x front-door) — run one task and exit:

```sh
thoth 'review this diff'                 # run one task, print the answer, exit
git diff | thoth 'review this'           # piped stdin is appended to the task
thoth --json 'summarize' | jq .response  # one JSON object per turn (for jq/CI)
thoth -o out.md 'draft a README'         # tee the answer to a file as well as stdout
source <(thoth --completion bash)        # tab-complete thoth's flags (bash or zsh)
thoth gui                                # open the desktop GUI instead of the TUI
thoth --help                             # the full one-shot reference
```

Define `[alias]` macros in `.thoth/config.cyml` (`ship = "/run git status"`) to add your own
slash commands; an unknown `/<name>` expands and re-dispatches. In the rich TUI, **Ctrl-P**
opens the model picker. thoth also **reads *and edits*** the project it was launched in: the agent has
default-on jailed `read_file` / `list_dir` tools (reads confined to the launch directory, plus any
`/allow`-granted roots), and — opt-in via `[edit].enabled` (off by default) — jailed **`edit`** (surgical
unique-match replace) and **`create_file`** (create-only) write tools plus an opt-in `shell` tool, each t-ron-gated
under its own verb, so the model can change code, not just explore it. Every model edit/create shows as a colored
diff card in the GUI feed.

`/run`, `/write`, and `/call` route through **one t-ron authorization choke
point**. When `[tron].policy` is configured, t-ron's verdict is final — a policy
deny means the action does not run. When it isn't, a **fail-closed confirm gate**
stands in: it denies by default and proceeds only on an explicit `y`. Either way
security degrades **closed**, never silent-allow — the documented off-AGNOS
posture, made real (see [ADR-0001](../adr/0001-os-agnostic-agnos-primary.md) and
[ADR-0006](../adr/0006-m4-tool-spine-daimon-bote-tron.md)).

## Source layout

- `src/main.cyr` — entry point; includes the modules and runs the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers (the pure
  `classify_input` / `token_is` / `arg_after` helpers are unit-tested).
- `src/config.cyr` — runtime config from `.thoth/config.cyml` (seam URLs, toggles); resolves
  the `.thoth/` home (walk up from CWD, then `~/.thoth`; legacy `./thoth.cyml` fallback).
- `src/seams.cyr` — the capability-seam registry (the seven spine seams + status).
- `src/session.cyr` — session state + the avatara persona overlay, and the **keyed multi-conversation store** (`_conv_store` + the `conv_*` API) that backs `/conversations`/`/new`/`/switch`, with `THOTH-SESSION-2` persistence carrying each reply's model / cited sources / tool calls.
- `src/hoosh.cyr` — the hoosh seam client (chat completions, streaming, `/models`).
- `src/daimon.cyr` — the daimon seam client (MCP tool list + call).
- `src/agent.cyr` — the model-driven agentic tool-calling loop.
- `src/gate.cyr` — the t-ron authorization choke point (and fail-closed confirm).
- `src/log.cyr` — structured driver-event logging (`[log]`, off by default).
- `src/exec.cyr` — the local shell escape for `/run` (portable `process.cyr`).
- `src/roundlog.cyr` — the session-local agentic tool-round trace `/audit` surfaces (0.7.0).
- `src/diff.cyr` — the bounded LCS line-diff for `/write` / `/read`.
- `src/mdhl.cyr` — the markdown + fenced-code syntax highlighter for the reply feed and `/read`.
- `src/ui.cyr` — the presentation surface: tier detection + the semantic color-role API (M7).
- `src/surface.cyr` — the tier-agnostic status **view-model** (facts-not-bytes) the line/TUI/GUI renderers share.
- `src/feed.cyr` — the self-managed T2 feed ring + the escape-aware clip / soft-wrap (M7).
- `src/ftree.cyr` — the togglable file-tree pane: geometry + flattened-tree model (M7).
- `src/intr.cyr` — the turn-interrupt substrate (Esc-abort), decoupled from the TUI.
- `src/tui.cyr` — the T2 alt-screen front-end: status bar, composer, palette, painter (M7).
- `src/gui/` — the sovereign T3 desktop GUI (`thoth gui`): the draw-command IR (`gdraw`) + kashi CPU rasterizer
  (`graster`) + view-builders (`gstatus`/`gtree`/`gtool`/`gfeed`/`gmem`/`gconv`) + the Wayland window seam
  (`gwindow`) + present loop (`gpresent`) + evdev input (`ginput`). Renders the same view-models as the line/TUI
  tiers, plus tool-call cards + colored diff cards, a per-turn memory/grounding strip (`gmem`), and a Ctrl+K
  conversation sidebar (`gconv`) over the `conv_*` store.
- `src/inhist.cyr` — the composer input-history recall ring + opt-in persistence (0.11.x).
- `src/oneshot.cyr` — the one-shot / argv front-door (`thoth 'task'`, `--json`, `-o`, `--completion`, `--tier`).
- `src/memory.cyr` — the memory seam: consumes **mneme** via daimon when hosted (`/remember`, semantic recall, citations, grounding, `/notes`), degrading to the local `.thoth/memory/` reader otherwise.
- `src/memlog.cyr` — the per-turn ring of recalled-source titles + grounding verdict (feeds the GUI `gmem` strip, 0.32.5).
- `src/mention.cyr` — `@file` mention expansion (appends a file's contents to the message).
- `src/project.cyr` — the default-on jailed `read_file` / `list_dir` tools the agent uses to see the project.
- `src/edit.cyr` — the opt-in, jailed, `thoth_edit`-gated model `edit` / `create_file` write tools (ADR-0017).
- `src/editlog.cyr` — the session ring of each edit's diff (keyed by turn/round/call), for the GUI diff cards.
- `src/git.cyr` — the git producer (`/state` row, `/git`, status-bar branch) — consumes sit.
- `src/shell.cyr` — the opt-in, t-ron-gated model-invokable `shell` tool (off by default).
- `src/mpick.cyr` — the Ctrl-P model-picker palette.
- `src/fsearch.cyr` — in-feed search.
- `src/search.cyr` — the jailed `search` tool (glob + content grep across the project).
- `src/checkpoint.cyr` — the file-snapshot store behind `/rewind` (a pre-edit copy per model write, 0.40.0).
- `src/subagent.cyr` — `delegate(task)`: a scoped child *context*, off by default ([ADR-0018](../adr/0018-subagent-delegation-scoped-child-context.md)).
- `src/mcpres.cyr` — MCP resources + prompts (`/resources`, `/resource`, `/prompts`) via daimon.
- `src/hooks.cyr` — operator lifecycle hooks (`[hooks]`); `pre_tool` can BLOCK a tool call.
- `src/toolpin.cyr` — trust-on-first-use hashing of tool definitions (the rug-pull defence, `[toolpin]`).
- `src/guard.cyr` — the injection-heuristic envelope over untrusted prose (`[guard]`).
- `src/redact.cyr` — secret/PII redaction of tool results (`[redact]`, on by default).
- `src/verify.cyr` — the post-edit `[verify].command` gate (run the build/tests after a model write).
- `src/events.cyr` — the `--events` NDJSON stream (turn/tool brackets for a driving program).
- `src/reasonlog.cyr` — the per-turn ring behind the Ctrl+R "thinking" fold (session-scoped).
- `src/mdmodel.cyr` — the shared structural-markdown model (facts-not-bytes) the line/TUI/GUI renderers classify with.
- `src/util.cyr` — the output-capture sink (`OUT_FD1`/`OUT_RING`/`OUT_NULL`) + `read_line` / `emit` / helpers.
- `src/version.cyr` — the single runtime version string (generated from `VERSION`).
- `src/vendor/` — committed spine dist bundles (bote-core, libro, t-ron, avatara) plus the vendored vyakarana
  tokenizer (syntax highlighting), darshana TTY substrate (the T2 TUI), kashi font rasterizer (the T3 GUI), and
  sankoch (zlib) + sit-read (git read profile) behind the git producer.
- `tests/` — the curated suites `tests/thoth_{core,gui,render}.tcyr` (thin drivers) over the topical bodies in
  `tests/cases/*.cyr`; `src/test.cyr` is the `cyrius test` driver. (The old single `tests/thoth.tcyr` was split in 0.30.9.)

## Adding a command

1. Add a `CMD_*` to the `enum Cmd` in `src/commands.cyr`.
2. Recognize it in `classify_input` (add a `token_is` line).
3. Write a `cmd_*` handler and wire it into `dispatch`.
4. Add assertions to `tests/cases/core.cyr` (cover `classify_input` + any pure helper), wired via `tests/thoth_core.tcyr`.
5. `cyrius test`, then `cyrius build`.

A capability that belongs to a spine domain (inference, MCP, authorization,
orchestration, personality) is **not** implemented here — it binds to the
owning crate through a seam. See
[architecture note 001](../architecture/001-consumer-only-no-domain-logic.md).
