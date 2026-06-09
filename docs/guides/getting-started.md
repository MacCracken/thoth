# Getting started with thoth

thoth 0.1.0 is a **driver core**: an interactive REPL/TUI that reads a line,
dispatches it, and iterates. The AGNOS capability spine
(hoosh/daimon/bote/t-ron/avatara) is reached through *seams* that are all
**absent** in 0.1.0 — so the agent loop is real, but model-backed reasoning,
MCP tools, and authorization are not wired yet. Absent capabilities degrade
honestly; nothing is faked.

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
thoth> /state             session state (turns, model, spine)
thoth> /read <file>       print a file (safe, read-only)
thoth> /model gpt-5       attempt a mid-session model switch (routes via hoosh — absent)
thoth> /run <cmd>         run a shell command — t-ron-gated (fail-closed)
thoth> /write <f> <text>  write a file — t-ron-gated
thoth> write me a quicksort   free text → a coding task → routed to hoosh (absent)
thoth> /quit              exit (or Ctrl-D)
```

`/run` and `/write` pass a **fail-closed confirm gate** that stands in for the
absent t-ron authorization seam: it denies by default and proceeds only on an
explicit `y`. That is the documented off-AGNOS security posture, made real —
see [ADR-0001](../adr/0001-os-agnostic-agnos-primary.md).

## Source layout

- `src/main.cyr` — entry point; includes the modules and runs the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers (the pure
  `classify_input` / `token_is` / `arg_after` helpers are unit-tested).
- `src/seams.cyr` — the capability-seam registry (the five spine seams + status).
- `src/session.cyr` — session state + the static avatara persona descriptor.
- `src/exec.cyr` — the local shell escape for `/run` (portable `process.cyr`).
- `src/util.cyr` — buffered stdin `read_line`, `emit`, small helpers.
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
