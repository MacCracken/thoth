# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.11.1] - 2026-06-25

**Composer input-history recall (0.11.x terminal-citizen line).** The T2 raw-mode
composer now recalls previously-submitted lines with **Up / Down**, shell-style: Up
walks older, Down newer, and stepping past the newest restores the line you were
typing. This is the top-ranked pure-substrate win from the SecureYeoman-TUI review —
no argv dependency, no spine touched. It is **distinct from the multi-turn conversation
history** (`session_history_*`, 0.5.1): that is the model's memory of the exchange; this
is the user's own keystrokes, kept so they can be navigated back to, re-edited, and
re-sent. 467 unit assertions (+29). Pin unchanged (6.2.43).

### Added
- **`src/inhist.cyr`** — the input-history ring. A PURE, unit-tested core: a 128-slot
  ring of submitted lines with **ignoredups** (a line identical to the newest is not
  re-stored) + skip-empty, O(1) eviction when full (the same ring shape as
  `src/feed.cyr`), and a navigation cursor (`inhist_nav_up`/`_down`/`_reset`/`_at_draft`)
  over `[0, count]` where `count` is "the live draft". Session-local memory only.
- **Recall in the TUI** (`src/tui.cyr`) — `_tui_recall_*` stashes the in-progress draft,
  loads a recalled line into the `led_*` composer (cursor at end), and restores the draft
  past the newest. Bound in `tui_loop` to Up/Down **in composer focus with the slash
  palette closed at the start of recall** (so Up/Down stay free while you compose a
  `/command`); once navigating, it continues regardless so a recalled `/cmd` doesn't
  strand you. A `↑↓ history` hint appears on the hint row once there is history to recall.
- **`test_inhist`** (+29): the ring (store/ignoredups/skip-empty/eviction/order), the full
  nav state machine (draft↔newest↔oldest, clamps, the draft boundary), and the composer
  load/stash/restore glue.

### Notes
- **TUI-only by construction** — recall needs the raw-mode composer's per-keystroke
  editing; the line-mode REPL reads through the kernel's cooked line discipline
  (`read_line`), which thoth does not replace. So the REPL / piped / CI floor is
  **byte-identical** (this code is never reached off the PT_RICH path; the hint is
  byte-identical when history is empty — the common first-use state).
- **Persistence is the next slice (0.11.2).** The spec's opt-in on-disk history file
  (`0600` when enabled, off by default) is deliberately separated — it adds file I/O,
  path resolution, and a security surface that earns its own pre-cut review. This cut is
  in-memory only, so the **default** experience (no persistence) is delivered in full and
  there is no on-disk footprint to secure yet.
- **Pre-cut adversarial review (4 perspective-diverse lenses — memory/bounds, ring +
  nav-cursor correctness, byte-identical floor + consumer posture, Cyrius-language +
  integration)**: zero confirmed findings (the lone raised item was a refuted
  maintainability nit — the `tui_loop` elif ordering is load-bearing; documented inline).
  The TUI render itself verifies on a real tty (`THOTH_TIER=rich`), not the harness.

## [0.11.0] - 2026-06-25

**One-shot / argv front-door — the 0.11.x keystone.** thoth becomes a first-class shell
citizen: a non-interactive mode that runs ONE turn and prints the answer, so it composes
in pipes and scripts.

```
thoth 'review this diff'              # run one task, print the answer, exit
git diff | thoth 'review this'        # piped stdin is APPENDED to the task
cat err.log | thoth 'explain'
thoth -p < prompt.txt                 # piped stdin IS the whole task
thoth 'draft' | thoth 'critique it'   # chains cleanly (stdout = answer only)
thoth --version   ·   thoth --help
```

It owns **no new spine path** — a one-shot turn runs through the EXISTING `cmd_task →
hoosh_send / agent_turn` seam; thoth adds only a new input source (argv + slurped stdin)
and a clean output contract. Mode is gated on **explicit argv intent**, NOT `isTTY ==
false` (piped stdin already drives the line-REPL), so with no argv task thoth falls
through to the TUI/REPL unchanged — the piped/CI floor stays **byte-identical**. See
[ADR-0011](docs/adr/0011-one-shot-argv-front-door.md). Opens the **0.11.x terminal-citizen
line** (the SecureYeoman-TUI-review backlog). 438 unit assertions (+13). Pin unchanged
(6.2.43).

### Added
- **`src/oneshot.cyr`** — the one-shot front-door. A PURE argv classifier (`_oneshot_parse`
  → `ONESHOT_NONE`/`RUN`/`VERSION`/`HELP`, joining positionals into a bounded heap task
  buffer; unit-tested via a hand-built argv snapshot), `oneshot_mode` (snapshots
  `argc`/`argv` over the portable args API — Linux `/proc/self/cmdline`, AGNOS the captured
  rsp, capped at 8 args so long tasks belong on stdin), `_oneshot_append_stdin` (slurps
  stdin as the payload only when fd 0 is **not** a tty), and `one_shot_run` (the orchestrator).
- **Clean-stdout contract.** The turn runs with output **discarded** (new `OUT_NULL` sink
  mode in `src/util.cyr`) so no human-progress chrome leaks; `one_shot_run` then prints
  ONLY the accumulated reply (`hoosh_last_reply`) to fd 1, with a trailing newline.
  Diagnostics (transport/HTTP error, empty reply, denied authorization) go to **stderr**
  (`emit_err`). Exit 0 on a real answer, nonzero otherwise.
- **`--version` / `-v` and `--help` / `-h`** (to stdout, exit 0).
- **`test_oneshot`** (+13): the argv classifier (`NONE`/`RUN`/`VERSION`/`HELP`, `-p` force,
  flag-vs-positional, positional joining) and the bounded task buffer.

### Security / degrade-closed
- **The t-ron confirm gate denies in one-shot** (`src/gate.cyr`): a non-interactive
  invocation can't safely authorize and the prompt would be discarded under `OUT_NULL`, so
  it fails **closed** — denied, announced on stderr, never a silent allow or a blocking
  invisible prompt.
- A **bound-policy DENY/FLAG** is mirrored to stderr in one-shot (`_gate_verdict_err`), so a
  refusal under `OUT_NULL` is announced, not silently swallowed.

### Notes
- **Pre-cut adversarial review (4 lenses, every finding verified)** confirmed the core sound
  (memory discipline, byte-identical floor via explicit-intent gating, consumer posture,
  degrade-closed exit codes, the confirm guard placed before `read_line`). It caught three
  honest-omit/contract gaps, **all fixed before cut**: (1) `gate_init`/`log_init` startup
  chrome leaked to stdout before one-shot dispatch when `[tron].policy`/`[log].file` were
  configured — fixed by classifying the mode first and discarding init chrome under
  `OUT_NULL` (and converting two raw `println` in `log.cyr` to the mode-aware `oprintln`);
  verified: `--version`/one-shot stdout is byte-clean with `[log]` set, REPL floor
  unchanged. (2) A streaming agentic turn that hit the iteration cap left interim narration
  in the reply accumulator, so one-shot could print it as a successful answer — fixed by
  clearing the accumulator on max-iters (`src/agent.cyr`) so one-shot reports failure
  (exit nonzero). (3) The bound-DENY stderr mirror above.
- A live one-shot **success** round-trip (a real answer on stdout) is a host-side step — the
  build sandbox blocks a compiled binary's TCP and a real call costs tokens; the wiring is
  covered by the smoke (clean stdout/stderr split + exit codes on the error paths) and the
  unit tests.
- Known: one-shot is **quiet** (progress discarded; the gateway's verbose error *body* is
  not surfaced — the concise stderr line + nonzero exit are). Run interactively or with
  `[hoosh].stream=false` for the body.

## [0.10.3] - 2026-06-25

**Cost — the second data producer (0.10.x arc).** thoth now surfaces a running session
**cost** (`$d.cc`), priced from hoosh's own token usage times an opt-in, user-declared
`[pricing.<model>]` rate. Cost is **priced at accumulate** — each response is costed with
the model active at that moment — so a mid-session `/model` switch is costed correctly
(a single end-of-session multiply would be wrong across switches). It follows the
**omit-until-present** doctrine ([ADR-0010](docs/adr/0010-data-producer-honest-omit.md)):
the field appears only once a priced response arrives — never a faked `$0` — and `/state`
announces the gap (unconfigured, or a model with no rate) honestly. hoosh owns the token
counts; thoth only multiplies them by the rate you declare. 425 unit assertions (+32).
Pin unchanged (6.2.43).

### Added
- **`[pricing.<model>]` config** (`src/config.cyr`): per-model `input`/`output` rates in
  integer **micro-USD per 1,000 tokens** (= USD-per-1M × 1000; `$3.00/1M → 3000`,
  `$0.25/1M → 250`). Cached at load into a stable fixed table (cap 32 models) keyed by the
  model id — matched **verbatim** against the bracket text, so ids with dots/dashes work.
  `config_price_input`/`config_price_output` return `-1` when a rate is undeclared;
  `_cfg_int` distinguishes an omitted key (`-1`) from an explicit `= 0` (declared free).
- **Pure cost math** (`src/hoosh.cyr`, `src/session.cyr`): `hoosh_cost_micro(p,c,in,out)
  = (p·in + c·out)/1000` (micro-USD); `cost_fmt` renders `$d.cc`, **truncating down** to
  whole cents so cost is never overstated.
- **Session cost tally** (`src/session.cyr`): `session_cost_micro` / `session_cost_seen`
  / `session_cost_unpriced_count` (+ `session_add_cost` / `session_note_unpriced`), cleared
  by `/reset`. `_hoosh_account_usage` folds tokens **and** cost from each response's usage
  (prompt/completion/total), wired into all four turn paths — blocking + SSE, hoosh + agent.
- **`$d.cc` in the TUI status bar** (after `tok`, **omitted** until a priced response) and a
  **`cost` row in `/state`** (the total once priced, else an honest absent line; a partially-
  priced session names how many responses were unpriced-and-omitted).
- **`test_cost`** (+32): the pricing math, the `$d.cc` formatter, the `[pricing]` table
  (verbatim dashed-id match, missing-key → `-1`), the accumulator + honest-omit flags, and
  an **end-to-end** assertion pricing a real usage body through the active model → `[pricing]`
  → accumulator, plus the unpriced- and half-declared-model degrade paths.

### Notes
- **Pre-cut adversarial review (4 lenses, every finding verified)** confirmed the core sound
  (cost_fmt sizing, pointer stability, byte-identical floor, truncation honesty, clean
  spine-consumer posture, price-at-accumulate correctly wired across all paths + multi-round
  agentic turns + the streaming usage frame). It caught one honest-omit gap, fixed before cut:
  a **half-declared** `[pricing.<model>]` (only `input` or only `output`) used to bill the
  missing side at `$0` and show an understated total — now any undeclared rate degrades the
  model to **unpriced + noted** (`&&` → `||` guard), with a regression test.
- **Keying contract:** `[pricing.<model>]` must match the model id thoth **requests**
  (session `/model`, else `[hoosh].model`, else the literal `"default"` under hoosh routing).
  Price a default-routed session with `[pricing.default]`, or set `[hoosh].model`. Documented
  in `thoth.cyml.example`.
