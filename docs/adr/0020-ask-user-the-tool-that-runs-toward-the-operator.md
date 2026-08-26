# ADR-0020 — `ask_user`: the tool that runs toward the operator

**Status:** Accepted (0.44.0)

## Context

Every tool thoth has runs *away* from the user: `read_file` reads a file, `shell` runs a command,
`delegate` spawns a child, daimon's tools call a host. When the model reached a decision only the human
could make — an ambiguous requirement, a choice between approaches with real trade-offs, a fact not
present in the project — it had exactly two moves: guess, or announce an assumption and carry on. Both
are worse than asking.

Peers solved this years ago; thoth had not, and the reason it had not is instructive. Asking is easy on
one surface and structurally hard on the others, and thoth has four.

## Decision

One model-invokable tool, **`ask_user(question, options?)`**, that BLOCKS the turn, shows the question
with a numbered list of the model's suggested answers and a free-text field, and returns whatever the
operator says as the tool result.

**Suggested answers are suggestions, never a menu.** The operator can always type something else — the
free-text field is present whether or not the model supplied options, and typing takes precedence over
any highlighted suggestion. A tool that could only offer a closed choice would let the model frame the
decision as well as ask it.

**One resolution rule, shared by every surface.** `ask_resolve` turns a typed line into an answer: a
bare in-range number picks that option, anything else is the operator's own words, empty declines. So
"2" means the same thing in the TUI, the GUI and the line REPL, and the three cannot drift.

### The front-end seam

The module (`src/ask.cyr`) owns the state and the policy and knows nothing about drawing. A front end
registers a blocking asker with `ask_hook_set`, exactly as it registers `intr_check_hook_set`
(`src/intr.cyr`) and `confirm_hooks_set` (`src/gate.cyr`). Each front end claims the seam **at its own
startup**, not in `main`'s preamble — the hook must belong to the surface that is actually running.

| surface | asker | mechanism |
|---|---|---|
| T2 rich TUI | `tui_ask` | the **confirm bracket** — `tui_confirm_begin/end` drop to `OUT_FD1` on the live screen, suspend Esc-poll so a cooked `read_line` echoes, and repaint afterwards |
| T3 Wayland GUI | `gui_ask` | a **nested poll loop** over `_gpresent_poll_fd` / `gwl_win_next_key` / `_gpresent_frame`, with a card composited last in `gframe_build` |
| line REPL | *(none)* | a plain cooked `read_line` — correct there, and free |
| one-shot / `--json` / `--events` | *(none)* | **degrades**: returns an honest "nobody could be asked" that tells the model to state its assumption |

### Why the TUI could not use a normal modal

Both existing TUI modals — the Ctrl-P model picker and the feed search — are **loop-level**: entered
from `tui_loop`'s key branch and drained by the same `while (_tui_running)` loop. During a turn that
loop is not running; it is blocked inside `dispatch()`, several frames above the tool round where
`ask_user` executes. The confirm bracket is the one mechanism that already works from inside a tool
round, and it has been carrying the y/N gate since 0.18.6.

### Why the GUI needed something built

Audit finding **A-11** (0.39.0) recorded that the GUI *"has no modal to render this in and no path from
evdev to `read_line`"*, which is why `confirm` DENIES on `OUT_NULL`: a turn that tried hung forever on a
prompt whose bytes went to a discard sink, presenting as a frozen window with no visible cause. This
release builds exactly that missing pair. It was possible because 0.35.0's mid-turn pump (`_gstop_poll`)
had already proved the shape — drain the Wayland fd and repaint from inside a synchronous turn — so the
modal is the same three primitives with a *blocking* poll instead of a peek.

`src/gui/gask.cyr` holds its **own** copy of the question and options rather than reading `src/ask.cyr`.
That keeps it a pure view-builder over `gdraw` + `ui`, which is what lets `tests/thoth_gui.tcyr` include
it headlessly beside `gstatus`/`gtree`/`gconv` and drive it with fixture text; `gui_ask` bridges the two.

