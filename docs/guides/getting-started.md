# Getting started with thoth

thoth is an interactive REPL/TUI that reads a line, dispatches it, and iterates.
The full AGNOS capability spine (hoosh/daimon/bote/t-ron/avatara) is **wired**
through *seams*: a free-text turn routes to a backing model via **hoosh** and,
when **daimon** is configured, drives a model-driven agentic loop — the model
calls daimon's MCP tools, **t-ron** authorizes each, and results loop back until
the model answers. A seam that isn't configured degrades honestly; nothing is
faked (`/seams` shows the live ladder).

The two things that bind only when you point them at a service: `[hoosh].url`
(model backend) and `[daimon].url` (MCP tool host) in `thoth.cyml`. Without them,
the loop still runs and says so honestly.

## Build, run, test

```sh
cyrius deps                              # resolve stdlib deps
cyrius build src/main.cyr build/thoth    # compile the binary
cyrius test                              # run the unit suite (tests/thoth.tcyr)
./build/thoth                            # start the REPL
```

The toolchain pin lives in `cyrius.cyml [package].cyrius`; CI reads it — don't
hardcode it elsewhere.

## Using the REPL

```
thoth> /help              show commands
thoth> /seams             the capability ladder — which spine seams are wired
thoth> /state             session state (turns, model, context, spine)
thoth> /model [id]        show the model, or switch it mid-session (routes via hoosh)
thoth> /models            list the models the hoosh gateway offers
thoth> /read <file>       print a file (safe, read-only)
thoth> /write <f> <text>  write a file — t-ron-gated
thoth> /run <cmd>         run a shell command — t-ron-gated (fail-closed)
thoth> /tools             list the MCP tools daimon hosts
thoth> /call <tool> [json]  invoke an MCP tool via daimon — t-ron-gated
thoth> /audit             show t-ron's audit chain (gated-action log)
thoth> /reset             clear the multi-turn conversation context
thoth> write me a quicksort   free text → a coding task → the model (agentic loop if daimon is wired)
thoth> /quit              exit (or Ctrl-D)
```

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
- `src/config.cyr` — `thoth.cyml` runtime config (seam URLs, toggles).
- `src/seams.cyr` — the capability-seam registry (the five spine seams + status).
- `src/session.cyr` — session state, multi-turn history, the avatara persona overlay.
- `src/hoosh.cyr` — the hoosh seam client (chat completions, streaming, `/models`).
- `src/daimon.cyr` — the daimon seam client (MCP tool list + call).
- `src/agent.cyr` — the model-driven agentic tool-calling loop.
- `src/gate.cyr` — the t-ron authorization choke point (and fail-closed confirm).
- `src/log.cyr` — structured driver-event logging (`[log]`, off by default).
- `src/exec.cyr` — the local shell escape for `/run` (portable `process.cyr`).
- `src/util.cyr` — buffered stdin `read_line`, `emit`, small helpers.
- `src/vendor/` — committed spine dist bundles (bote-core, libro, t-ron, avatara).
- `tests/thoth.tcyr` — the unit suite (`cyrius test`).

## Adding a command

1. Add a `CMD_*` to the `enum Cmd` in `src/commands.cyr`.
2. Recognize it in `classify_input` (add a `token_is` line).
3. Write a `cmd_*` handler and wire it into `dispatch`.
4. Add assertions to `tests/thoth.tcyr` (cover `classify_input` + any pure helper).
5. `cyrius test`, then `cyrius build`.

A capability that belongs to a spine domain (inference, MCP, authorization,
orchestration, personality) is **not** implemented here — it binds to the
owning crate through a seam. See
[architecture note 001](../architecture/001-consumer-only-no-domain-logic.md).
