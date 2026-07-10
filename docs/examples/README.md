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

## 5. Make it your own

- **Aliases** — add `[alias]` macros to `.thoth/config.cyml` (`ship = "/run git status"`); an
  unknown `/<name>` expands and re-dispatches.
- **Project memory** — `mkdir -p .thoth/memory`, set `[memory].enabled = true`, then `/remember
  <fact>`; curated facts are injected into each turn (opt-in; see
  [ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md)).
- **Persona / role** — `/persona`, `/personas`, and `/role` switch the avatara archetype and its
  trait-derived role mid-session.