## The safety rules, and why each exists

**The question is model-authored text that gets displayed**, so it is sanitised once at ingest —
C0 controls and DEL substituted with `?`, the width-preserving `_tree_set_name` rule from
`src/ftree.cyr`. Newlines are substituted too, unlike the hook-output policy that keeps them: a `\n` in
a question would be a free extra screen row the model controls. Without this, a raw ESC reaching the T2
feed is stored and re-emitted verbatim, and the question could clear the screen or reposition the cursor
to forge output.

**The model never occupies the trust position.** Each surface prefixes the question with a fixed literal
that surface owns — `[the agent is asking]` — drawn in thoth's accent role. The operator must be able to
tell thoth asking from a model that has written something shaped like a prompt.

**In the GUI the threat is layout forgery, not escape forgery** — `graster` has no escape interpreter
and advances past control codepoints without drawing. So the defence there is the codepoint clip
(`max_cp`) on every model-authored string plus the option cap, so nothing can push the card's own
affordance line off the card.

**Not t-ron-gated, deliberately.** A question touches no file, no process and no network — strictly less
dangerous than `read_file`, which is ungated too — and gating it would mean a confirm prompt to
authorize a prompt.

**Bounded per TURN, not per session.** The resource this tool spends is the operator's *attention*, and
no authorization policy expresses "stop bothering me". `ASK_MAX_PER_TURN` is 4; the budget resets each
turn beside `_agent_work_reset`/`intr_reset`. A question that could **not** be asked spends nothing —
the counter tracks interruptions, not attempts.

**Off by default** (`[ask].enabled`). A model that asks well is a better collaborator; one that asks
badly makes a session unusable, and the operator should opt into finding out which they have.

**It never returns an empty string.** "They said nothing", "they declined" and "nobody could be reached"
are three different facts the model must be able to act on differently, and a bare `""` reads as the
first on every surface.

## Consequences

- `_agent_round_has_local` gains `ask_user`: it must take the serial path, both because the parallel
  executor fires no `pre_tool` hook and no events, and because two concurrent workers cannot both own
  the operator's screen.
- The 8 MB `preprocess_out` ceiling **bit again** — adding one module pushed `tests/thoth_core.tcyr`
  over. The TUI test bodies moved to a new `tests/thoth_tui.tcyr` (identical src chain, split bodies);
  nothing was dropped and every assertion still runs. This is the second release running that the
  ceiling has shaped a change, and the real fix remains upstream lean `[lib.X]` profiles.
- `/state` gains an `ask` row that names **which surface can answer**, because the tool is advertised
  wherever it is enabled but only answerable where a human can be reached — and a user must not learn
  that from a refusal mid-turn.

## Verified

Not asserted — driven end to end against a gateway that calls the tool:

| surface | input | the model received |
|---|---|---|
| line REPL | `2` | `SQLite` |
| T2 TUI | `3` | `Leave it abstract` |
| T2 TUI | `DuckDB, actually` | `DuckDB, actually` |
| line REPL | *(empty)* | `(the operator declined to answer …)` |
| one-shot | *(no human)* | `(nobody could be asked …)`, no hang |

The T3 modal's view-builder and key fold are covered headlessly in `tests/cases/gui.cyr`; its poll loop
needs a live compositor and is the one part still pending an on-compositor confirmation.

## Alternatives rejected

- **A slash command the user runs to answer.** Puts the turn in a state the operator has to discover and
  then service; the whole value is that the agent surfaces the question itself.
- **An `--events` question event with no blocking.** Right for a programmatic driver and wrong as the
  only mechanism — it leaves every interactive surface unable to answer. Worth adding later *beside*
  this, not instead of it.
- **Reusing `confirm`.** It answers y/N/allow-all against a *verb and object thoth chose*. A question is
  free text the model chose, needs suggestions and a text field, and must not inherit session grants —
  "allow all" makes no sense for a question.