- The piped/CI floor stays byte-identical (status field TUI-only; the `/state` row emits 0
  escapes at T0 — verified). A live priced round-trip is a host-side step (the build sandbox
  blocks a compiled binary's TCP); the math + wiring are covered by `test_cost`.

## [0.10.2] - 2026-06-25

**Token usage — the first data producer (0.10.x arc).** thoth now surfaces a live
`tok <n>` session token count, sourced from hoosh's own `usage.total_tokens` and
summed across the session (including every iteration of an agentic turn and across
mid-session model switches). It follows the **omit-until-present** doctrine
([ADR-0010](docs/adr/0010-data-producer-honest-omit.md)): the field appears **only
once hoosh actually reports usage** — never a `0` or `(n/a)` placeholder — and
`/state` carries an honest absent line until then. hoosh owns the count; thoth only
sums what it is told. 393 unit assertions (+13). Pin unchanged (6.2.43).

### Added
- **`hoosh_extract_usage`** (`src/hoosh.cyr`): pulls `usage.total_tokens` out of a
  response body (the blocking completion, or a streaming usage frame) as an int, or
  `-1` when absent — pure, unit-tested. The shared `_hoosh_usage_total` core lets the
  SSE callback read the figure from the value it already parsed (no double-parse per
  frame).
- **Session token tally** (`src/session.cyr`): `session_tokens` / `session_tokens_seen`
  / `session_add_tokens` — a running sum plus a seen-flag so "0 tokens" is
  distinguishable from "no usage yet"; only a real (`>= 0`) figure flips the flag, so
  an absent report never fakes presence. Cleared by `/reset`.
- **`tok <n>` in the TUI status bar** (`src/tui.cyr`) — shown after `turns`, **omitted
  entirely** until usage is seen.
- **`tokens` row in `/state`** (`src/commands.cyr`) — the running total once reported,
  else `(none reported yet — shows once hoosh returns usage)`.
- **`test_usage`** (+13): `hoosh_extract_usage` across a blocking body, a streaming
  usage frame (`choices:[]` + `usage`), a plain delta frame, a `usage` without
  `total_tokens`, and an unparseable body; the accumulator's sum / seen-flag / absent-
  report-ignored / `/reset`-clears semantics.

### Changed
- **Streaming requests carry `stream_options:{include_usage:true}`** (`hoosh_build_request`,
  `hoosh_build_messages`, `agent_build_request`) so the gateway appends a final usage
  frame to the SSE stream — without it a streamed turn carries no token count. The
  three streaming request-shape assertions ride forward.
- **`_hoosh_sse_cb`** now parses each frame once (was: delegating to
  `hoosh_extract_delta`, which re-parsed) and reads both the content delta and the
  trailing usage frame on the same pass.

### Notes
- The piped/CI floor stays clean: the status field is TUI-only and the `/state` row
  emits no escapes at T0 (verified: 0 escape bytes). The `/state` surface gains one
  honest row — a deliberate field addition, not a regression of existing output.
- Live hoosh round-trip (a turn returning a real `usage`) is a host-side step — the
  build sandbox blocks a compiled binary's TCP; the wire shape is covered by the unit
  tests.

## [0.10.1] - 2026-06-25

**Toolchain refresh to Cyrius 6.2.43.** Maintenance: the source pin moves `6.2.40 →
6.2.43` (`cyrius.cyml` + a `lib/` re-sync via `cyrius lib sync` — 67 floor modules), so
the pin matches the installed `cycc` again and the toolchain-drift warning is gone. **No
thoth source change** — 380 unit assertions pass unchanged on the new floor and x86_64
Linux builds + ships as before. The `run_capture` arity warning the older `cycc` surfaced
also cleared.

### Notes
- One **benign** build warning remains and is accepted: `lib/sandhi.cyr` calls
  `_sandhi_conn_open_v6_fully_timed_a` with 8 args (missing the TLS `ctx`) in the
  HTTP/**2** connection-promotion path (`_sandhi_http_try_h2_promote_a`). That path runs
  **only for pooled requests**; thoth issues one-shot `sandhi_http_post` /
  `sandhi_http_stream` with `opts = 0` (no pool), so it takes the HTTP/1.1 path and never
  reaches the call — unreachable from thoth at runtime. It is an upstream sandhi h2-path
  inconsistency (the promote call-site lags the 9-arg signature), not a thoth bug; `lib/`
  is vendored and never hand-edited. The hoosh/daimon live round-trip on 6.2.43 is a
  host-side step (the build sandbox blocks a compiled binary's TCP).

## [0.10.0] - 2026-06-25

**`/theme` — dark / light (M7).** A runtime color-theme switch over the existing
semantic-role surface: a theme axis now sits in front of the role color tables, so a
theme is just a different role→color mapping. `dark` is today's amber (byte-identical
default); `light` is the mockup's warm-light palette. Switch with `/theme dark|light` or
toggle with **⌃T** in the TUI; the active theme shows in the status bar and `/state`.
`rainbow` is announced as not-yet-available (it's a per-grapheme HSV render mode, not a
role table — it needs the anuenue lib vendored, a separate effort) — never faked. Opens
the **0.10.x arc** (themes + data producers). 380 unit assertions (+14). Pin unchanged
(6.2.40).

### Added
- **The theme axis** (`src/ui.cyr`): `_ui_rgb`/`_ui_idx256`/`_ui_code16` now branch on
  `_ui_theme` into `_dark` (the pre-0.10.0 values verbatim) and `_light` leaves;
  `ui_set_theme(t)` rebuilds the cached SGR table under the new theme while keeping the
  detected tier/depth; `ui_theme`/`ui_theme_name`/`ui_theme_from_name`. PT_PLAIN stays
  empty-string under any theme, so the piped/CI floor is byte-identical. `test_theme`
  (+12): the dark byte-identical anchor, the light palette, the T1 rebuild, and the
  PT_PLAIN floor under both themes.
- **`/theme` command** (`src/commands.cyr`) + the **⌃T** toggle (`src/tui.cyr`): bare
  `/theme` shows the active theme + choices; `/theme dark|light` switches; `/theme
  rainbow` honestly degrades. The status bar gains a `theme <name>` field and `/state` a
  `theme` row.

### Known limitations
- A theme switch re-colors the chrome (status bar, composer, tree) and all NEW output;
  existing feed lines keep their baked-in colors (the feed is a byte transcript) — run
  `/clear` for a fully re-themed window. At 16-color, `light` shares the dark codes (the
  named-color floor can't render warm-light hues). Each switch leaks ~390 B into the
  bump heap (bounded; switches are rare). rainbow is deferred (needs anuenue).

## [0.9.5] - 2026-06-25

**Version single-source + the TUI welcome banner + status-bar version.** Small polish
and infra ahead of the 0.10.x arc. The runtime version is now derived from one place —
the `VERSION` file — and the TUI gains the full scribe greeting + its version in the
status bar.

### Added
- **The full welcome banner in the TUI feed** — the alt-screen view now seeds the scribe
  greeting (sourced from the avatara persona, mirroring the line-REPL banner) instead of
  a one-line note: `<name>, <role> - {(o>` · the THOTH backronym tagline · `READY — type
  a task, or /help. Ctrl-X exits.`
- **The version in the status bar** — `{(o> thoth (<version>)  model …  turns …  surface
  …`, read from the single version source.

### Changed
- **Version is a single source of truth (`VERSION`).** New `scripts/gen-version.sh`
  generates `src/version.cyr` (`thoth_version()` — the one runtime copy) from the
  `VERSION` file; `scripts/build.sh` regenerates it before every build so it can't drift,
  and the generated file is committed so a raw `cyrius build` stays in sync. The banner,
  the `/state` build line, and the status bar all read `thoth_version()` — the previously
  scattered `"thoth X.Y.Z"` literals are gone. (`cyrius.cyml` already read `VERSION` via
  `${file:VERSION}`.) The per-release version sync is now: edit `VERSION`, run
  `gen-version.sh` (or build), bump the CHANGELOG header.

## [0.9.4] - 2026-06-25

**`/clear` + feed scrollback (M7).** Two quality-of-life additions to the T2 TUI, both
on the self-managed feed the 0.9.1 redraw model already provides. `/clear` empties the
content window; **Shift-↑/↓** (the non-mouse wheel fallback) and **PageUp/PageDown**
page back through the retained feed history (the ring keeps the last 2048 lines). A new
turn jumps back to the newest output. The REPL / piped / CI floor is unchanged. 366 unit
assertions (+4). Pin unchanged (6.2.40).

### Added
- **`/clear` command** (`src/commands.cyr`, `src/feed.cyr`): clears the content window.
  In the TUI (output captured, OUT_RING) it empties the feed ring (`feed_clear` — the
  post-dispatch repaint shows a clean window); in the line REPL on a real terminal it
  clears the screen; piped/CI it is a no-op so nothing leaks. Distinct from `/reset`
  (which clears the conversation *context*, not the screen). Listed in `/help` + the TUI
  slash palette.
- **Feed scrollback** (`src/tui.cyr`): **Shift-↑/↓** scroll a few lines (CSI `1;2A`/
  `1;2B`), **PageUp/PageDown** a screenful (CSI `5~`/`6~`), paging back into the ring's
  retained history (`feed_repaint` now honors `feed_scroll()`; `_tui_feed_scroll_by`
  clamps to the available history). Works in either focus (the tree keeps its own ↑/↓).
  Submitting a turn resets the scroll to the bottom so fresh output is always visible.

## [0.9.3] - 2026-06-25

**The togglable file-tree pane (M7).** A keyboard-navigated (no-mouse) inline
expand/collapse tree of the working directory, shown as a left column — the headline
of the M7 presentation arc, made possible by the 0.9.1 self-managed feed + escape-aware
clip. Toggle with **Ctrl-B**; **Tab** focuses it; **↑/↓** move, **→/←** expand/collapse,
**Enter** reads a file (or toggles a folder). The feed paints into the narrowed right
column; the tree paints the left. Kept portable — rooted at `$PWD` (no Linux-only
syscall), so `src/ftree.cyr` compiles for every target — and hidden by default, so the
REPL / piped / CI floor stays byte-identical. Adversarially reviewed pre-cut (4 lenses,
every finding verified): zero correctness/crash/floor/security findings. 362 unit
assertions (+21). Pin unchanged (6.2.40).

### Added
- **`src/ftree.cyr` — the file-tree pane.** A PURE, unit-tested core: the layout
  geometry (`tui_tree_w`/`tui_feed_left`/`tui_feed_width` — tree `[1, tree_w]`, a `│`
  separator, feed `[tree_w+2, cols]`; all collapse to a full-width feed when hidden) and
  the flattened-tree model (`ftree_move`/`ftree_collapse_at` + the splice on expand +
  `ftree_path`, which reconstructs a node's absolute path by walking ancestors). Plus the
  I/O listing (`ftree_load`/`ftree_expand` via `lib/fs.cyr` `dir_list`/`is_dir`,
  dirs-first, rooted at `$PWD`). `test_ftree` (+21): geometry, the splice/collapse
  mechanics, ancestor-walk paths, and a real `src/` listing smoke.
- **The two-column TUI** (`src/tui.cyr`): `feed_repaint` paints the feed into the right
  column via the 0.9.1 escape-aware clip; `tui_draw_tree` paints the tree (dir blue /
  file muted, the selected row a reverse-video bar) + the separator. New keys
  (Ctrl-B / Tab / ↑ / ↓) and a focus model (`_tui_focus`); the terminal cursor stays on
  the composer during tree nav (the bar is the tree's selection). Hidden by default.

### Changed
- **Enter on a file reads it immediately and keeps focus on the tree** (so you browse
  file-to-file without the composer stealing focus). The read runs through the normal
  capture/dispatch path, so its output lands in the feed.

### Known limitations (→ later)
- The tree caps at 256 visible nodes; beyond that it truncates (rare in practice; no
  alphabetical sort within the dirs-first grouping yet). An empty expanded folder shows
  the `▾` marker with nothing under it.

## [0.9.2] - 2026-06-25

**Instant SIGWINCH resize + the working spinner + incremental streaming paint (M7).**
The second course on the 0.9.1 self-managed feed: now that thoth owns the feed, a
terminal resize is a pure recompute+repaint, the streamed response paints as it
arrives, and a "working" indicator shows during a turn. Built entirely on the
vendored darshana substrate (signalfd) + the stdlib epoll wrappers — no hand-rolled
floor. The REPL / piped / CI floor stays byte-identical (the streaming hook no-ops off
the TUI; `_out_mode` defaults to OUT_FD1). Adversarially reviewed pre-cut (4 lenses,
every finding verified against the code): zero correctness/hang/crash/floor/security
findings. 341 unit assertions (+4). Pin unchanged (6.2.40).

### Added
- **Instant SIGWINCH resize** (`src/tui.cyr`): the bare blocking key-read is replaced
  by an **epoll multiplex** of stdin + a SIGWINCH signalfd (`tty_open_signalfd(
  TTY_SIGMASK_WINCH)`, `sys_epoll_create`/`_ctl`/`_wait`). Idle, the loop blocks in
  `epoll_wait`, so a resize wakes it **instantly** — not on the next keystroke (the
  0.9.1 limitation) — and `tui_relayout` recomputes geometry + full-repaints at the new
  size. A resize during a blocking dispatch queues on the level-triggered signalfd and
  is serviced on return (an accepted gap). Where epoll/signalfd are absent the loop
  falls back to the 0.9.1 blocking read (no instant resize) — degrade closed.
- **Incremental streaming paint** (`src/tui.cyr`, `src/feed.cyr`): `feed_repaint` now
  renders the **unsealed pending line** (an in-progress streamed response, no newline
  yet) as a virtual bottom row, and the new `feed_stream_tick` — pinged from the hoosh
  and agent SSE callbacks on each chunk — repaints it so a streaming turn renders **as
  it arrives** in the TUI (it was captured-but-not-shown-until-completion in 0.9.1).
  Off the TUI (OUT_FD1) the tick is a no-op (the chunk's `emit` already wrote live), so
  the REPL stream is byte-identical.
- **The working spinner** (`src/tui.cyr`): a braille indicator (`spin_glyph`, +
  `spin_advance`/`spin_begin`/`spin_end`/`spin_paint`) on the hint row for the dispatch
  window. The main loop is blocked inside `dispatch()` during a turn, so the only
  in-dispatch heartbeat is the SSE callback: a **streaming** turn animates the spinner
  per chunk; a **blocking** turn / `/run` holds the same glyph still — honest, never
  faked motion. Suspended across an interactive gate confirm (which owns the
  composer/hint rows) and resumed after. `test_spinner` (+4): the pure frame cycle.

### Fixed
- **The SIGINT signalfd is now closed on teardown** — `tty_open_signalfd(SIGINT)` was
  opened-and-forgotten since 0.9.0, leaking the fd and leaving SIGINT blocked on the
  thread after exit. `tui_events_teardown` now closes both signalfds (restoring the
  signal mask) and the epoll fd on every exit path.

### Known limitations (→ 0.9.3)
- The togglable **left-column file-tree pane** is next (the self-managed feed + the
  escape-aware clip are its prerequisites, both in place since 0.9.1). No
  scrollback-scroll keys yet (the feed pins to the newest screenful).
- SIGWINCH during a blocking dispatch repaints on dispatch return, not mid-turn;
  the cursor may flicker through the feed rows during a streaming repaint (cosmetic).

## [0.9.1] - 2026-06-24

**The self-managed feed-redraw model (M7).** The T2 TUI's feed stops relying on the
DECSTBM terminal-scroll trick and becomes thoth-owned: dispatch output is captured
into a line ring (`src/feed.cyr`) and the visible window is PAINTED each frame. This
is the foundational change the rest of M7 needs — a togglable left-column file-tree
pane (0.9.3) and instant SIGWINCH resize (0.9.2) are only possible once thoth owns the
feed content (DECSTBM sets only top/bottom margins, so terminal-native scroll always
spans the full width). The capture mechanism is a **surface-routed output sink** — no
fd-1 redirection, which would have forked the floor (AGNOS has no `sys_dup2`) and
broken the interactive gate confirm — so the REPL / piped / CI floor stays
byte-identical (a golden `/help`+`/state`+`/seams` diff is unchanged across the
206-site rename) and the t-ron confirm stays answerable. Adversarially reviewed
pre-cut (5 lenses, every finding verified against the code): zero
correctness/crash/floor/security findings. 337 unit assertions (+42). Pin unchanged
(6.2.40).

### Added
- **`src/feed.cyr` — the self-managed feed ring + escape-aware clip.** A ring of 2048
  lines × 2 KiB (one 4 MiB bump alloc) capturing dispatch output, sealed per newline
  (the `\n` not stored — the painter supplies row breaks), evicting the oldest in O(1)
  when full. The load-bearing PURE primitive is
  `feed_clip(dst, dst_cap, src, src_len, max_cols)`: it paints a stored line into a
  width-W column, passing ANSI color escapes through verbatim (zero width), never
  severing a CSI or a UTF-8 glyph, **suppressing `ESC[…K`** (which would erase to the
  physical EOL and scribble a neighbour column), appending a defensive reset if a
  color span is left open at the clip point, and never writing past `dst_cap`.
  Store-time truncation is escape-boundary-aware (a slot never ends mid-escape).
  `test_feed` / `test_feed_ring` (+31): the clip width/escape/`dst_cap`/`ESC[K`/UTF-8
  cases and the ring seal/evict/flush machine.
- **The output-capture sink** (`src/util.cyr`): `_out_mode` (OUT_FD1 default /
  OUT_RING), `emit`/`emit_n` gain a one-line branch routing to `feed_write` when
  capture is armed, `emit_raw`/`emit_raw_n` ALWAYS reach fd 1 (the chrome + painter
  use these, structurally immune to OUT_RING self-recursion), and `oprintln`/`ofmt_int`
  shadow the stdlib `println`/`fmt_int` (which bypass `emit` and write fd 1 directly) —
  byte-identical to their twins under OUT_FD1, captured under OUT_RING. `test_capture`
  (+11): mixed-call logical-line reconstruction + shadow byte-identity (incl. zero and
  negatives).
- **The self-managed painter** (`src/tui.cyr`): `feed_repaint` paints the newest feed
  lines into the feed band each frame (via `emit_raw`, so it is safe even while capture
  is armed); `tui_run_line` arms capture around the dispatch window, echoes the
  submitted command immediately, and repaints on return; the DECSTBM scroll region is
  gone. A welcome line seeds the feed at launch.

### Changed
- **The dispatch tree routes through the capture sink** — a mechanical rename of
  `println`/`fmt_int` to the mode-aware `oprintln`/`ofmt_int` across the 9 dispatch
  files (206 sites). Verified overload-safe (thoth source carries no `: i64`
  annotations, so cyrius's `println(i64)→println_int` overload can't fire) and
  byte-identical on the floor (the golden diff is unchanged).
- **The t-ron gate confirm** (`src/gate.cyr`) brackets back to the live screen when
  capture is armed (`tui_confirm_begin`/`tui_confirm_end`): it seals + repaints the
  dispatch output so far (so the user sees e.g. the `/write` diff), then drops to
  OUT_FD1 with the cursor on the composer row so the prompt and its cooked y/N echo are
  VISIBLE rather than buried in the ring, then resumes capture. The REPL/piped path
  (OUT_FD1) skips the bracket entirely — fail-closed semantics and byte output
  unchanged (verified: piped `/write` and `/run` deny/allow paths intact).

### Known limitations (→ 0.9.2 / 0.9.3)
- **Streamed SSE output is not painted incrementally** in the TUI — it is captured and
  appears when the turn completes (the line REPL still streams live). Incremental paint
  lands with the spinner in 0.9.2 (both ride hoosh's per-chunk callback).
- **Instant SIGWINCH resize** and the **working spinner** are 0.9.2; the **togglable
  file-tree pane** is 0.9.3 — the self-managed feed is their prerequisite, now in place.
- **No scrollback-scroll keys yet** — the feed pins to the newest screenful (the ring
  retains 2048 lines for when scroll keys land). Diff-row background tint covers the
  text width, not the full row, in the captured feed (`ESC[K` is suppressed).

## [0.9.0] - 2026-06-24

**The T2 rich-TUI front-end (M7).** thoth gains an interactive alt-screen TUI — a
pinned status bar, a scrolling feed, a raw-mode composer with line editing, a
slash-command palette, and keybinding hints: the jump from a colored REPL to a TUI
app. It activates only at the T2 tier on a real terminal (`THOTH_TIER=rich`); the
line-mode REPL stays the guaranteed fallback for pipes / CI / lower tiers (piped
output byte-identical). Built on the vendored darshana TTY substrate. The new module
was adversarially reviewed (4 issues found, all fixed) before this cut.

### Added
- **`src/tui.cyr` + vendored `src/vendor/darshana.cyr`** — the alt-screen T2 layout:
  - **Pinned status bar** (`{(o> thoth · model · turns · surface`), **togglable with
    Ctrl-G** (keyboard, no mouse — the feed reclaims the row when hidden).
  - **Scrolling feed** (a DECSTBM scroll region); the composer clears the instant you
    press Enter, so the sent line moves into the feed and the response streams below.
  - **Raw-mode composer** — a line editor (insert / Backspace / ←→ / Home/End / Ctrl-U)
    with horizontal scroll so long lines never wrap onto the chrome.
  - **Slash-command palette** — a live-filtered command list on the hint row while you
    type a `/command` token.
  - **Exit**: `Ctrl-X` (the clean, signal-free close) or `Ctrl-C` fallback or `/quit` —
    all restore the terminal (cooked + scroll region + alt-screen) cleanly. (A real
    stdin EOF — terminal closed — also exits.)
  - Detection: `THOTH_TIER=rich` + a real tty → PT_RICH → the TUI; else the REPL.
  - Pure pieces unit-tested (`test_tui`, +25): line-editor state machine, geometry,
    palette matchers.

### Fixed (pre-cut adversarial review of src/tui.cyr)
- **SIGINT can no longer garble the terminal** — Ctrl-C during the cooked-mode dispatch
  window (a slow `/task` / `/run` / `/call`) raised an unhandled SIGINT that killed
  thoth with the alt-screen still up. SIGINT is now blocked for the TUI session.
- **Composer can't scribble the chrome** — long lines are clamped to the visible width
  with a horizontal-scroll window.
- **Raw-mode re-entry after dispatch is checked** — a failed re-raw ends the session
  cleanly instead of spinning half-cooked.

### Known limitations (→ 0.9.1)
- **Mid-session resize** redraws on the next keystroke / submit / toggle, not the
  instant the terminal changes size (SIGWINCH handling lands with the file-tree pane).
- **The file-tree pane** is not yet present — it needs the feed-buffer redraw model.

## [0.8.6] - 2026-06-24

**Diff row background tint (M7 Phase 2d).** Add/del diff rows now carry a subtle
background tint — green for additions, red for deletions — with the syntax-highlighted
code on top, completing the mockup's diff card. Only at 256-color and up; degrades to
the gutter-only style at 16-color and to plain bytes when piped (byte-identical floor).

### Changed
- **Tinted diff rows** — `_diff_emit_line` sets a per-row background (`ui_bg`), uses
  fg-only resets (`ui_reset_fg` → `ESC[39m`) so the tint survives the colored spans,
  and fills the row to its end (`ui_eol` → `ESC[K`) before a final full reset. New
  `ui_bg` / `ui_eol` / `ui_reset_fg` surface accessors + a bg-escape builder. T0 /
  16-color / context rows are untinted, so piped/CI output is unchanged.

## [0.8.5] - 2026-06-24

**Syntax-highlighted diff bodies (M7 Phase 2c).** The colored diff card now
syntax-highlights the line bodies too — keywords amber, strings green, and the rest —
sharing the SAME coverage-guarded highlighter `/read` uses (`_hl_span`), so no byte is
dropped or reordered. The green `+` / red `−` gutter + faint line numbers carry the
add/del signal; the grammar is auto-detected from the file path. Plain when piped.
(The mockup's per-row background tint is left as future polish.)

### Changed
- **Diff line bodies are syntax-colored** — `diff_render` detects the grammar from the
  path and tokenizes each line via vyakarana; context / add / del bodies all render in
  token colors with the structural gutter on top. T0 and unknown-language fall back to
  the plain body.
- **One shared highlighter** — `_hl_span` + `_tok_role` moved into `src/diff.cyr`, so
  `/read` and the diff bodies use a single tested, coverage-guarded path instead of two.

## [0.8.4] - 2026-06-24

**Syntax highlighting via vyakarana (M7 Phase 2b).** `/read` now renders source files
syntax-colored — keywords amber, strings green, numbers/preprocessor blue, comments
faint, operators muted — through the T1 surface, plain when piped. Consumes the
vendored vyakarana tokenizer (no hand-rolled highlighter), and the rendering is
coverage-guarded so the FULL file is always shown verbatim, only colored.

### Added
- **Vendored `src/vendor/vyakarana.cyr`** (2.2.3) — the AGNOS source-code tokenizer
  (45 grammars incl. Cyrius; 10 stable token kinds). Clean integration: no symbol
  collisions, all of its stdlib deps already present in thoth.
- **`/read` syntax highlighting** — `detect_language(path)` → `tokenize_stream_*` →
  token kind mapped to a color role (`_tok_role`). Unknown languages / the plain tier
  fall back to verbatim. A cursor guard emits any uncovered gap + trailing bytes plain,
  so highlighting never drops or reorders a byte (verified: highlighted-then-stripped
  equals the file exactly). The `/read` header is colored too (path blue, frame faint).
  `test_highlight` (+7).

## [0.8.3] - 2026-06-24

**Diff producer + colored hunks (M7 Phase 2).** `/write` now reads the old file and
renders a colored old→new diff before committing — the first step from *formatting*
into a real *capability* (the first diff DATA thoth produces). An adversarial 3-lens
review (memory / LCS-correctness / edge+integration, each finding double-verified)
cleared the engine and caught two honesty-contract gaps, both fixed before this cut.

### Added
- **`src/diff.cyr`** — a bounded (256-line) LCS line-diff: `diff_render` (the colored
  card: green `+` add / red `−` del / faint context, line numbers, blue path header,
  green/red `+A −D` counts, through the T1 surface — plain when piped) + the pure
  `diff_stats` (add/del counts). Reused buffers, no per-call accretion; an over-cap
  input summarizes honestly rather than running away. `test_diff` (+7).
- **`/write` shows the diff** of the proposed change (old on disk → new content)
  after the t-ron gate and before the write; path / denied / wrote lines colored.

### Fixed
- **Newline-aware line identity** — a line ending in `\n` no longer compares equal to
  one that doesn't, so rewriting a file that lacked a trailing newline is shown as a
  real change (was `+0 −0` while the committed bytes changed). The card never
  under-reports what is written.
- **Old-file truncation is announced** — an old file over 64 KB is no longer silently
  diffed against a truncated copy; `/write` prints `(old file > 64KB — diff skipped)`
  (degrade-closed, announced — never a fake).

## [0.8.2] - 2026-06-24

**Color breadth — the rest of the core views (M7 Phase 1b).** Extends 0.8.1's
palette to the remaining surfaces, all through `src/ui.cyr`'s semantic roles at T1.
Still no new substrate; output stays **byte-identical when piped/CI** (verified: 0
escape bytes across `/help` + `/state` + `/seams`; `/help` column alignment intact).

### Changed
- **`/state`** — labels faint, model + build version accent, seam `absent` states
  faint, `parallel` / live surface tier green, status notes muted.
- **`/help`** — command tokens in accent amber, descriptions muted (alignment
  preserved exactly).
- **`/models`** + **`/models <provider>`** — header accent, the active routing
  target marked with a green `*` and its id in accent, other ids in the warm fg.
- **`/tools`** — header accent, tool names accent, descriptions muted.
- **Turn lines** — the `-> hoosh (…)` / `-> daimon …` request lines dim the framing
  to faint and lift the model/tool name to accent.
- New surface helper `ui_emit_n(role, ptr, n)` for `Str` (ptr,len) spans.

## [0.8.1] - 2026-06-24

**Design-palette color across the core surfaces (M7 Phase 1a).** First visible step
of the 0.8.x design arc: the banner, `/seams`, the agent loop's tool-call/result
lines, and the t-ron gate verdicts now render through the semantic color roles
(`src/ui.cyr`) at T1 — the warm amber palette from the mockup. Still pure T1 (no new
substrate); output stays **byte-identical when piped/CI** (every role resolves to the
empty string on the T0 floor — verified: 0 escape bytes piped).

### Changed
- **Banner** — persona name/role + `thoth` brand in accent amber, tagline muted.
- **`/seams`** — the live capability ladder is colored: seam names accent, binding
  mode green (wired) / faint (absent), capability effect green (full) / amber
  (degraded) / red (absent) — so "degrade closed" is now visible (t-ron reads
  `absent` binding in gray but `degraded` effect in amber).
- **Agent loop** — `tool-call:` lines color the tool name accent + args muted;
  `result:` label faint.
- **t-ron gate** — `allow` green, `DENY` red, `FLAG` + the fail-closed confirm
  prompt amber.
- New surface helpers `ui_emit(role, s)` / `ui_label(s)`.

## [0.8.0] - 2026-06-24

**Presentation surface — the render foundation (M7 Phase 0).** Opens the **0.8.x
arc** that brings thoth's front-end toward the warm-amber agentic-IDE design
([ADR-0009](docs/adr/0009-presentation-capability-ladder.md)). Presentation is now a
capability tier — **T0 plain → T1 ANSI → T2 rich-TUI → T3 desktop** — resolved once
at startup and degrading **closed**: output is byte-identical to 0.7.2 when piped/CI,
and the `{(o> ` prompt is the T0 floor.

### Added
- **`src/ui.cyr` — the render surface.** A tier model + startup detection (`isatty`
  via `ioctl` + `TERM`/`COLORTERM`/`NO_COLOR`, with a `THOTH_TIER` override; degrades
  closed to plain when color can't be proven) + a **semantic color-role API**
  (`ui_sgr(ROLE_*)` / `ui_reset()`) so feature code never hardcodes an escape:
  empty strings at T0, the design's exact amber palette (`#e6ab5c`, truecolor → 256 →
  16) at T1. The active tier is announced in `/state` (`surface : …`). `test_ui`
  (+12): the T0 floor emits no escapes; T1 produces the exact amber SGR; 256-color
  fallback maps the accent to its cube index.
- The `{(o> ` prompt now wears the accent role — the first surface call-site, and
  byte-identical on the T0 floor.

## [0.7.2] - 2026-06-24

### Changed
- **REPL prompt** is now `{(o> ` (was `thoth> `).

## [0.7.1] - 2026-06-24

**`/models <provider>` — drill into a provider's switchable models.** `/models`
lists the providers hoosh routes to; previously there was no way to see the actual
model ids to switch to. Pairs with **hoosh 2.4.9**, which adds the per-provider
catalog endpoint.

### Added
- **`/models <provider>`** lists the concrete, switchable model ids a provider
  offers (e.g. `/models anthropic` → `claude-opus-4`, `claude-sonnet-4`,
  `claude-3.5-haiku`, …), marking the active routing target. Consumes hoosh's
  `GET /v1/models/catalog` (`{object:list, data:[{id, owned_by}]}`) and filters on
  `owned_by` with a case-insensitive match, so `/models Anthropic` works too. Bare
  `/models` (the provider list) is unchanged. An unknown provider degrades honestly
  ("no models for 'X' — run /models …"), as does an older hoosh without the catalog
  endpoint (404 → a one-line "needs hoosh >= 2.4.9" note). `test_provider_catalog`
  (+9): catalog parse, owned_by filter, case-insensitive provider match.

## [0.7.0] - 2026-06-24

**Parallel tool execution, `/audit` tool-rounds, and a security-hardening pass.**
The floor blockers a prior note recorded as "HELD/UNSAFE at 6.2.37" are repaired: the
toolchain bump to Cyrius **6.2.40** carries sandhi **1.6.13** (per-dispatch arena
context) and bayan **1.0.3** (per-call parser state), so parallel tool calls land on
by default. An audit-driven hardening pass then closed six model-controlled heap
overflows. Pin **6.2.40**; 235 unit assertions pass (+14).

### Added
- **Agentic tool-round trace in `/audit`** (new module `src/roundlog.cyr`). The
  agentic loop runs up to `AGENT_MAX_ITERS` rounds per turn, each a batch of gated
  tool calls. t-ron's libro chain (the existing `/audit` view) is the canonical
  *security* record — flat, newest-first. `/audit` now also surfaces the orthogonal
  *loop-structure* view: a session-local ring (last 16 rounds) of recent tool
  rounds, grouped — each line shows `turn N, round R (K calls): [allow|deny|noname]
  <tool> ok|err, …`. It owns no security logic and never touches t-ron's chain, so
  it renders even when the t-ron seam is absent (the loop runs under the
  fail-closed confirm gate regardless). Recorded by `_agent_run_calls` /
  `agent_turn`, rendered by `cmd_audit` (both branches), cleared by `/reset`.
  `test_roundlog` (+22 assertions): recording, accessors, per-round cap, ring
  eviction.

### Added — parallel tool execution
- **A round's tool calls now run concurrently** (`[hoosh].parallel`, on by default;
  a single-call round or `parallel = false` takes the serial path). Phased so the
  security path stays serial: Phase 1 (main thread) snapshots each call and runs the
  t-ron gate in order — the libro audit chain is hash-linked, so gating must not
  race; Phase 2 fans the ALLOWED calls across OS threads, each worker doing ONLY the
  network (`daimon_fetch_into`) on its own arena + request/response buffers over a
  fresh connection — the reentrant shape sandhi 1.6.13 certifies; Phase 3 (main
  thread, in call order) parses each raw body with bayan and appends results, so
  bayan never runs concurrently (its value parser is not thread-safe). If
  `thread_create` is unavailable (Windows/AGNOS) or a slot arena cannot be
  allocated, the call runs inline — correct, just serial.

### Security
- **Bounded request assembly closes six confirmed model-controlled heap overflows.**
  Every builder that writes LLM- or MCP-controlled text into a fixed buffer
  (`daimon_build_call`, `_ag_build_array`, `agent_format_tools`, `agent_build_request`,
  and the hoosh request builders) now writes through bounded `_append_cstr_cap` /
  `_json_escape_into_cap` helpers, so an oversized tool name/arguments or daimon tool
  registry truncates in-buffer instead of overrunning the heap (`load8`/`store8` are
  unchecked — an overrun is silent corruption). The parallel path was already bounded.
  `test_bounds_hardening` (+7, canary-guarded).
- **Oversized tool arguments are uniformly refused** on both the serial and parallel
  paths (`AGENT_ARGS_MAX`) with a result the model can react to, and the parallel path
  now gates on the FULL payload — so t-ron never scans a clipped argument string and no
  truncated/malformed body is ever sent to daimon.

### Changed
- **Tool registry fetched once per session, not per turn** — the agentic loop now
  caches the daimon registry GET + bayan parse + re-serialize (it is session-stable),
  retrying only if the first fetch failed so a transient daimon-down is not sticky.
- **Banner/`/state` version** — `src/session.cyr` startup banner and
  `src/commands.cyr` `/state` build line ride forward to `0.7.0`.

## [0.6.7] - 2026-06-23

**Cross-target re-verification of the 6.2.37 floor — and the getrandom root cause.**
After 0.6.6 pinned 6.2.37, `./scripts/build.sh all` was re-run on x86_64 Linux to
re-verify every lane. Two symbols the gated lanes hit turned out to be **fixable
upstream bugs, not capability gaps** — the earlier instinct to bucket them as
permanent "known gaps" was wrong and is corrected here.

- **Windows `SYS_GETRANDOM` was a patra bug — fixed, not a Win32 gap.** Windows
  HAS a CSPRNG: `bcryptprimitives!ProcessPrng`, wired as the `sys_getrandom()` peer
  wrapper. patra's `_wal_gen_salts` drew its WAL salts via a raw
  `syscall(SYS_GETRANDOM,…)` — a Linux-shaped call the Windows peer deliberately
  omits the constant for — so `cyrius build --win` failed to link. **Fixed in patra
  v1.12.4** (`src/wal.cyr`, `#ifdef CYRIUS_TARGET_WIN` → `sys_getrandom()`); patra
  now builds `--win` and its 834 Linux tests still pass. thoth's `--win` lane clears
  the moment the toolchain re-bundles patra ≥1.12.4.
- **AGNOS's old `SYS_LSEEK` blocker is RESOLVED upstream.** The 6.2.37 agnos peer
  now defines `SYS_LSEEK = 58` (+ `SYS_GETRANDOM = 45`), closing the filed
  `agnos/.../2026-06-16-cyrius-patra-lseek-syscall-gap.md`. The lane now gates on
  **`SIGHUP`** — and that is **not** "agnos has no signals": the agnos peer already
  ships `SYS_SIGPROCMASK=17`/`SYS_SIGNALFD=18` (signal infra DONE), it merely omits
  the signal-NUMBER constants the other peers define, so t-ron's `sighup_init` can't
  resolve the bare `SIGHUP`. A fixable floor gap, **filed**:
  `agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md`.
- **aarch64 Linux** re-confirmed building — `build/thoth_aarch64` is a valid static
  ARM ELF (exec-format error on the x86 host confirms it's genuinely cross).
- **macOS** not re-run at 6.2.37 (native Mach-O needs the Mac host); last verified
  0.6.4.

### Changed
- **`scripts/build.sh`** — gap set split into `ARCH_GAP` (genuine, permanent Win32
  differences: `SYS_FUTEX`/epoll, no raw-syscall equivalent) and `TRANSIENT_GAP`
  (`SYS_GETRANDOM`, `SIGHUP` — fixable, fixed-or-filed upstream, present only while
  the vendored snapshot lags; each tagged for deletion on toolchain pickup). The
  resolved `SYS_LSEEK` entry was dropped. Per-lane header comments corrected to stop
  calling getrandom a Win32 gap.
- **Banner/`/state` version** — `src/session.cyr` startup banner and
  `src/commands.cyr` `/state` build line ride forward to `0.6.7`.
- **Targets table + cross-target narrative** in `docs/development/state.md` and
  `roadmap.md` rewritten to separate fixable-transient symbols from architectural
  gaps.

### Upstream (fixed/filed while cross-verifying — not in this repo)
- **patra v1.12.4** — `src/wal.cyr` Windows getrandom fix (`~/Repos/patra`; dist
  regenerated, CHANGELOG + VERSION bumped).
- **Filed** `agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md`
  — the agnos syscall peer needs its signal-number enum (`SIGHUP`, …).

## [0.6.6] - 2026-06-23

**Toolchain refresh to Cyrius 6.2.37.** The source pin moves 6.2.15 → **6.2.37**
(`cyrius.cyml` + a `lib/` re-sync via `cyrius lib sync` — 98 floor modules, two
new snapshot modules pulled in: `protobuf` and `yantra`; no thoth source change),
clearing the toolchain-drift warning. 199 unit assertions pass (unchanged) under
the new pin; x86_64 Linux builds and ships as before. (Cross-target re-verification
of the new floor — and the getrandom/SIGHUP findings it surfaced — landed in 0.6.7.)

### Changed
- **`cyrius.cyml`** — `[package].cyrius` pin `6.2.15` → `6.2.37`; `lib/` re-synced
  to the pin via `cyrius lib sync` (98 modules; `protobuf.cyr` + `yantra.cyr` new;
  floor-only churn, no source change).
- **Banner/`/state` version** — `src/session.cyr` startup banner and
  `src/commands.cyr` `/state` build line ride forward to `0.6.6`.

## [0.6.5] - 2026-06-16

**M6 capability ladder — the full / degraded / absent dimension.** The seam
registry already reported each spine seam's **binding mode** (native /
remote-client / absent — *how* it's reached). This release adds the second,
orthogonal dimension the M6 ladder owed: the **capability effect** (full /
degraded / absent — *what the user actually gets*), and the two cannot be inferred
from each other. A seam can be `absent` at the binding layer yet `degraded` (not
`absent`) at the capability layer when thoth stands a fail-closed fallback in its
place — the whole point of "fails closed, announced, never faked" lives in that
gap. The defining case is **t-ron**: its binding goes `native → absent`, but its
capability effect goes `full → degraded` (the built-in confirm gate), never to
`absent`. There is no reachable state in which an action is silently allowed.

The ladder is **computed, not narrated**: `seam_cap_state(id)` resolves the effect
from the live binding status, so `/seams` and the binary can't drift from the doc.
`/seams` now renders both dimensions per seam plus the live effect line. 199 unit
assertions (+12). Toolchain pin unchanged (Cyrius 6.2.15).

### Added
- **Capability-effect dimension** in `src/seams.cyr`: `CapState`
  (full/degraded/absent), `seam_cap_state` (derives effect from live binding
  status; t-ron special-cased to degrade closed, never absent), `seam_cap_full`
  (what FULL delivers) and `seam_cap_fallback` (the degraded/absent stand-in), plus
  `cap_state_label`.
- **[architecture note 002](docs/architecture/002-capability-ladder.md)** — the
  binding-mode × capability-effect invariant, the per-seam ladder table, and the
  "computed, not narrated" enforcement rule.
- **`test_capability_ladder`** in `tests/thoth.tcyr` — asserts the effect states
  (vendored seams full; hoosh/daimon absent unconfigured; t-ron degrades closed)
  and the fallback semantics. +12 assertions (199 total).

### Changed
- **`/seams`** now renders two dimensions per seam — `[binding] [effect] domain`,
  then the live effect line (what FULL delivers, or the degraded/absent stand-in) —
  with a closing note that security degrades CLOSED.

## [0.6.4] - 2026-06-16

**Toolchain refresh to Cyrius 6.2.15 — and aarch64 Linux joins the build matrix.**
The source pin moves 6.1.38 → **6.2.15** (`cyrius.cyml` + a `lib/` re-sync via
`cyrius lib sync` — 97 floor modules, no thoth source change), clearing the
toolchain-drift warning. The headline: the **aarch64 Linux** lane now **builds a
binary** (`build/thoth_aarch64`, a valid statically-linked ARM ELF). It had been
staged-blocked on a cycc `#pure`/aarch64 pass-1 scanner bug; that fix landed
upstream in **Cyrius v6.2.2**, so the lane lights up with zero thoth change — the
"port the floor; never fork the spine" posture paying off exactly as designed.

The remaining cross targets stay honestly gated, each on a named upstream floor
gap surfaced (not faked) by the build driver:
- **AGNOS** — still blocked on `SYS_LSEEK` (the patra audit-store seek). Now
  **filed upstream**: `agnos/docs/development/issues/2026-06-16-cyrius-patra-lseek-syscall-gap.md`.
  A second gap (`SYS_FUTEX`, patra's mutex) sits behind it.
- **Windows** — the 6.2.15 floor surfaces `SYS_FUTEX` first (patra's mutex; Windows
  uses `WaitOnAddress`, no raw-syscall equivalent), behind it the sandhi/epoll gap.
  `scripts/build.sh` now recognizes `SYS_FUTEX` as a sanctioned best-effort gap so
  the lane warns cleanly instead of reading as a regression.

**macOS builds and runs natively on Apple Silicon (verified).** Built on a macOS
arm64 host (Cyrius emits Mach-O there; cross-emit from Linux is not the path),
`./scripts/build.sh macos` produces `build/thoth_macos` (Mach-O arm64), and it
launches the REPL and exits cleanly. **Caveat, honestly flagged:** cycc emits ~86
"syscall not routed by the Mach-O ARM translation (ESYSXLAT/__got)" warnings — the
`var SYS_*; syscall(SYS_*,…)` first-arg-doesn't-const-fold reroute miss (upstream
cyrius issue `2026-06-16-var-syscall-number-defeats-macho-pe-reroute`). The basic
driver path is unaffected, but patra's `lseek`/`futex` calls (the t-ron audit
ledger) will **fault at runtime** when a `[tron].policy` is configured, until that
cycc fix lands. So macOS is "builds + runs, audit path gated upstream."

187 unit assertions pass (unchanged) under the new pin; Linux ships as before.

### Changed
- **`cyrius.cyml`** — `[package].cyrius` pin `6.1.38` → `6.2.15`; `lib/` re-synced
  to the pin (floor-only churn, no source change).
- **`scripts/build.sh`** — aarch64 documented as a building lane (gap closed in
  Cyrius v6.2.2); `SYS_FUTEX` added to the sanctioned `KNOWN_GAP` set so the
  Windows/AGNOS best-effort lanes warn on it instead of failing as a regression;
  header target notes refreshed (AGNOS lseek issue now filed).

### Fixed
- **Banner/`/state` version drift** — two hardcoded `thoth 0.6.3` strings
  (`src/session.cyr` startup banner, `src/commands.cyr` `/state` build line) had
  fallen behind the `VERSION` file. Surfaced by the macOS smoke test (the running
  binary announced a stale version). Now kept in sync with `VERSION` as part of the
  per-release version-sync step (they ride forward to the current release number).

## [0.6.3] - 2026-06-12

**Multi-target builds begin (M6): Linux first, honestly.** thoth is OS-agnostic
at the substrate layer — one source tree, the target picked at build time. This
slice makes that real: `scripts/build.sh` is the single build driver that fans
the source to targets (`linux` | `agnos` | `all`), and **x86_64 Linux is a
named, first-class target** (`build/thoth`), built and tested exactly as before.
The **AGNOS** target is wired and staged but does **not link today** — and this
is announced, not faked: thoth's t-ron audit chain persists through libro's
patra store, and patra's `_pt_seek` needs `SYS_LSEEK`, which the AGNOS syscall
floor (`syscalls_x86_64_agnos.cyr`) lacks across Cyrius 6.1.38 → 6.2.0 (present
on linux/macos/windows/aarch64). That gap is upstream in the Cyrius stdlib, not
thoth; the AGNOS lane lights up with zero thoth changes once the floor gains
`lseek`. The build machinery itself changed no source logic. Toolchain pin
unchanged (Cyrius 6.1.38).

**Also in 0.6.3 — real per-tool argument schemas reach the model.** The agentic
loop advertised daimon's MCP tools to hoosh with a permissive
`"parameters":{"type":"object"}` guess, because daimon's manifest omitted the
input schema it stored (thoth filed that gap as daimon issue
`2026-06-11-mcp-manifest-omits-tool-input-schema`). **daimon 1.2.7** now emits
`inputSchema` per tool in `GET /v1/mcp/tools`, so thoth passes it through verbatim
as `function.parameters` — the backing model now sees each tool's real argument
shape instead of a guess, the last gap blocking high-fidelity model-driven tool
calling. 187 unit assertions pass (+1).

### Added
- **`scripts/build.sh`** — the multi-target build driver. `linux` (default) →
  `build/thoth`; `agnos` attempts `cyrius build --agnos` and surfaces the real
  result (the honest `SYS_LSEEK` block today, `build/thoth_agnos` once the floor
  catches up); `all` builds Linux (the release gate) then attempts AGNOS without
  letting the known block fail the run. The target matrix and its honesty live in
  the script header.
- **[ADR-0008](docs/adr/0008-multi-target-builds.md)** — records the multi-target
  posture (one source tree, target at build time), ships Linux, and documents the
  AGNOS block (cause, dependency chain, and the rejected alternatives: forking the
  floor, cutting the audit chain, or silently omitting AGNOS).
- **Target matrix in `state.md`** — per-target status (Linux shipped; AGNOS
  staged/blocked-upstream; aarch64/macOS/Windows future) with the `SYS_LSEEK`
  cause spelled out.
- **1 new unit assertion (187 total)**: a tool carrying `inputSchema` passes
  through verbatim while a schemaless tool falls back to the object schema.

### Changed
- **`agent_format_tools`** (`src/agent.cyr`): reads each daimon tool's
  `inputSchema` (a JSON Schema object) and re-emits it verbatim
  (`bayan_json_v_build`) as the OpenAI `function.parameters`. Tools that advertise
  no schema (e.g. builtins) still fall back to `{"type":"object"}`, so the change
  is backward-compatible with pre-1.2.7 daimon.

### Notes
- AGNOS is the primary, most-capable home and is **not** abandoned — the block is
  upstream and tracked; no capability is cut and the floor is not forked to force
  a link.

## [0.6.2] - 2026-06-12

**See what models you can pick from.** `/model <id>` could switch the backing
model mid-session, but you had to already know the id. `/models` now asks the
hoosh gateway for its catalog (GET `/v1/models`, the OpenAI-compatible list) and
prints every model id, marking the one this session routes to — so the
mid-session switch has a menu, not a guess. The catalog is hoosh's domain
(multi-provider routing); thoth only asks and shows. Hoosh seam absent → honest
degradation (no endpoint, no catalog claim), exactly like `/tools`. Toolchain
pin unchanged (Cyrius 6.1.38). 186 unit assertions pass (+6); both the bound and
absent paths live-verified.

### Added
- **`/models` command** (`src/commands.cyr`, `src/hoosh.cyr`): lists the models
  the hoosh gateway advertises. `cmd_models` gates on the hoosh seam (absent →
  the same honest-degradation message shape as `/tools`/`/audit`); `hoosh_list_models`
  does the GET (auth header reused), parses the OpenAI `{"data":[{"id":…}]}` list,
  and prints each id, marking the active routing target (`*`) and naming it in the
  footer. `_hoosh_models_url` builds the `/v1/models` endpoint (base trailing
  slash trimmed, cached) mirroring `_hoosh_endpoint_url`.
- **`hoosh_extract_models`** (`src/hoosh.cyr`): pure extractor returning the
  `data` array value of a `/v1/models` body (or 0 on absent/wrong shape), unit-
  tested.
- **6 new unit assertions (186 total)**: the model-catalog extractor (two-model
  list, id match, empty catalog, missing `data` field, unparseable body).

## [0.6.1] - 2026-06-11

**Streaming in the agentic loop.** The 0.6.0 agentic loop was non-streaming, so
wiring daimon silently turned off the SSE streaming shipped in 0.5.0. Now the loop
streams when `[hoosh].stream` is on (the default): content prints live, and the
model's `tool_calls` are assembled from the streamed deltas. `[hoosh].stream =
false` still gives a blocking round-trip. Toolchain pin unchanged (Cyrius 6.1.38).
180 unit assertions pass; both paths live-verified end-to-end (streamed deltas
reassembled, gated, executed, final answer streamed; blocking path intact).

### Added
- **Streaming in the agentic loop** (`src/agent.cyr`): the loop now streams the
  model's output via SSE when `[hoosh].stream` is on (the default) — content
  prints live as it arrives, and the model's `tool_calls` are assembled from the
  streamed deltas (the `arguments` JSON arrives fragmented and is concatenated by
  index, then reconstructed into the same tool_calls array text the blocking path
  produces, so execution and the assistant echo reuse one code path). This closes
  the 0.6.0 rough edge where wiring daimon silently disabled streaming for every
  turn. `[hoosh].stream = false` still gives a blocking round-trip. The streaming
  banner shows `(…, agentic, stream, N tool-bytes)`.
- **4 new unit assertions (180 total)**: the streamed tool_call delta assembly
  (`_ag_reset`/`_agent_accum_delta`/`_ag_build_array` — fragmented `arguments`
  reassembled, then re-parsed through the same `agent_tc_*` accessors) and the
  streaming request shape.

### Changed
- **`agent_build_request` gained a `stream` parameter**; `agent_turn` is
  refactored into per-iteration `_agent_iter_stream` / `_agent_iter_block` helpers
  with a shared outcome (final answer vs tool calls vs error), so the loop body is
  transport-agnostic.

## [0.6.0] - 2026-06-11

**The agentic tool-calling loop — the M4 vision realized.** A free-text turn
becomes a loop: thoth advertises daimon's MCP tools to hoosh, the model decides
which to call, thoth executes each through daimon (every call **t-ron-gated**),
feeds the results back, and repeats until the model answers. hoosh decides,
daimon executes, bote is the protocol, t-ron authorizes — thoth only drives.
Unblocked by **daimon 1.2.6** (its registry-aliasing fix); thoth's seam needed no
change to integrate. Engages when the daimon seam is wired and `[hoosh].tools` is
on (the default). Toolchain pin unchanged (Cyrius 6.1.38). 176 unit assertions
pass; the loop is live-verified end-to-end on both the happy path
(call→gate→execute→result→answer) and the security path (a t-ron policy deny
blocks the call before it reaches daimon and feeds the denial back to the model).

### Added
- **Model-driven agentic tool-calling loop** (`src/agent.cyr`, `src/daimon.cyr`,
  `src/config.cyr`) — the payoff of the M4 tool spine. When the daimon seam is
  wired, a free-text turn becomes a LOOP: thoth advertises daimon's MCP tools to
  hoosh, the backing model decides which to call (`tool_calls`), thoth executes
  each through daimon — **every call gated by t-ron** — feeds the results back as
  `{role:tool}` messages, and repeats until the model answers with plain content.
  Standard OpenAI tool-calling contract (hoosh normalizes every provider to it).
  thoth owns none of the moving parts: hoosh decides, daimon executes, bote is
  the protocol, t-ron authorizes — thoth only drives the loop.
  - **`agent.cyr`**: advertises tools (`agent_format_tools` — daimon's
    `{name,description}` → OpenAI function tools with a permissive object schema),
    parses `choices[0].message.tool_calls` (`agent_tool_calls` / `agent_tc_*`),
    echoes the assistant tool-call message back verbatim (`_agent_raw_tool_calls`,
    a string-aware balanced-bracket scan), and assembles each request (system +
    budgeted history + this turn's ephemeral tool rounds + the `tools` array).
    Iteration-capped (`AGENT_MAX_ITERS = 8`); failures roll the user turn back out
    of history. Agentic turns are **non-streaming** (the full response must be
    parsed for tool calls).
  - **t-ron-gated execution**: each tool call passes `gate_authorize` before any
    request leaves thoth — a policy deny (or fail-closed confirm when t-ron is
    absent) blocks the call and feeds the denial back to the model, never an
    abort. Verified: a policy-denied tool never reaches daimon.
  - **daimon helpers**: `daimon_invoke` (invoke + return the MCP result text as a
    cstr, no chatty printing) and `daimon_tools_value` (fetch the registry's tool
    array for advertisement).
  - **`[hoosh].tools` toggle** (default **true**): the loop engages when daimon is
    wired and tools are on; `tools = false` keeps plain single-shot turns. `/state`
    shows the agent mode. Events logged via sakshi (`agent_turn` result/iters).
- **13 new unit assertions (176 total)**: tool advertisement formatting,
  `tool_calls` parsing (id/name/arguments, and the no-tool-calls case), the raw
  tool_calls extractor, the agentic request shape (history + tools), and
  `agent_enabled` gating.

## [0.5.2] - 2026-06-11

**Structured driver-event logging** — thoth now logs its own driver events
(turns routed to hoosh, t-ron authorization decisions, mid-session model
switches, session start) as structured `event=… key=value` lines through the
vendored sakshi logger. Off by default (binds only when `[log]` is configured),
so an unconfigured session stays quiet. This is thoth's operational log, distinct
from t-ron's cryptographic audit chain (`/audit`): sakshi records what the driver
did; t-ron records the security verdicts. thoth still owns no logging domain
logic — sakshi owns the envelope/transport/levels. Toolchain pin unchanged
(Cyrius 6.1.38). 163 unit assertions pass; logging live-verified end-to-end (all
five event types written to a file with correct levels).

### Added
- **Structured driver-event logging** (`src/log.cyr`, `src/config.cyr`): thoth
  now logs its own driver events — turns routed to hoosh, t-ron authorization
  decisions, mid-session model switches, session start — as structured
  `event=<name> key=value` lines through the vendored **sakshi** logger (its
  `[timestamp] [LEVEL]` envelope, zero heap alloc). This is thoth's *operational*
  log, distinct from t-ron's cryptographic audit chain (the `/audit` command):
  sakshi records what the driver did; t-ron records the security verdicts. thoth
  owns no logging domain logic — sakshi owns the envelope/transport/levels;
  `log.cyr` only composes the message and gates it on config.
  - **`[log]` config** (`file`, `level`): **off by default** — logging binds only
    when `[log].file` or `[log].level` is set, so an unconfigured session stays
    quiet (the TUI is uncluttered). `file` appends; with only a `level`, sakshi's
    stderr default applies. `level` is `off|fatal|error|warn|info|debug|trace`
    (default `info`). An unopenable file is announced and logging stays off
    (degraded honestly). `/state` shows the log target.
  - Events: `session_start`; `model_switch model=…`; `hoosh_turn model=… stream=…
    multi=… result=ok|transport_error|http_error [status=…]`; `authz tool=…
    verdict=allow|deny|flag` (or `gate=confirm allow=…` when t-ron is absent).
- **15 new unit assertions (163 total)**: the structured-message builder
  (`log_begin`/`log_kv_str`/`log_kv_int` → `log_message`, incl. null-value `-`
  and negative ints), the level parse (`off`→disabled, each named level, unknown
  → default), and the `[log]` config defaults / `log_active` off-without-init.

## [0.5.1] - 2026-06-11

**Multi-turn conversation context** — the headline: free-text turns now carry
prior exchanges, so the backing model has conversation memory (a bounded,
byte-budgeted window; `/reset` clears it, `[hoosh].history = false` reverts to
stateless). Plus a routine toolchain refresh to **Cyrius 6.1.38**. thoth still
owns no domain logic — it holds the transport-side context window; hoosh owns
the inference. 148 unit assertions pass; multi-turn live-verified end-to-end
(context accumulates across turns, `/reset` clears it, the toggle stays
stateless).

### Added
- **Multi-turn conversation context** (`src/session.cyr`, `src/hoosh.cyr`,
  `src/config.cyr`): free-text turns now carry the prior exchanges, so the
  backing model has conversation memory. `session.cyr` keeps a capped history
  (role + a stable content copy; oldest dropped past `SESS_HIST_MAX`); each turn
  records the user message, sends the whole conversation via the new
  `hoosh_build_messages`, and records the assistant reply on success (rolled back
  on failure so history holds only completed exchanges). The streaming path
  accumulates the SSE deltas (`_hoosh_acc`) so the full reply enters history; the
  blocking path copies the parsed content. The request is **byte-budgeted**
  (`_hoosh_history_start`, budget = `HOOSH_REQ_CAP/8`) so the conversation tail
  can never overflow the request buffer (raised to 256 KiB), always keeping at
  least the newest turn. thoth owns only this transport-side context window —
  hoosh owns the inference.
  - **`/reset` command**: clears the conversation context (fresh start; keeps the
    model id and turn counter), reporting how many messages were dropped.
  - **`[hoosh].history` toggle** (default **true**): `history = false` makes each
    turn stateless (the prior single-turn behavior — lower token use, no memory).
    `/state` shows the context mode + message count.
- **17 new unit assertions (148 total)**: the multi-turn history group
  (append/accessors, the stable-copy guarantee, pop/clear, the drop-oldest cap),
  the request group (`_hoosh_history_start` budgeting + the multi-turn
  `hoosh_build_messages` shape with/without system and stream), and the `/reset`
  classification.

### Changed
- **`HOOSH_REQ_CAP` raised 32 KiB → 256 KiB** (`src/hoosh.cyr`) to hold a
  multi-turn request; the per-turn builder byte-budgets against it.
- **Toolchain: Cyrius 6.1.37 → 6.1.38** (`cyrius.cyml`); `lib/` re-synced via
  `cyrius lib sync` (88 modules). Floor-only churn — `alloc`, `alloc_agnos`,
  `atomic`, `str` — no stdlib API migration, no thoth source change from the bump.
  Clears the 6.1.38 drift warning (pin now matches the installed `cycc`).

## [0.5.0] - 2026-06-11

Two unblocked-polish capabilities land on top of the 0.4.x spine (no milestone,
no upstream gate): **hoosh streaming (SSE)** and **`/audit`**. Turns now stream
the completion as it is generated — thoth prints each delta as the SSE frames
arrive, the natural interactive experience — with `[hoosh].stream = false` as the
blocking escape hatch. `/audit` surfaces t-ron's in-process, libro-backed audit
chain: counts, a tamper-check, the agent risk score, and the recent gated
actions. thoth still owns no domain logic — hoosh streams, t-ron audits; thoth
renders. Toolchain pin unchanged (Cyrius 6.1.37). 131 unit assertions pass; both
features live-verified end-to-end (streaming against a real SSE gateway, `/audit`
against the real vendored t-ron engine). Multi-turn context is deferred to 0.5.1.

### Added
- **hoosh streaming (SSE)** (`src/hoosh.cyr`, `src/config.cyr`): free-text turns
  now **stream the completion as it is generated** — thoth POSTs with
  `"stream":true` and prints each `choices[0].delta.content` as the
  Server-Sent-Events frames arrive (via sandhi's `sandhi_http_stream` + the SSE
  parser; the `[DONE]` sentinel ends the turn). A new pure `hoosh_extract_delta`
  (the streaming sibling of `hoosh_extract_content`) and the `_hoosh_sse_cb`
  event callback do the per-frame work; transport errors and non-2xx still
  degrade honestly (announced, not faked). thoth owns none of the inference —
  hoosh streams, thoth renders.
  - **`[hoosh].stream` toggle** (default **true**): set `stream = false` in
    `thoth.cyml` for a single blocking round-trip (the prior behavior; also the
    only mode that can surface a gateway error *body*, since the stream result
    exposes status but not body). `/state` shows the active mode
    (`… (streaming)` / `(blocking)`). New `config_hoosh_stream` + a `_cfg_bool`
    TOML-boolean reader.
- **`/audit` — surface t-ron's audit chain** (`src/gate.cyr`, `src/commands.cyr`):
  a new command that renders t-ron's in-process, libro-backed audit chain — the
  cryptographic record of every gated action (`/write`, `/run`, `/call`) this
  session. Reports total events, denials, the chain length + a tamper-check
  (`audit_verify_chain`), the agent's rolling risk score (0–100%), and the 10
  newest events (id · verdict · tool · reason, newest first). thoth owns none of
  this: `gate_audit_report` reads t-ron's query API (`query_total_events` /
  `query_total_denials` / `audit_recent` / `risk_score`) and renders; the only
  glue thoth authors is the pure `audit_kind_str` verdict-label. With the t-ron
  seam absent, `/audit` says so plainly — the fail-closed confirm gate keeps no
  cryptographic log — degraded honestly. Closes a `state.md` future-work item.
- **26 new unit assertions (131 total)**: the `/audit` group (a `t-ron audit
  chain` set driving the real vendored engine — three `tron_check` calls then
  asserting event/denial counts, the libro chain length + integrity, newest-first
  ordering — plus the pure `audit_kind_str` cases and the `/audit`
  classification); and the streaming group (the `stream:true` request shape,
  `hoosh_extract_delta` across content/role-only/finish/`[DONE]` frames, and the
  `[hoosh].stream` config toggle through the real TOML parser).

### Changed
- **`hoosh_build_request` gained a `stream` parameter** (`src/hoosh.cyr`):
  signature `(dst, model, system, prompt, stream)`. `stream == 1` emits
  `"stream":true`; anything else preserves the prior `"stream":false` shape.

## [0.4.1] - 2026-06-11

Maintenance release: toolchain **Cyrius 6.1.34 → 6.1.37**. The vendored stdlib
(`lib/`) is re-synced to the 6.1.37 snapshot; thoth's own source is unchanged and
all 105 unit assertions pass without modification. No behavior change.

The bump was forced by a real breakage: cycc 6.1.37 changed how an
`#ifndef`-guarded `include` is handled — it now opens the guarded file even when
the guard symbol is already defined. The 6.1.34 `lib/sigil.cyr` carried a
redundant, guard-skipped `include "src/sha_ni.cyr"` (and `aes_ni.cyr`); under
6.1.37 that include fired and failed (`cannot open include file: src/sha_ni.cyr`),
breaking every build/test on a host with the newer wrapper. 6.1.37's own sigil
snapshot drops the redundant include, so re-syncing `lib/` to the matching pin
resolves it.

### Changed
- **Toolchain: Cyrius 6.1.37** (`cyrius.cyml [package].cyrius`, was 6.1.34).
  `lib/` re-synced via `cyrius lib sync` (88 modules). Only the transport/crypto
  floor moved: `sigil` (the dropped sha_ni/aes_ni includes), `sandhi`, `tls`,
  `tls_native`, `ws`, and the `syscalls_{windows,x86_64_agnos}` variants. No
  stdlib API migration — every `bayan_*` / `sandhi_*` / sigil call site is
  unchanged, so no thoth source touched.
- Version strings and the banner bumped to `0.4.1`.

### Verified
- 105/105 unit assertions on `cyrius test` under 6.1.37; `cyrius build` produces
  a clean ~2.7 MB `build/thoth`. The toolchain-drift warning is gone (pin now
  matches the installed `cycc`).

## [0.4.0] - 2026-06-11

The last absent seam flips (roadmap M5): **avatara** binds **native** as a
vendored dist bundle, in-process — the same vendored-bundle pattern as
bote-core / t-ron / libro. thoth now wires **all five spine seams**. The
Thoth/Librarian persona stops being a hardcoded stub: it is **sourced from the
avatara archetype** (`egyptian_thoth()` via the `prof_*` accessors), and — the
half that matters — its soul + spirit prose is threaded into a leading
`{role:system}` message so the precision-0.95 scribe archetype actually
**steers the backing model**, not just the banner. thoth still owns no domain
logic: avatara owns the archetype; thoth reads the emitted profile and authors
only profile→string glue (ADR-0003).

### Added
- **avatara seam, native** (`src/vendor/avatara.cyr`, avatara **2.7.1**): the
  vendored archetype bundle, consumed in-process. `seam_status(SEAM_AVATARA)`
  reports **native** by construction; `/seams` and `/state` reflect it.
- **Persona sourced from avatara** (`src/session.cyr`): `persona_name` now reads
  `prof_name(egyptian_thoth())`; new `persona_soul` / `persona_spirit` /
  `persona_desc` expose the archetype's emitted prose. The profile is built once
  (lazy, stable bump-heap pointer). The "Librarian" role and the THOTH backronym
  tagline remain thoth's own overlay framing over avatara's Egyptian
  wisdom-scribe archetype — not avatara logic.
- **Persona system prompt** (`src/session.cyr` `persona_system_prompt`): soul +
  spirit + thoth's coding operating clause, built once and cached. Threaded into
  the hoosh request as a `{role:system}` message when the avatara seam is bound;
  absent → omitted (the bare user turn), degraded honestly.
- **`scripts/sync-avatara.sh`**: re-sync the vendored bundle from the
  GitHub-tagged dist (default `2.7.1`), mirroring `sync-{bote,tron,libro}.sh`.
- **12 new unit assertions (105 total)**: a persona group (identity sourced from
  the archetype, soul/spirit prose, the built system prompt) and the hoosh
  request-shape cases (no system preserves the original shape, empty system is
  omitted, a non-empty system is prepended).

### Changed
- **`hoosh_build_request` gained a `system` parameter** (`src/hoosh.cyr`):
  signature `(dst, model, system, prompt)`. A non-empty system emits a leading
  `{role:system}` message; an empty/0 system preserves the prior
  single-user-message shape exactly. `hoosh_send` passes the avatara persona,
  gated on the seam being native.
- **Seam registry**: `SEAM_AVATARA` is now `native` (was `absent`); the
  `seam_status` comment block and `src/session.cyr` / `src/main.cyr` headers
  updated — the persona is an overlay sourced from avatara, no longer a "static
  descriptor".
- **`cyrius.cyml`**: `[deps].stdlib` gained **`math`** (the avatara bundle's
  `f64_le` / `f64_ge`; the other f64 ops are compiler builtins). `lib/` re-synced
  to the 6.1.34 pin via `cyrius lib sync` (88 modules).
- Version strings and the banner bumped to `0.4.0`.

### Notes
- The avatara bundle carries a benign `ERR_NONE = 0` that matches the vendored
  libro's identical constant (same value; last definition wins), and its own
  self-contained `xalloc` (an OOM guard over stdlib `alloc`, defined nowhere
  else). No fn/type collisions with the other bundles, the stdlib, or thoth's
  own source.

## [0.3.0] - 2026-06-11

The agent gets real hands (roadmap M4): **three seams flip at once**. daimon
(MCP tool execution + host registry) binds **remote-client** over HTTP via
sandhi; bote (the MCP protocol) and t-ron (per-tool authorization) bind
**native** as vendored dist bundles, in-process. Every dangerous action —
`/run`, `/write`, and the new MCP `/call` — now flows through one t-ron-backed
authorization choke point that fails closed at every layer. Live-verified
end-to-end across the real spine: thoth → t-ron allow → daimon → MCP JSON-RPC
→ hoosh's bote-backed `/v1/tools/call` → echo back up the chain; a deny-listed
tool refused with no request sent. See [ADR-0006](docs/adr/0006-m4-tool-spine-daimon-bote-tron.md).

### Added
- **daimon seam client** (`src/daimon.cyr`): `/tools` lists the MCP host
  registry (`GET /v1/mcp/tools`); `/call <tool> [json]` invokes a tool
  (`POST /v1/mcp/call`) and prints the MCP tool-result text. Binds when
  `thoth.cyml [daimon].url` is declared; degrades honestly otherwise.
- **t-ron authorization gate** (`src/gate.cyr`): when `[tron].policy` names a
  loadable policy TOML, every gated action becomes a t-ron `ToolCall` —
  **deny is final** (no prompt can override policy), flag falls back to the
  interactive confirm, allow proceeds. Without a policy the M2 fail-closed
  confirm prompt stands in, announced. Built-ins authorize as `thoth_run` /
  `thoth_write`; MCP tools under their real name, checked *before* any
  request leaves thoth. t-ron's own defaults deny unknown agents/tools.
- **Vendored spine bundles** (`src/vendor/`): bote-core 2.7.3 (MCP protocol,
  transport-free), t-ron 2.1.5 (policy/rate/scan/audit engine), libro 2.7.2
  (the audit chain t-ron writes). Committed dist files with re-sync scripts
  (`scripts/sync-{bote,tron,libro}.sh`) — NOT `[deps.X]` blocks, whose
  transitive git sub-deps collide (the hoosh-discovered pattern).
- **26 new unit assertions (93 total)**: daimon call building + result/error
  extraction against canned bodies, t-ron verdicts through the real vendored
  engine (allow/deny globs, deny-by-default for unknown agent/tool — also the
  libro `chain_append` SIGILL canary), `[daimon]`/`[tron]` config defaults,
  `/tools` + `/call` classification, and M4 seam statuses.

### Changed
- **Seam registry is fully dynamic**: bote reports **native** by construction
  (the bundle is in-process); daimon remote when configured; t-ron native when
  a policy loads. `/seams`, `/state`, and the gate all reflect it.
- **`cyrius.cyml`**: toolchain pin `6.1.32` → `6.1.33` (dep-resolver CVE
  hardening; no stdlib migration). Stdlib deps gained `regex` (t-ron policy
  globs), `random`, `patra`, `slice` (vendored libro/t-ron surfaces), and the
  concurrency+crypto floor (`atomic`/`thread`/`thread_local`/`ct`/`keccak`/
  `random`) moved **before** `sigil` — t-ron 2.1.5's documented ordering
  constraint (without it, libro's `chain_append` SIGILLs).
- `confirm` moved from `src/commands.cyr` into `src/gate.cyr`, beside the
  seam it stands in for; thoth's private `_hex_digit` renamed
  `_hoosh_hex_digit` (stdlib patra now carries an identical private one).
- Version strings and the banner bumped to `0.3.0`.

### Known issues
- **daimon 1.2.4 upstream**: the MCP host registry stores strings aliasing
  the transient request buffer, so registrations corrupt as later requests
  arrive (calls 502, `/tools` shows garbage). Filed as
  `daimon/docs/development/issues/2026-06-11-mcp-registry-aliases-request-buffer.md`.
  thoth's seam is correct against a fresh registration.
- t-ron's bundle duplicates sigil's `chacha20_xor` (same signature/semantics;
  last definition wins) — benign, accepted in t-ron's own 2.1.5 notes.

## [0.2.1] - 2026-06-11

Maintenance release: toolchain **Cyrius 6.1.23 → 6.1.32** (the bayan stdlib
migration) and the hoosh seam re-verified against **hoosh 2.4.5** (was wired
against 2.2.2). The `/v1/chat/completions` contract thoth consumes is unchanged
across hoosh 2.2.3–2.4.5 — the gateway's new surface (tool calling, batch, MCP
tool endpoints, DLP, observability, new providers, configurable routing
strategy) is server-side or belongs to later seams (M4: daimon/bote/t-ron).
No thoth behavior change.

### Changed
- **Toolchain: Cyrius 6.1.32** (pin, was 6.1.23). Clean `lib/` re-sync
  (52 modules).
- **Stdlib migration: `json` / `toml` / `cyml` / `base64` / `bigint` → `bayan`.**
  Cyrius 6.1.25 carved the data-domain modules out of stdlib into the bayan
  distlib; those five names no longer resolve. `[deps].stdlib` now lists
  `bayan` in their place, ordered before `sigil` (u256) and the transport
  (json/base64). Call sites migrated to the canonical `bayan_*` names
  (`bayan_json_v_*` in `src/hoosh.cyr`, `bayan_toml_*` / `bayan_cyml_*` in
  `src/config.cyr`) rather than the deprecated back-compat aliases.
- Version strings and the banner bumped to `0.2.1`.

### Verified
- 67/67 unit assertions on `cyrius test`; live end-to-end against a local
  hoosh **2.4.5** gateway — a turn routed to Anthropic, then a mid-session
  `/model` switch re-routed to OpenAI in the same session, both through the
  bayan-migrated response parser.

## [0.2.0] - 2026-06-10

The signature feature, wired (roadmap M3): the **hoosh seam** flips from absent
→ **remote-client**. thoth routes a turn to a backing model and switches the
backing model mid-session — both through hoosh, the AGNOS inference gateway,
reached as an OpenAI-compatible HTTP client transported by **sandhi**. Verified
end-to-end against a live gateway: a turn routed to a real provider, and a
mid-session `/model` switch re-routed Anthropic → OpenAI within one session.
thoth still owns no domain logic — hoosh owns inference, routing, and the
switch; thoth drives. See [ADR-0005](docs/adr/0005-hoosh-seam-remote-over-sandhi.md).

### Added
- **hoosh seam client** (`src/hoosh.cyr`): builds an OpenAI-compatible
  chat-completions request (with a JSON string escaper), POSTs it via
  `sandhi_http_post`, and extracts `choices[0].message.content` with the stdlib
  `json` value parser. The request builder, escaper, and response/error
  extractors are pure; only the round-trip does I/O.
- **`thoth.cyml` runtime config** (`src/config.cyr`): thoth's own CYML config
  (distinct from the `cyrius.cyml` build manifest), parsed once at startup via
  the stdlib `cyml` + `toml` modules. `[hoosh].url` / `token` / `model`.
  `thoth.cyml` is gitignored (it may hold a token); `thoth.cyml.example` is the
  committed template.
- **Mid-session model switch made real**: `/model <id>` stores a stable copy
  (`session_set_model_copy`) used on the next turn; hoosh routes per request by
  the `model` field, so a new id is the switch.
- **20 new unit assertions** (67 total): JSON escaping, request building, and
  response/error extraction against canned bodies, plus config defaults and the
  copy-not-alias model switch.

### Changed
- **Seam status is honest and dynamic**: `seam_status(SEAM_HOOSH)` returns
  `remote` when `thoth.cyml` declares an endpoint, else `absent`. `/seams`,
  `/state`, `/model`, and free-text task routing reflect it — a configured turn
  POSTs to hoosh; an unconfigured one degrades with a pointer to `thoth.cyml`;
  an unreachable gateway announces the transport error. Never faked.
- **`cyrius.cyml`**: toolchain pin `6.1.15` → `6.1.23`; opted `sandhi` and its
  full transitive stdlib set (plus `cyml`/`toml`) into `[deps].stdlib`, ordered
  so the low-level floor precedes the transport that consumes it (libs are
  opt-in and Cyrius does not resolve transitive deps).
- Version strings and the banner bumped to `0.2.0`.

## [0.1.0] - 2026-06-09

First real release: the platform-neutral **driver core** (roadmap M2). thoth is
a DRIVER — it owns no domain logic and reaches the AGNOS spine
(hoosh/daimon/bote/t-ron/avatara) through capability seams that are all
**absent** in 0.1.0. The agent loop is real; model-backed reasoning, MCP tools,
and authorization are not wired yet, and degrade honestly. SemVer `0.x` per
[ADR-0004](docs/adr/0004-semver-pre-release.md).

### Added
- **Interactive REPL/TUI driver** (`src/repl.cyr`, `src/main.cyr`): a
  read → dispatch → iterate loop over a portable buffered line reader.
- **Commands** (`src/commands.cyr`): `/help`, `/seams`, `/state`, `/model`,
  `/read`, `/write`, `/run`, `/quit`, plus free-text input routed as a coding
  task. Pure `classify_input` / `token_is` / `arg_after` helpers.
- **Capability-seam registry** (`src/seams.cyr`): the five spine seams with
  status (all `absent`); `/seams` renders the capability ladder honestly.
- **Fail-closed authorization gate**: `/run` and `/write` name their target and
  deny by default, proceeding only on explicit `y` — the t-ron-absent
  degrade-closed posture, made real.
- **Local shell escape** (`src/exec.cyr`): `/run` runs `/bin/sh -c` via the
  portable `process.cyr` surface (explicit argv), streaming output and
  reporting the real exit code.
- **Session state + persona** (`src/session.cyr`): turn/model state and the
  static avatara Thoth/Librarian banner descriptor.
- **47-assertion unit suite** (`tests/thoth.tcyr`) over the pure logic.
- Project identity + the OS-agnostic/AGNOS-primary design: `CLAUDE.md`,
  `README.md`, `docs/development/{state,roadmap}.md`, ADR-0001..0004,
  architecture note 001, and the required root files (`CONTRIBUTING.md`,
  `SECURITY.md`, `CODE_OF_CONDUCT.md`).

### Changed
- `cyrius.cyml`: `version` → `${file:VERSION}` (was an inlined `0.1.0`); real
  `description`; added `repository`; `[build].output` → `build/thoth`; added
  `process` / `result` / `tagged` stdlib deps for the portable shell escape.
- Standards links repointed from the stale `docs/development/applications/…`
  path to `docs/development/first-party/…`.

### Security
- `/run` and `/write` are gated by a fail-closed confirm that denies by default
  (stands in for the absent t-ron seam) and names the object being authorized.
- `/run` uses explicit argv via `exec_vec` — no `sys_system` with unsanitized
  data. `/read` is read-only and ungated by design; a real sandbox/authorization
  posture belongs to the t-ron seam, not an in-tree allowlist (see ADR-0001).
