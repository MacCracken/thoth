# 0011 — One-shot / argv front-door: thoth as a non-interactive shell citizen

**Status**: Accepted
**Date**: 2026-06-25

## Context

Until 0.11.0 thoth had exactly one way in: launch, then type at the interactive
TUI / line-REPL. `src/main.cyr` parsed **no argv at all**. That makes thoth a
poor citizen of the Unix shell — you cannot say `git diff | thoth 'review this'`,
`cat err.log | thoth 'explain'`, or chain `thoth 'draft' | thoth 'critique'`, and
it cannot be scripted in CI.

A one-shot mode is also the **keystone** of the 0.11.x line: the JSON-envelope
output, the `-o` file tee, and shell-completion generation all need an argv
front-door first (they were the cluster the SecureYeoman-TUI review surfaced, each
gated on this one).

Two hazards shaped the design, both flowing from thoth's own constraints:

1. **Piped stdin already has meaning.** thoth's line-REPL reads piped stdin
   line-by-line (`cat script.txt | thoth` runs each line as a command), and prints
   a banner + `scribe out.`. So we **cannot** key one-shot on `isTTY == false` the
   way the surveyed tool does — that would silently repurpose an existing,
   byte-identical behavior. The piped/CI floor is a hard invariant ([ADR-0009](0009-presentation-capability-ladder.md)).

2. **Clean stdout is the whole point.** For `thoth | thoth` chaining and
   redirection, stdout must be *exactly the answer* — no banner, no `-> hoosh`
   progress line, no agent tool-call chrome, no streamed-then-final duplication.
   But the answer and the chrome are emitted through the same `emit`/`emit_n`
   sink, so they cannot be separated by routing alone.

## Decision

**Add a non-interactive one-shot mode, gated on EXPLICIT argv intent, that runs ONE
turn through the existing seam and prints only the answer to stdout.**

- **Explicit-intent gating, never `isTTY`.** One-shot engages only when a task is
  present on argv (a positional arg), or `-p`/`--print` is given. `--version`/`-v`
  and `--help`/`-h` short-circuit. With no argv task, `oneshot_mode()` returns
  `ONESHOT_NONE` and thoth falls through to the TUI/REPL **unchanged** — so the
  piped/CI floor stays byte-identical and the line-REPL keeps its meaning. Piped
  stdin is slurped **only as the payload** appended to an argv task (never read
  from an interactive tty).

- **No new spine path — only a new input source.** A one-shot turn runs through the
  existing `cmd_task → hoosh_send / agent_turn` seam. thoth adds argv + slurped
  stdin as an input and a clean output contract; it reimplements no
  inference/routing/MCP/auth/persona. ([ADR-0002](0002-consume-the-agnos-stack.md).)

- **Clean stdout via discard-then-emit.** The turn runs with output **discarded**
  (a new `OUT_NULL` sink mode), so none of the human-progress chrome leaks; afterward
  `one_shot_run` prints **only** the accumulated reply (`hoosh_last_reply`) to fd 1,
  with a trailing newline. Diagnostics — transport/HTTP error, an empty reply, a
  denied authorization — go to **stderr** (fd 2). So fd 1 is exactly the answer and
  pipes cleanly; fd 2 carries the human-facing detail.

- **Degrade closed end to end.** The hoosh seam absent / unreachable → a concise
  stderr line and a **nonzero exit**; a real answer → exit 0. The t-ron confirm gate
  **denies** in one-shot (a non-interactive invocation cannot safely authorize, and
  the prompt would be discarded under `OUT_NULL`) — announced on stderr, never a
  silent allow or a blocking invisible prompt. This is the security-degrades-closed
  posture ([ADR-0001](0001-os-agnostic-agnos-primary.md)) applied to the new surface.

- **Portable substrate.** argv comes from the portable `args_init`/`argc`/`argv`
  (Linux `/proc/self/cmdline`, AGNOS the captured rsp — capped at 8 args, so long
  tasks belong on stdin). No per-OS source.

## Consequences

- **Positive** — thoth becomes a first-class shell/CI citizen (`git diff | thoth
  'review'`, `thoth 'x' | thoth 'y'`, `thoth 'q' > out.md`) with a clean,
  pipe-safe stdout contract, while the interactive surface and the byte-identical
  floor are untouched. It unblocks the 0.11.x riders (JSON envelope, `-o` tee,
  completion).
- **Negative** — one-shot is **quiet**: progress is discarded, so a slow agentic
  turn shows nothing until the answer, and the gateway's verbose error *body* is
  not surfaced (the concise stderr line + nonzero exit are; run interactively or
  `[hoosh].stream=false` for the body). Accepted — a quiet, clean one-shot is the
  CLI-idiomatic trade.
- **Neutral** — adds `OUT_NULL` to the output-sink model and a small `src/oneshot.cyr`
  module; the pure argv classifier is unit-tested.

## Alternatives considered

- **Key one-shot on `isTTY == false` (the surveyed tool's approach).** Rejected:
  thoth's piped stdin already drives the line-REPL, so this would silently change
  existing behavior and break the byte-identical floor.
- **Route chrome to stderr (`OUT_FD2`) and the answer to stdout, keeping streaming.**
  Rejected for the default: the answer would appear both in the fd-2 progress stream
  and on fd 1 (a visible double when both are a terminal). Discard-then-emit gives a
  single clean answer.
- **A hoosh one-shot/preview endpoint.** Rejected: thoth composes and runs the turn
  locally through the existing seam; a server-side one-shot path would creep toward
  forking the inference spine.
- **Block (prompt) on the t-ron confirm in one-shot.** Rejected: a non-interactive
  invocation cannot answer, and under `OUT_NULL` the prompt is invisible — it would
  hang or mislead. Denying (fail-closed), announced on stderr, is the safe direction.
