# Examples

Concrete, copy-pasteable ways to use thoth. Setup + the command reference are in
[getting-started](../guides/getting-started.md); the full config format is
[`.thoth/config.cyml.example`](../../.thoth/config.cyml.example).

## 1. Point thoth at a gateway

thoth's config lives in a discoverable `.thoth/` home (like `.git/`). Create
`.thoth/config.cyml` at your repo root:

```toml
[hoosh]
url   = "http://127.0.0.1:8088"     # a running hoosh gateway (`hoosh serve 8088`)
# token = "secret"                   # optional bearer; omit for an unauthenticated gateway
# model = "claude-sonnet-4-6"        # optional default model; omit to let hoosh route

[daimon]
url = "http://127.0.0.1:8090"        # optional — wires daimon's MCP tools + the agentic loop
```

thoth finds this by walking **up** from wherever you launch it, then `~/.thoth/config.cyml`
(a global default), so you can run thoth from any subdirectory of the repo. Without a
`[hoosh].url` the loop still runs and says so honestly — the greeting states the config
source and whether the gateway actually answers (never a faked `READY`).

## 2. An interactive session

```sh
./build/thoth                        # opens the rich TUI on a capable terminal
```

```
{(o> /seams              which spine seams are wired (the capability ladder)
{(o> write a quicksort in Cyrius with a test     → a coding task; the model drives the turn
{(o> /model gpt-4o       switch the backing model mid-session (routes via hoosh)
{(o> /read src/main.cyr  print a file (read-only, syntax-highlighted)
{(o> @src/config.cyr how does discovery work?    mention a file → its contents become context
{(o> /git                the working repo — branch, status, per-file diff
{(o> /quit               exit (Ctrl-X / Ctrl-D)
```

`--tier=simple` forces the line REPL (e.g. over a dumb terminal); `--tier=rich` forces the TUI.

## 3. Shell citizen — one task, then exit

```sh
thoth 'explain what src/gate.cyr does'           # run one task, print the answer, exit
git diff | thoth 'review this diff for bugs'      # piped stdin is appended to the task
thoth -p < prompt.txt                             # force one-shot; the whole task comes from stdin
thoth -o review.md 'review this PR'               # tee the answer to a file as well as stdout
```

A one-shot turn writes only the answer to stdout (diagnostics go to stderr) and exits non-zero
on failure, so it composes cleanly in pipes and scripts. t-ron confirmation denies in one-shot
(no interactive prompt) — configure a `[tron].policy` to allow specific tools non-interactively.

## 4. CI / scripting — structured output

```sh
thoth --json 'summarize the changes' | jq -r .response     # one JSON object per turn
thoth --json 'summarize' | jq '{model, turns, tokens, cost}'
source <(thoth --completion bash)                          # tab-complete thoth's flags
```

The `--json` envelope is `{response, model, turns, tokens?, cost?, elapsed_ms}` — token/cost
fields appear only once the gateway reports usage (omit-until-present), never faked.

## 4b. Capturing a session that crashes, hangs, or is killed

```sh
thoth --logs session.log                       # interactive, with a full session log
thoth --logs session.log --log-level trace     # more detail
thoth --logs run.log 'review this project'     # one-shot; stdout stays the answer
```

`--logs` binds the log **before the config is read and before any seam is touched**, so a run that
dies on a bad config, an unreachable gateway or a hang still leaves a record. It is a transcript,
not just a trace — the task, one line per agentic round (with the working-set size), one line per
tool call with its arguments, authorization verdict, wall-time and result size, and the reply:

```
event=turn_start turn=1 model=claude-opus-5 max_iters=25 tool_bytes=8439
event=task part=1 of=1 text=review this project
event=round turn=1 iter=1 work_bytes=0 mode=stream
event=tool name=read_file verdict=allow ok=1 ms=0 bytes=3145 args={"path": "README.md"}
event=agent_turn iters=4 result=ok
event=reply part=1 of=2 text=...
```

Long values split across `part=i of=n` lines, so a file cut short by a crash loses one chunk rather
than the session. It works in every mode — TUI, line REPL and one-shot — and overrides `[log].file`
for that run. For a readable markdown transcript of a session that ended normally, use
`/save <file>` (`--json` / `--plain` variants) from inside the session instead.

## 5. Make it your own

- **Aliases** — add `[alias]` macros to `.thoth/config.cyml` (`ship = "/run git status"`); an
  unknown `/<name>` expands and re-dispatches.
- **Project memory** — `mkdir -p .thoth/memory`, set `[memory].enabled = true`, then `/remember
  <fact>`; curated facts are injected into each turn (opt-in; see
  [ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md)).
- **Persona / role** — `/persona`, `/personas`, and `/role` switch the avatara archetype and its
  trait-derived role mid-session.
