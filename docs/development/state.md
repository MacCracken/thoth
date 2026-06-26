# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.11.8** — shell completion (0.11.x terminal-citizen line), 2026-06-26. `thoth --completion
<shell>` prints a bash or zsh completion script to stdout (completing thoth's argv flags + a
filename after `-o`/`--out`) for the non-interactive front door — the interactive REPL
slash-palette already completes commands live. A print-and-exit mode (`ONESHOT_COMPLETION`, like
`--version`/`--help`): `--completion`/`--completions` short-circuits in `_oneshot_parse`,
capturing the next argv token as the shell (optional → default bash); an unsupported shell
degrades closed (stderr + nonzero exit). `oneshot_print_completion` dispatches to
`_completion_bash`/`_completion_zsh` (`src/oneshot.cyr`), which EMIT static scripts (the shell
runs them; thoth never executes them — no spine path, no security surface). bash completes flags
+ `-o` filenames + `bash zsh` after `--completion`; zsh uses `_arguments` (source-style, ending
`compdef _thoth thoth`). The flag lists mirror `_oneshot_parse` (sync comments). **Cyrius
escaping** (the risk): `$` is literal in Cyrius string literals (confirmed empirically — no
`\$`); only an inner `"` (→`\"`) and a trailing `\` (→`\\`) escape; bash uses single-quoted
flags. Verified byte-correct via `bash -n`/`zsh -n` + a functional `COMPREPLY` check. **Two-pass
review:** design pass settled the escaping + pinned the folds (bash `--completion` arm, zsh
`compdef` form, `--completions` alias, single-quoted flags); diff pass ZERO must-fixes. 599
assertions (+11, `test_completion`; scripts host-validated). Pin unchanged (6.2.43).
**0.11.7** — `-o` / `--out` file tee (0.11.x terminal-citizen line), 2026-06-25. `thoth -o
<file> <task>` tees the answer (plain reply or the `--json` envelope) to `<file>` (plain bytes)
AS WELL AS stdout. It is the user's OWN redirection (an argv-token path, like shell `>`), so it
is **NOT t-ron-gated** — t-ron gates the MODEL writing files (`/write`); choosing where thoth's
own output goes is not a model action (the path is fixed from argv before the turn, so the model
cannot influence it). `-o`/`--out` is a one-shot MODIFIER flag (consumes the next token as the
path; does not force a run; a dangling `-o` is ignored; composes with `--json`). New
`_oneshot_write_out` (`src/oneshot.cyr`) writes the answer + a trailing newline (if absent) so
the file matches stdout byte-for-byte, create+truncate at 0644 via the portable `lib/io.cyr`
wrappers (the AGNOS open bridge — never a raw `sys_open`); degrades closed (open/short/newline
write failure → stderr + nonzero exit; the answer still reached stdout — best-effort tee); a
FAILED turn writes no file. **Perms:** 0644 (umask-respecting, tighter than `>`'s
`0666 & ~umask`); AGNOS drops the create-mode (frozen-ABI bridge) — keep secret-bearing output
in an owner-only dir (noted in `--help`). REPL/TUI-only scope. **Two-pass review:** design pass
confirmed the parse + the 0644/not-gated security calls and pinned one fix (check the
trailing-newline write → degrade-closed); diff pass ZERO must-fixes. Verified live: `--help` +
a failed turn writes no file; the success tee + degrade are exact-tested (writer unit-tested
against a scratch file under `build/`). 588 assertions (+19, `test_oneshot_out`). Pin unchanged
(6.2.43).
**0.11.6** — JSON-envelope output (0.11.x terminal-citizen line), 2026-06-25. `thoth --json
<task>` runs the one-shot turn and prints a single JSON object to stdout instead of the plain
reply — `{response, model, turns, tokens?, cost?, elapsed_ms}` — for jq/CI. Rides the 0.11.0
one-shot clean-stdout seam; **opt-in** (default one-shot stays plain text; the interactive
TUI/REPL + the byte-identical floor untouched). `--json`/`-j` is a one-shot MODIFIER flag (an
`elif` on the `-p` chain — does not force a run, never a positional, never breaks `-p`; reset
before the `n<=1` early return so no stale flag). New pure `oneshot_json_envelope`
(`src/oneshot.cyr`) serializes the object: the reply escaped BY LENGTH (an embedded NUL
survives as a `\u0000`, matching the plain path's by-length print); `tokens`/`cost` follow
ADR-0010 omit-until-present (never a faked `0`/`$0`); `turns` always present; `elapsed_ms` =
wall-clock turn time (`clock_now_ms`, non-monotonic-step guarded). The envelope buffer
(`HOOSH_ACC_CAP*6 + MODEL_BUF_CAP*6 + 256`) is sized so a worst-case 6×-escaped max reply
never truncates → always complete, valid JSON. New `_json_escape_n_into_cap` (`src/hoosh.cyr`,
length-bounded); `_json_escape_into_cap` refactored to delegate to it at `strlen` (byte-identical
for all existing callers). **Failure contract:** on any failure NOTHING goes to stdout in either
mode (no partial/invalid JSON), a diagnostic to stderr, nonzero exit (the jq/CI consumer checks
the exit code). **Two-pass adversarial review:** design pass confirmed the buffer/valid-JSON
guarantee + failure contract and pinned the fixes (elif parse, flag reset, self-documenting cap,
by-length escaper); diff pass returned ZERO must-fixes. Verified live: `--help` + the failure
path (empty stdout + stderr + exit 1, no hoosh); the success envelope is exact-tested. 569
assertions (+13, `test_json_envelope`). Pin unchanged (6.2.43).
**0.11.5** — `/dry` request-body preview (0.11.x terminal-citizen line), 2026-06-25. `/dry
<task>` renders the EXACT hoosh request body thoth would compose for `<task>` and SKIPS the
POST — a local introspection command ("what goes to the model?"). **Side-effect-free** (no
session history / token / cost mutation) and **network-free** (no hoosh POST, no daimon fetch);
NEVER a hoosh `/preview` endpoint (that would fork the inference spine) — it renders thoth's OWN
composed request buffer. New `hoosh_build_dry` (`src/hoosh.cyr`) composes the multi-turn body
(persona system + budgeted history tail + the pending user turn) WITHOUT mutating history (the
live `hoosh_send` appends the turn first; this reads only), reusing the same
`_hoosh_emit_msg_cap`/`_hoosh_history_start`/cap-bounded builders so the bytes match a real turn;
plus `hoosh_model_cur()` (the exact `hoosh_send` model precedence) and `hoosh_dry_buf()`.
`cmd_dry` (`src/commands.cyr`, `CMD_DRY`) mirrors `hoosh_send`'s path selection, prints the
endpoint + flags (model/stream/history/agent/bytes) + the body, degrades honestly when
`[hoosh].url` is unset (composes locally, never refuses), and in agentic mode shows the message
envelope + ANNOTATES (never fetches) the `tools` array. REPL/TUI-only (one-shot routes argv to
`cmd_task`); a >2 KiB body truncates in the TUI feed (noted; the line REPL shows it whole).
Documented faithfulness edge: `_hoosh_history_start` budgets without the pending prompt's bytes,
so at a ~32 KiB-history boundary the preview can include one extra old message. **Two-pass
adversarial review:** design pass confirmed the side-effect-free/network-free design + pinned
fixes (reuse `_hoosh_model`, annotate-not-fetch tools, honest absent handling, read-only build
over a lossy temp-append); diff pass returned ZERO must-fixes. Verified live (piped REPL): the
body for configured + absent seams, and `turns: 0` after two `/dry` calls. 551 assertions (+9,
`test_dry`). Pin unchanged (6.2.43).
**0.11.4** — `[alias]` prompt macros (0.11.x terminal-citizen line), 2026-06-25. User-defined
slash macros in `thoth.cyml`: a `[alias]` table of `name = "expansion"` pairs. Typing
`/<name> [args]` that is NOT a built-in expands to the configured text (+ any trailing args)
and RE-DISPATCHES it — an alias can map to a built-in (`/ship → /run git status`), a free-text
task, or `/quit`. Reuses the bayan TOML parser (no second config format). **Opt-in — with no
`[alias]` table the unknown-command path is BYTE-IDENTICAL to before.** New `[alias]` table in
`src/config.cyr` (`_alias_load` caches each pair's name/expansion into a stable fixed table,
cap 64; blank skipped, duplicate key keeps the first, a name ≥ 256 chars skipped since it could
never match a typed token; `config_alias_lookup`/`config_alias_count`). Expand-then-redispatch
in `src/commands.cyr`: `_alias_name_of` (bare slash token) + `alias_expand(line, depth)` (value
+ ' ' + trailing args into a per-depth, cap-bounded, nul-terminated buffer); `dispatch(line)`
is now a thin wrapper over `_dispatch_d(line, depth)` that, at `CMD_UNKNOWN_SLASH`, tries an
alias and re-dispatches the expansion one level deeper — **bounded** (`ALIAS_MAX_DEPTH` = 8;
the guard fires BEFORE the next slot is written, so a cycle is refused, never an OOB write or
runaway). An `aliases : N defined` row in `/state` (shown only when N > 0, so default `/state`
is unchanged). **Security/posture:** an alias to `/run`/`/write`/`/call` is re-dispatched
through the SAME t-ron gate (no bypass); built-ins always win (aliases only fill the
`CMD_UNKNOWN_SLASH` gap); it is a REPL/TUI feature (one-shot routes argv straight to `cmd_task`
by design, so it doesn't interpret `/aliases`). **Two-pass adversarial review (Workflow):** a
DESIGN pass caught two real blockers pre-code (the depth guard had to precede `alias_expand`
or a cycle wrote one slot past the buffer; `_alias_bufs` needed lazy alloc); a DIFF pass
surfaced one must-fix (a ≥256-char name was a dead, count-inflating entry), fixed +
regression-tested. Verified live (piped REPL): `/st → /state`, a cycle refused, no-config
floor unchanged. 542 assertions (+20, `test_alias`). Pin unchanged (6.2.43).
**0.11.3** — soft-wrap long feed lines (0.11.x terminal-citizen line), 2026-06-25. The
top-ranked pure-substrate win from the SecureYeoman-TUI review: the T2 feed stops
TRUNCATING a logical line wider than the feed column and REFLOWS it across several physical
rows. Painter + scrollback-math only — no argv dependency, no spine touched; the
line-REPL/piped/CI floor never paints the feed, so it is **byte-identical** by construction
(`feed_clip` and the file-tree painter are untouched). New PURE `feed_clip_seg` in
`src/feed.cyr` paints the visible-column WINDOW `[skip_cols, skip_cols+max_cols)` of a
stored line (segment N == `feed_clip_seg(.., N*width, width)`), carrying SGR color across the
wrap boundary via a bounded 64-byte SGR-since-last-reset carry (whole-or-drop flush — never a
severed CSI), suppressing `ESC[...K`, never severing a UTF-8 glyph, closing an open span with
`ui_reset()`. Plus pure `feed_rows_for` (`ceil(vis/width)`, blank = 1 row) + `_feed_total_phys`
(the document's soft-wrapped height). `feed_repaint` (`src/tui.cyr`) rewritten to the
physical-row model (each physical row → a `(logical line, segment)` pair); **scrollback is now
PHYSICAL (soft-wrapped) rows** (`feed_scroll()` redefined; `_tui_feed_maxscroll` shared by the
scroll keys + a `tui_relayout` upper-clamp, since a width change re-flows the document).
**Honest limitations (declared):** glyph width counted as 1 col (a double-width CJK/emoji
wraps a column late + undercounts `_feed_total_phys` → approximate scroll/segment mapping for
CJK-heavy captured output; ASCII/thoth output exact), and the 64-byte cumulative-SGR carry cap
(over-cap run drops the overflow whole — bounded cosmetic glitch; thoth's single-span output
never overflows). **Two-pass pre-cut adversarial review:** a DESIGN pass (4 lenses, before any
code) caught the one real gap — `feed_scroll()`'s unit had to become physical + clamp on
resize — folded in pre-implementation; a DIFF pass (4 lenses, each finding independently
verified) confirmed the change correct on every input the live caller produces (the raised
`feed_clip_seg` contract edges are unreachable through `feed_repaint`: `fwidth >= 1` and
proven `PAINT_CAP` headroom), and two zero-risk hardening edits (empty-window guard +
whole-or-drop carry) aligned the canonical primitive with its docstring before downstream
reuse. 522 assertions (+42, `test_softwrap`). Painter verifies on a real tty
(`THOTH_TIER=rich`), not the harness. Pin unchanged (6.2.43).
**0.11.2** — opt-in persistent input history (0.11.x terminal-citizen line), 2026-06-25.
Completes the 0.11.1 composer input-history recall: set `[history].file` in `thoth.cyml` and
thoth **loads** prior submitted lines into the recall ring at TUI startup and **saves** new
ones across sessions. **Off by default** (no `[history].file` → in-memory-only recall, floor
untouched); DISTINCT from `[hoosh].history` (conversation memory). New `[history].file`
config (`src/config.cyr`, `config_history_file`, mirrors `[log].file`). `src/inhist.cyr`
gains a PORTABLE-I/O section (lib/io.cyr `file_open`/`_read`/`_write`/`_close`, which bridge
the AGNOS open ABI — never a raw `sys_open`): a streaming loader (chunked, bounded; each line
pushed through the ring so dedup/skip-empty/evict keep the most-recent 128), a NON-DESTRUCTIVE
writability probe at init (create-if-absent without truncate — starting thoth never rewrites
your file), and a rewrite-the-ring saver after each stored submit (file bounded to the ring,
not append-grow). **Security, honest:** the file holds typed composer lines (may contain
secrets), so a FRESH file is **0600** (owner-only) on POSIX — **best-effort, NEVER asserted in
the UI**: the create-mode applies only on CREATE (a pre-existing looser file keeps its perms —
no silent re-tighten, since `chmod` is absent on Windows + a frozen-ABI no-op on AGNOS, so
calling it would fork the floor), and the path follows symlinks. Documented in
`thoth.cyml.example`. Degrades closed: an unwritable path or a mid-session write failure is
ANNOUNCED (startup feed line + a one-time "persistence disabled" note), never faked. **Pre-cut
adversarial review (4 lenses)** caught a real honesty defect — the first draft hardcoded
"0600" in the announce (a guarantee not held on AGNOS / for a pre-existing file); fixed before
cut (announce asserts no mode, init non-destructive, saver checks write returns + degrades
closed, residuals documented), then a targeted re-review confirmed the fixes clean. 0600
create-mode verified empirically (`stat`). 480 assertions (+13, `test_inhist_persist`). Pin
unchanged (6.2.43).
**0.11.1** — composer input-history recall (0.11.x terminal-citizen line), 2026-06-25. The
top-ranked pure-substrate win from the SecureYeoman-TUI review: the T2 raw-mode composer
recalls previously-**submitted** lines with **Up/Down** (Up older, Down newer, past-newest
restores the in-progress draft) — shell-style history, **distinct from the multi-turn
CONVERSATION history** (`session_history_*`, 0.5.1; that is the model's memory, this is the
user's keystrokes). New **`src/inhist.cyr`** — a PURE, unit-tested 128-slot ring of
submitted lines (the same ring shape as `src/feed.cyr`): **ignoredups** + skip-empty +
O(1) eviction, and a nav cursor (`inhist_nav_up`/`_down`/`_reset`/`_at_draft`) over
`[0, count]` where `count` == "the live draft". The TUI glue (`src/tui.cyr` `_tui_recall_*`)
stashes the draft, loads a recalled line into the `led_*` composer (cursor at end), and
restores the draft past the newest; `tui_loop` binds Up/Down **in composer focus with the
slash palette closed at the START of recall** (so Up/Down stay free while composing a
`/command`; once navigating it continues, so a recalled `/cmd` doesn't strand you). A
`↑↓ history` hint appears once there is history. **TUI-ONLY by construction** — recall needs
the raw-mode composer; the line REPL reads through the kernel's cooked line discipline
(`read_line`), unchanged → the REPL/piped/CI floor is **byte-identical** (this code is never
reached off PT_RICH; the empty-history hint is byte-identical). **Persistence (opt-in,
`0600`) is deliberately the next slice (0.11.2)** — it adds file I/O + a security surface
that earns its own review; this cut is in-memory only, so the default experience is
delivered in full with no on-disk footprint. **Pre-cut adversarial review (4
perspective-diverse lenses — memory/bounds, ring+nav correctness, byte-identical
floor+posture, Cyrius-language+integration): zero confirmed findings** (the lone raised item
was a refuted nit — the `tui_loop` elif ordering is load-bearing, now documented inline).
467 assertions (+29). Pin unchanged (6.2.43).
**0.11.0** — one-shot / argv front-door, the 0.11.x keystone, 2026-06-25. thoth becomes a
non-interactive shell citizen: `thoth 'task'`, `git diff | thoth 'review'`, `thoth -p <
f`, `thoth --version|--help` run ONE turn through the EXISTING `cmd_task →
hoosh_send/agent_turn` seam and exit — **no new spine path**, only a new input source
(argv + slurped stdin) + a clean output contract. Mode gated on **explicit argv intent**
(NOT `isTTY==false` — piped stdin already drives the line-REPL), so no-argv-task falls
through to the TUI/REPL unchanged (**byte-identical floor**). New `src/oneshot.cyr` (pure
`_oneshot_parse` classifier + bounded task assembly + `_oneshot_append_stdin` payload slurp
+ `one_shot_run`). Clean stdout via a new `OUT_NULL` discard sink (`src/util.cyr`): the turn
runs with output discarded, then `one_shot_run` prints ONLY the reply accumulator
(`hoosh_last_reply`) to fd 1; diagnostics → stderr (`emit_err`); exit 0 on a real answer,
nonzero otherwise. Degrade-closed: the t-ron confirm **denies** in one-shot (announced on
stderr, never silent-allow/blocking-prompt), and a bound-policy DENY/FLAG is mirrored to
stderr. **Pre-cut adversarial review (4 lenses, all verified):** core sound; caught + fixed
3 contract gaps before cut — (1) `gate_init`/`log_init` startup chrome leaked to stdout when
`[tron]`/`[log]` configured (fixed: classify mode first + discard init chrome under
OUT_NULL + 2 raw `println`→`oprintln` in `log.cyr`; verified byte-clean), (2) streaming
max-iters left interim narration in the accumulator → one-shot could print it as success
(fixed: clear the accumulator on max-iters in `agent.cyr` → reports failure), (3) silent
bound-DENY (fixed: stderr mirror). [ADR-0011](../adr/0011-one-shot-argv-front-door.md). Live
success round-trip is host-side (sandbox blocks compiled-binary TCP); error paths + parser
covered by smoke + `test_oneshot`. 438 assertions (+13). Pin unchanged (6.2.43; note: local
cycc has drifted to 6.2.44 — a future maintenance bump, not bundled here).
**0.10.3** — cost, the second data producer (0.10.x arc), 2026-06-25. thoth surfaces a
running session **cost** (`$d.cc`), priced from hoosh's token usage times an opt-in,
user-declared `[pricing.<model>]` rate, **priced at accumulate** (each response costed with
the model active at that moment, so a mid-session `/model` switch is costed correctly).
Omit-until-present ([ADR-0010](../adr/0010-data-producer-honest-omit.md)): the field shows
only once a priced response arrives — never a faked `$0` — and `/state` announces the gap.
New `[pricing.<model>]` config (`src/config.cyr`): per-model `input`/`output` rates in
integer micro-USD per 1000 tokens (= USD-per-1M × 1000), cached at load into a stable fixed
table (cap 32) keyed by the verbatim model id (dots/dashes OK); `_cfg_int` distinguishes an
omitted key (`-1`) from `= 0`. Pure math: `hoosh_cost_micro = (p·in + c·out)/1000`;
`cost_fmt` renders `$d.cc` truncating DOWN (never overstates). Session tally in
`src/session.cyr` (`session_cost_micro`/`_seen`/`_unpriced_count` + `add_cost`/`note_unpriced`;
`/reset` clears). `_hoosh_account_usage` folds tokens+cost from each response's usage, wired
into all four turn paths (blocking+SSE, hoosh+agent). Surfaced as `$d.cc` in the status bar
(after `tok`, omitted until priced) and a `cost` row in `/state` (honest absent line, plus an
unpriced-omitted count for partially-priced sessions). hoosh owns the counts; thoth only
multiplies. **Pre-cut adversarial review (4 lenses, all verified):** core sound; caught one
honest-omit gap — a half-declared `[pricing]` (one side omitted) billed the missing side at
`$0` — fixed before cut (`&&`→`||` guard → unpriced+noted, regression-tested). Keying
contract documented (key matches the REQUESTED model id; default routing → `[pricing.default]`).
Floor byte-clean (status TUI-only; `/state` row 0 escapes at T0 — verified). Live priced
round-trip is host-side (sandbox blocks compiled-binary TCP); covered by `test_cost`. 425
assertions (+32). Pin unchanged (6.2.43).
**0.10.2** — token usage, the first data producer (0.10.x arc), 2026-06-25. thoth
surfaces a live `tok <n>` session token count, sourced from hoosh's own
`usage.total_tokens` and summed across the session (every agentic-loop iteration, and
across mid-session model switches). Follows **omit-until-present**
([ADR-0010](../adr/0010-data-producer-honest-omit.md)): the field appears **only once
hoosh reports usage** — never a `0`/`(n/a)` placeholder — and `/state` shows an honest
absent line until then. New pure `hoosh_extract_usage` (+ shared `_hoosh_usage_total`):
reads `usage.total_tokens` from a blocking body or a streaming usage frame, `-1` when
absent. Session tally in `src/session.cyr` (`session_tokens`/`_seen`/`add_tokens` — the
seen-flag distinguishes "0 tokens" from "no usage yet"; only a `>= 0` figure flips it;
cleared by `/reset`). Surfaced as `tok <n>` in the TUI status bar (omitted until seen)
and a `tokens` row in `/state`. **Streaming now sends `stream_options:{include_usage:true}`**
(`hoosh_build_request`/`hoosh_build_messages`/`agent_build_request`) so the gateway
appends a usage frame to the SSE stream; `_hoosh_sse_cb` parses each frame once and reads
content + usage on one pass. hoosh owns the count; thoth only sums. Floor stays clean
(status field TUI-only; `/state` row emits 0 escapes at T0 — verified). Live `usage`
round-trip is a host-side step (sandbox blocks compiled-binary TCP); wire shape covered
by `test_usage`. 393 assertions (+13). Pin unchanged (6.2.43).
**0.10.1** — toolchain refresh to Cyrius 6.2.43, 2026-06-25. Maintenance: the source pin
moves `6.2.40 → 6.2.43` (`cyrius.cyml` + `cyrius lib sync` — 67 floor modules), clearing
the toolchain-drift warning (cycc had drifted to 6.2.43 locally). **No thoth source
change**; 380 assertions pass unchanged; x86_64 Linux builds + ships as before. The
`run_capture` arity warning the older cycc surfaced also cleared. One **benign** warning
is accepted: `lib/sandhi.cyr`'s HTTP/2 connection-promotion path
(`_sandhi_http_try_h2_promote_a`) calls `_sandhi_conn_open_v6_fully_timed_a` with 8 args
(missing the TLS `ctx`) — but that path runs only for **pooled** requests, and thoth
issues one-shot `sandhi_http_post`/`_stream` with `opts = 0` (no pool → HTTP/1.1), so it
never reaches the call. An upstream sandhi h2-path inconsistency, unreachable from thoth;
`lib/` is vendored, never hand-edited. Pin **6.2.43**.
**0.10.0** — `/theme` dark/light (M7), 2026-06-25. Opens the 0.10.x arc (themes + data
producers). A runtime color-theme switch over the semantic-role surface: a **theme axis**
in `src/ui.cyr` sits in front of the role color tables — `_ui_rgb`/`_ui_idx256`/
`_ui_code16` branch on `_ui_theme` into `_dark` (pre-0.10.0 values verbatim → byte-
identical default) and `_light` (the mockup's warm-light) leaves; `ui_set_theme(t)`
rebuilds the cached SGR table while keeping the detected tier/depth. `/theme dark|light`
switches, **⌃T** toggles in the TUI, the status bar + `/state` show the active theme.
PT_PLAIN stays empty-string under any theme → piped/CI floor byte-identical (verified: 0
escapes). `rainbow` is announced not-yet-available (a per-grapheme HSV render mode, not a
role table — needs anuenue vendored; user deferred it). Known: a switch re-colors chrome
+ new output but existing feed lines keep baked colors (/clear for a clean window); light
shares dark's 16-color codes. TUI render verifies on a real tty. 380 assertions (+14,
`test_theme`). Pin unchanged (6.2.40 → 0.10.1 will refresh to 6.2.43).
**0.9.5** — version single-source + the TUI welcome banner + status-bar version,
2026-06-25. Small polish/infra ahead of the 0.10.x arc. **Version is now a single source
of truth (`VERSION`):** new `scripts/gen-version.sh` generates `src/version.cyr`
(`thoth_version()`, the one runtime copy) from `VERSION`; `scripts/build.sh` regenerates
it before each build (committed too, so a raw `cyrius build` stays in sync). The banner,
the `/state` build line, and the status bar all read `thoth_version()` — the scattered
`"thoth X.Y.Z"` literals are gone (cyrius.cyml already read `VERSION` via `${file:VERSION}`).
Proven: bump `VERSION` → regen → rebuild → the runtime string follows. **TUI welcome
banner:** the alt-screen feed seeds the full scribe greeting (avatara-sourced, mirroring
the REPL banner) — `<name>, <role> - {(o>` · the THOTH backronym · `READY — …`. **Status
bar:** `{(o> thoth (<version>)  model …  turns …  surface …`. TUI render verifies on a
real tty; 366 assertions (unchanged). Pin unchanged (6.2.40).
**0.9.4** — `/clear` + feed scrollback (M7), 2026-06-25. Two quality-of-life additions
to the T2 TUI, both riding the 0.9.1 self-managed feed. **`/clear`** empties the content
window: in the TUI it clears the feed ring (`feed_clear`); in the line REPL on a tty it
clears the screen; piped/CI it's a no-op (no window) — distinct from `/reset` (which
clears the conversation *context*). **Scrollback:** **Shift-↑/↓** (the non-mouse wheel
fallback; CSI `1;2A`/`1;2B`) scroll a few lines and **PageUp/PageDown** (CSI `5~`/`6~`,
incl. the modified `5;2~`/`6;2~` form) a screenful, paging back through the ring's
retained 2048 lines (`feed_repaint` honors `feed_scroll()`; `_tui_feed_scroll_by` clamps
to the available history); a submitted turn resets to the bottom so fresh output shows.
Scroll works in either focus (the tree keeps its own ↑/↓). Adversarially reviewed pre-cut
(2 lenses): one low finding (modified-PageUp decode) fixed; zero must-fix. **TUI verifies
only on a real tty (`THOTH_TIER=rich`)**, not the harness. The REPL/piped/CI floor is
byte-identical (`/clear` no-ops at T0; scroll/CSI-decode are TUI-only). 366 assertions
(+4). Pin unchanged (6.2.40 — cycc locally at 6.2.42; staying on the pin).
**0.9.3** — the togglable file-tree pane (M7), 2026-06-25. The headline of the
presentation arc: a keyboard-navigated (no-mouse) inline expand/collapse tree of the
working directory as a LEFT COLUMN, made possible by the 0.9.1 self-managed feed +
escape-aware clip. **Ctrl-B** toggles it; **Tab** focuses it; **↑/↓** move, **→/←**
expand/collapse, **Enter** reads a file (keeping tree focus, so you browse file-to-file)
or toggles a folder. New `src/ftree.cyr` — a PURE, unit-tested core (the tree/feed layout
geometry; the flattened-tree model: `ftree_move`/`ftree_collapse_at` + the expand splice
+ `ftree_path` ancestor-walk) + the I/O listing (`dir_list`/`is_dir` via `lib/fs.cyr`,
dirs-first, rooted at `$PWD` — portable, no Linux-only `SYS_GETCWD`, so it compiles for
every target). The feed paints into the narrowed right column (`tui_feed_left`/
`tui_feed_width` → `feed_clip`); `tui_draw_tree` paints the left (dir blue / file muted,
selected row a reverse-video bar) + a `│` separator. Hidden by default → the REPL/piped/CI
floor stays byte-identical. Adversarially reviewed pre-cut (4 lenses, every finding
verified): zero correctness/crash/floor/security findings. **TUI render verifies only on
a real tty (`THOTH_TIER=rich`)**, not the harness. 362 assertions (+21, `test_ftree`).
Pin unchanged (6.2.40 — cycc locally at 6.2.42; staying on the pin, the drift/arity
warnings are toolchain-side). Known limit: 256-node cap; no in-dir alphabetical sort yet.
**0.9.2** — instant SIGWINCH + the working spinner + incremental streaming paint
(M7), 2026-06-25. The second course on the 0.9.1 self-managed feed. **Instant resize:**
the bare blocking key-read is replaced by an **epoll multiplex** of stdin + a SIGWINCH
signalfd (`tty_open_signalfd(TTY_SIGMASK_WINCH)` + `sys_epoll_create/_ctl/_wait`) — idle,
the loop blocks in `epoll_wait`, so a resize wakes it the instant it happens (not on the
next keystroke), and `tui_relayout` recomputes geometry + full-repaints; a resize during a
blocking dispatch queues on the level-triggered fd and is serviced on return (accepted
gap). Falls back to the 0.9.1 blocking read where epoll/signalfd are absent (degrade
closed). **Incremental streaming:** `feed_repaint` renders the unsealed pending line as a
virtual bottom row, and `feed_stream_tick` (pinged from the hoosh/agent SSE callbacks)
repaints it per chunk, so a streamed turn renders as it arrives in the TUI (was
shown-only-on-completion in 0.9.1); no-op off the TUI → REPL stream byte-identical.
**Working spinner:** a braille indicator on the hint row for the dispatch window —
animated per SSE chunk when streaming, held still on a blocking turn / `/run` (honest, no
faked motion since the loop is blocked inside `dispatch()`), suspended across the gate
confirm. Also **fixes the 0.9.0 SIGINT-signalfd teardown leak** (both signalfds + epoll
now closed on every exit, restoring the signal mask). Adversarially reviewed pre-cut (4
lenses, every finding verified): zero correctness/hang/crash/floor/security findings.
**TUI render verifies only on a real tty (`THOTH_TIER=rich`)**, not the harness. 341
assertions (+4, `test_spinner`). Pin unchanged (6.2.40 — cycc locally at 6.2.41; staying
on the pin, the drift/arity warnings are toolchain-side). Known → 0.9.3: the togglable
left-column file-tree pane.
**0.9.1** — the self-managed feed-redraw model (M7), 2026-06-24. The T2 feed stops
relying on the DECSTBM terminal-scroll trick and becomes thoth-owned: dispatch output
is captured into a line ring (new `src/feed.cyr` — 2048×2 KiB, escape-aware clip) and
the visible window is painted each frame. The prerequisite for the file-tree pane
(0.9.3) and instant SIGWINCH (0.9.2): once thoth owns the feed it can repaint it at a
new size or in a narrower column. Capture is a **surface-routed output sink** (new
`_out_mode`/`emit_raw`/`oprintln`/`ofmt_int` in `src/util.cyr`; emit/emit_n branch to
`feed_write` under OUT_RING) — NOT fd-1 redirection, which the design workflow rejected
as floor-forking (AGNOS has no `sys_dup2`) and confirm-breaking. Armed only around the
`dispatch()` window; the REPL/piped/CI floor never arms it → **byte-identical** (golden
`/help`+`/state`+`/seams` diff unchanged across the 206-site `println`/`fmt_int`→shadow
rename). The t-ron gate confirm brackets back to the live screen under capture
(`tui_confirm_begin`/`_end`), staying answerable + fail-closed; the REPL path is
unchanged. Adversarially reviewed pre-cut (5 lenses, every finding verified): zero
correctness/crash/floor/security findings. **TUI render verifies only on a real tty
(`THOTH_TIER=rich`)**, not the harness. 337 assertions (+42, `test_feed`/`test_feed_ring`/
`test_capture`). Pin unchanged (6.2.40). Known → 0.9.2: instant SIGWINCH + working
spinner + incremental streaming paint; → 0.9.3: the togglable left-column file-tree pane.
**0.9.0** — the T2 rich-TUI front-end (M7), 2026-06-24. An interactive alt-screen TUI
(new `src/tui.cyr` + vendored `src/vendor/darshana.cyr`): a pinned, Ctrl-G-togglable
status bar, a scrolling feed (the composer clears on Enter; the response streams
below), a raw-mode composer with line editing + horizontal scroll, a slash-command
palette, and keybinding hints; exit via Ctrl-X / Ctrl-C / /quit (all restore the
terminal). Active only at PT_RICH on a real tty (`THOTH_TIER=rich`); the line REPL
is the guaranteed fallback (piped output byte-identical). Adversarially reviewed
pre-cut — 4 issues fixed, incl. a critical SIGINT-during-dispatch teardown leak. 295
assertions (+25, `test_tui`). Known → 0.9.1: instant SIGWINCH resize + the file-tree
pane (the feed-buffer redraw model). Pin unchanged (6.2.40).
**0.8.6** — diff row background tint (M7 Phase 2d), 2026-06-24. Add/del diff rows now
carry a subtle background tint (green add / red del) under the syntax-highlighted code
— completing the mockup's diff card. Built with fg-only resets (`ESC[39m`) so the tint
survives the colored spans + `ESC[K` row-fill; only at 256-color+, gutter-only at
16-color, plain when piped (byte-identical floor). New `ui_bg`/`ui_eol`/`ui_reset_fg`
accessors. 270 assertions. Pin unchanged (6.2.40).
**0.8.5** — syntax-highlighted diff bodies (M7 Phase 2c), 2026-06-24. The colored diff
card now syntax-colors the line bodies (keywords amber, strings green, …) via the SAME
coverage-guarded highlighter `/read` uses (`_hl_span`, shared into `src/diff.cyr`) — no
byte dropped; the green `+`/red `−` gutter + faint line numbers carry the add/del
signal; grammar auto-detected from the path. Plain when piped. 270 assertions. Pin
unchanged (6.2.40).
**0.8.4** — syntax highlighting via vyakarana (M7 Phase 2b), 2026-06-24. `/read`
renders source syntax-colored (keywords amber, strings green, comments faint, …) via
the newly vendored `src/vendor/vyakarana.cyr` (2.2.3 — the AGNOS tokenizer, 45
grammars; no hand-rolled highlighter; clean integration, zero collisions). Coverage-
guarded so the full file is shown verbatim, only colored (verified byte-identical);
plain at T0 / for unknown languages. 270 assertions (+7, `test_highlight`). Pin
unchanged (6.2.40).
**0.8.3** — diff producer + colored hunks (M7 Phase 2), 2026-06-24. `/write` reads
the old file and renders a colored old→new diff (new `src/diff.cyr`: a bounded LCS
line-diff — green add / red del / faint context, line numbers, blue path, `+A −D`
counts) through the T1 surface, plain when piped. Crosses from formatting into a real
capability (the first diff DATA thoth produces). A 3-lens adversarial review cleared
the engine (memory + LCS correctness sound) and caught two honesty gaps — newline-aware
line identity + announced old-file truncation — both fixed before cut. 263 assertions
(+7, `test_diff`). Pin unchanged (6.2.40).
**0.8.2** — color breadth, the rest of the core views (M7 Phase 1b), 2026-06-24.
Extends 0.8.1's palette to `/state` (faint labels, accent model/build, green live
tier), `/help` (accent commands, muted descriptions, alignment preserved), `/models`
+ `/models <provider>` (active target a green `*` + accent id), `/tools`, and the
`-> hoosh`/`-> daimon` turn lines — all via `src/ui.cyr` roles at T1. No new
substrate; **byte-identical when piped/CI** (0 escape bytes verified). New
`ui_emit_n` helper. 256 assertions. Pin unchanged (6.2.40).
**0.8.1** — design-palette color across the core surfaces (M7 Phase 1a), 2026-06-24.
The banner, `/seams`, the agent loop's tool-call/result lines, and the t-ron gate
verdicts now render through `src/ui.cyr`'s semantic color roles at T1 (the mockup's
warm amber). Pure T1, no new substrate; **byte-identical when piped/CI** (roles are
empty on the T0 floor — 0 escape bytes verified). `/seams` colors the live ladder so
degrade-closed is visible (t-ron `absent` binding gray, `degraded` effect amber). New
`ui_emit`/`ui_label` helpers. 256 assertions. Pin unchanged (6.2.40).
**0.8.0** — presentation surface, the render foundation (M7 Phase 0), 2026-06-24.
Opens the **0.8.x design-style arc** ([ADR-0009](../adr/0009-presentation-capability-ladder.md)):
presentation becomes a capability tier (T0 plain → T1 ANSI → T2 rich-TUI → T3
desktop). New `src/ui.cyr` — startup tier detection (`isatty` + `TERM`/`COLORTERM`/
`NO_COLOR`/`THOTH_TIER`, degrade-closed) + a semantic color-role API (`ui_sgr`/
`ui_reset`): empty at T0 so piped/CI output is **byte-identical to 0.7.2**, the
design's exact amber (`#e6ab5c`, truecolor→256→16) at T1. Tier shown in `/state`
(`surface : …`); the `{(o> ` prompt wears the accent role. 256 assertions (+12,
`test_ui`). Pin unchanged (6.2.40).
**0.7.2** — REPL prompt restyled to `{(o> ` (was `thoth> `), 2026-06-24. Prompt-only
change (`src/repl.cyr`); no behavior change. 244 assertions. Pin unchanged (6.2.40).
**0.7.1** — `/models <provider>` drill-down, 2026-06-24. `/models` lists the
providers hoosh routes to; **`/models <provider>`** now lists that provider's
concrete, switchable model ids (e.g. `/models anthropic` → `claude-opus-4`,
`claude-sonnet-4`, …), marking the active routing target. Consumes **hoosh 2.4.9**'s
new `GET /v1/models/catalog` (`{object:list, data:[{id, owned_by}]}`, only models an
enabled route can serve), filtered by `owned_by` (case-insensitive). Bare `/models`
unchanged; unknown provider and pre-2.4.9 hoosh (404) degrade honestly. The catalog
is hoosh's domain — thoth only asks. 244 assertions (+9, `test_provider_catalog`).
Pin unchanged (6.2.40).
**0.7.0** — parallel tool calls + `/audit` tool-rounds + a security-hardening pass,
2026-06-24. **Parallel tool execution LANDED, on by default** (`[hoosh].parallel`): a
round's calls fan out across OS threads — t-ron gating and bayan parsing stay serial,
only the daimon network invoke is concurrent (`_agent_run_calls_par` over the reentrant
`daimon_fetch_into`). Unblocked by the floor repairs the toolchain bump carried: cyrius
**6.2.40**, sandhi **1.6.13** (per-dispatch arena context), bayan **1.0.3** (per-call
parser state) — the earlier "HELD/UNSAFE at 6.2.37" framing is obsolete. `/audit`
surfaces a session-local trace of the loop's tool **rounds** (`src/roundlog.cyr`),
grouped by turn/round, independent of t-ron's libro chain (renders even when t-ron is
absent). **Hardening (audit-driven):** every model/MCP-controlled request builder now
writes through bounded `_append_cstr_cap` / `_json_escape_into_cap` helpers — an
oversized tool name/arguments or daimon tool registry truncates in-buffer instead of
overflowing a fixed heap buffer (closed 6 confirmed overflow paths in the serial,
streaming, and tool-advertise code; the parallel path was already bounded). Oversized
tool arguments are now uniformly REFUSED on both paths with a result the model can react
to, gated on the full payload so t-ron never scans a clipped one. Tool registry is
fetched + serialized once per session, not per turn. 235 assertions (+14). Pin **6.2.40**.
**0.6.7** — cross-target re-verification of the 6.2.37 floor + getrandom root cause,
2026-06-23: re-ran `./scripts/build.sh all` on x86_64 Linux. Two symbols the gated
lanes hit are **fixable upstream bugs, not capability gaps** (correcting an earlier
"known gap" misread): **Windows `SYS_GETRANDOM`** — Windows HAS ProcessPrng via the
`sys_getrandom()` wrapper; patra issued a raw Linux `syscall(SYS_GETRANDOM,…)`, **fixed
in patra v1.12.4**; and **AGNOS `SIGHUP`** — agnos signal infra is DONE
(`sigprocmask`#17/`signalfd`#18), the peer just omits the signal-number constants,
**filed**. AGNOS's old `SYS_LSEEK` blocker is RESOLVED (agnos peer now has it). aarch64
re-confirmed building; macOS not re-run (Mac host). `scripts/build.sh` gap set split
into `ARCH_GAP` (permanent: futex/epoll) vs `TRANSIENT_GAP` (getrandom/SIGHUP). No
thoth runtime source change; 199 assertions. Pin unchanged (6.2.37).
**0.6.6** — toolchain refresh to Cyrius 6.2.37, 2026-06-23: the source pin moves
6.2.15 → **6.2.37** (`lib/` re-synced via `cyrius lib sync` — 98 floor modules,
two new snapshot modules `protobuf`/`yantra`; no thoth source change), clearing the
drift warning. 199 assertions (unchanged); x86_64 Linux builds + ships as before.
Cross-target re-verification of the new floor landed in 0.6.7 (above).
**0.6.5** — M6 capability ladder (effect dimension), 2026-06-16: the seam registry
gains the **full / degraded / absent capability-effect** dimension on top of the
existing native/remote-client/absent **binding mode** — two orthogonal axes, the
second not inferable from the first. `seam_cap_state` derives the effect from live
binding status; **t-ron** is the defining case (binding `native→absent`, effect
`full→degraded` — the fail-closed confirm gate, never silent-allow). `/seams` now
renders both axes + the live effect line; computed, not narrated, so doc and binary
can't drift. New [architecture note 002](../architecture/002-capability-ladder.md).
199 assertions (+12). Pin unchanged (6.2.15).
**0.6.4** — toolchain refresh + aarch64 lane lights up, 2026-06-16: the source
pin moves 6.1.38 → **6.2.15** (`lib/` re-synced via `cyrius lib sync`, 97 floor
modules; no thoth source change), clearing the drift warning. The **aarch64 Linux**
target now **builds** (`build/thoth_aarch64`, a valid statically-linked ARM ELF) —
the cycc `#pure`/aarch64 pass-1 scanner gap that blocked it closed upstream in
Cyrius **v6.2.2**, so the lane lights up with zero thoth change. AGNOS stays blocked
on `SYS_LSEEK` — now **filed upstream**
(`agnos/.../2026-06-16-cyrius-patra-lseek-syscall-gap.md`), with a second gap
(`SYS_FUTEX`, patra's mutex) behind it. Windows now surfaces `SYS_FUTEX` first
(Win uses `WaitOnAddress`); `scripts/build.sh` recognizes it as a sanctioned
best-effort gap. 187 assertions (unchanged). Pin **6.2.15**.
**0.6.3** — multi-target builds (M6) + per-tool input schemas, 2026-06-12:
`scripts/build.sh` is the build driver that fans one source tree to targets
(`linux`|`agnos`|`all`); **x86_64 Linux ships** as a named target (`build/thoth`).
The **AGNOS** target is staged but blocked **upstream** — `patra` needs
`SYS_LSEEK`, absent from the AGNOS syscall floor (6.1.38→6.2.0); announced, never
faked. Also: daimon **1.2.7** emits `inputSchema` per MCP tool, so
`agent_format_tools` passes it through verbatim as the model's
`function.parameters` instead of a permissive `{"type":"object"}` guess — the
model now sees each tool's real argument shape (closing daimon issue
`2026-06-11-mcp-manifest-omits-tool-input-schema`; backward-compatible).
187 assertions. Pin 6.1.38 at the time. See [ADR-0008](../adr/0008-multi-target-builds.md).
NB superseded by 0.6.4: the cycc `#pure`/aarch64 pass-1 scanner fix landed in
Cyrius v6.2.2 and aarch64 now builds; macOS remains a Mac-host build.
**0.6.2** — model catalog, 2026-06-12: `/models` asks the hoosh gateway for its
catalog (GET `/v1/models`, OpenAI-compatible) and lists every model id, marking
the session's active routing target — the mid-session `/model` switch now has a
menu, not a guess. Catalog is hoosh's domain; thoth only asks. Seam absent →
honest degradation (like `/tools`). Pin unchanged (6.1.38). 186 assertions (+6);
bound + absent paths live-verified.
**0.6.1** — agentic streaming, 2026-06-11: the agentic loop streams via SSE when
`[hoosh].stream` is on — content live, `tool_calls` assembled from fragmented
deltas. Closes the 0.6.0 edge where wiring daimon disabled streaming. Pin
unchanged (6.1.38). 180 assertions; both stream/block paths live-verified.
**0.6.0** — agentic tool-calling loop, 2026-06-11: free-text turns become a loop —
thoth advertises daimon's MCP tools to hoosh, the model calls them, thoth executes
each through daimon (t-ron-gated), feeds results back, repeats until the model
answers. The M4 vision realized; unblocked by daimon 1.2.6. `[hoosh].tools`
(default on). Pin unchanged (6.1.38). 176 assertions; loop live-verified on the
happy and policy-deny paths.
**0.5.2** — structured logging, 2026-06-11 (unblocked polish): thoth logs its own
driver events (`event=… key=value` via the vendored sakshi logger) — turns,
authz verdicts, model switches, session start. Off by default (`[log]` opt-in);
operational, distinct from t-ron's `/audit` chain. Toolchain pin unchanged
(6.1.38). 163 assertions; logging live-verified to a file.
**0.5.1** — multi-turn context, 2026-06-11 (unblocked polish): free-text turns
carry prior exchanges so the model has conversation memory — a bounded,
byte-budgeted window (`/reset` clears it, `[hoosh].history=false` reverts to
stateless). Plus a routine toolchain refresh to Cyrius **6.1.38** (floor-only
`lib/` churn, no source change). 148 assertions; multi-turn live-verified.
**0.5.0** — streaming + audit, 2026-06-11 (unblocked polish, no milestone gate):
hoosh turns **stream the completion (SSE)** as it is generated — each delta
printed as the frames arrive, `[hoosh].stream=false` reverts to blocking; and
**`/audit`** surfaces t-ron's in-process, libro-backed audit chain (counts,
tamper-check, agent risk score, recent gated actions). Toolchain pin unchanged
(6.1.37). 131 assertions; both live-verified end-to-end. Multi-turn → 0.5.1.
**0.4.1** — toolchain refresh, 2026-06-11 (Cyrius 6.1.34 → 6.1.37; `lib/`
re-synced. Forced by a cycc 6.1.37 guarded-`include` behavior change that fired
the 6.1.34 sigil's redundant `src/sha_ni.cyr` include and broke the build; the
6.1.37 sigil drops it. No thoth source change; 105/105 still pass).
**0.4.0** — the avatara seam, 2026-06-11 (roadmap M5: avatara binds native via a
vendored dist bundle; the Thoth/Librarian persona is sourced from the archetype
(`egyptian_thoth()`) and threaded into the hoosh system prompt — **all five
spine seams now wired**).
**0.3.0** — the M4 tool spine, 2026-06-11 (daimon remote-client; bote + t-ron
native via vendored dist bundles; one fail-closed authorization choke point).
**0.2.1** — toolchain + hoosh refresh, 2026-06-11 (Cyrius 6.1.32 / the bayan
stdlib migration; seam re-verified against hoosh 2.4.5). **0.2.0** — the hoosh
seam, 2026-06-10 (roadmap M3: inference + mid-session model switch). First real
release was **0.1.0**, 2026-06-09 (M2: the driver core). Scaffolded 2026-06-08
via `cyrius init`.

thoth uses **SemVer `0.x`** through its pre-1.0 phase
([ADR-0004](../adr/0004-semver-pre-release.md)) — this supersedes the earlier
"CalVer at first release" note. The post-1.0 scheme is deferred.

## Posture

thoth wires **all five seams** (since 0.4.0), and a free-text turn drives the
**model-driven agentic tool-calling loop** (0.6.0) on top of them. hoosh (M3) is
**remote-client**: turns route to a backing model and switch mid-session through
the inference gateway over sandhi. M4 adds the tool spine: **daimon remote-client** (the MCP
host — `/tools` lists its registry, `/call` invokes a tool), **bote native**
(the vendored bote-core bundle IS the MCP protocol, in-process), and **t-ron
native** (the vendored authorization engine gates `/run`, `/write`, and
`/call` through one choke point — deny is final, no policy means the
fail-closed confirm prompt). M5 adds **avatara native**: the vendored archetype
bundle (avatara 2.7.1) supplies the Thoth/Librarian persona in-process — sourced
from `egyptian_thoth()` via the `prof_*` accessors and threaded into the hoosh
`{role:system}` message so the precision-0.95 scribe archetype steers the turn,
not just the banner. Unconfigured capabilities (no hoosh/daimon url, no t-ron
policy) still degrade honestly; nothing is faked. See
[ADR-0006](../adr/0006-m4-tool-spine-daimon-bote-tron.md) and
[ADR-0007](../adr/0007-m5-avatara-seam-native-persona-system-prompt.md).

The hoosh seam binds only when `thoth.cyml` declares `[hoosh].url` — no endpoint
declared, no remote claim. Verified end-to-end against a live gateway (a turn
routed to a real provider; a mid-session `/model` switch re-routed Anthropic →
OpenAI in one session) — wired against hoosh 2.2.2, re-verified at **hoosh
2.4.5** (0.2.1); the `/v1/chat/completions` contract is unchanged across that
span. See [ADR-0005](../adr/0005-hoosh-seam-remote-over-sandhi.md).

The settled identity (recorded so code doesn't entrench the wrong shape):
thoth is OS-agnostic in its reach and AGNOS-sovereign in its spine, and the
two never collide because they govern different layers.

- **Substrate (OS-agnostic floor).** Below thoth sit syscalls, allocation,
  argv, process spawn, and terminal I/O. Cross-OS support here is already
  structurally present in the vendored Cyrius stdlib (see
  [Toolchain](#toolchain)) behind one stable interface — a posture thoth
  ratifies, not infrastructure it must invent. thoth writes against the
  portable interface and picks the target at build time; it never writes
  against a per-OS file.
- **Capability spine (AGNOS-sovereign ceiling).** Above thoth sits the
  capability spine — model routing / mid-session switching, agent
  orchestration + MCP tool execution + host registry, the MCP protocol,
  per-tool authorization, and the Thoth / Librarian archetype overlay.
  thoth owns **no domain logic of its own**; it owns its place in the stack
  precisely by **consuming** that spine rather than reimplementing any part
  of it.

The framing is "everywhere capable, AGNOS canonical": portability owns the
floor (it always runs), AGNOS owns the ceiling (it runs best — the whole
spine is native, co-resident, and sandboxed end to end), and the gap is an
explicit, documented contract. Off AGNOS, thoth runs the **same** spine
reached as a client over a portable transport, capability-gated; where a
service is unreachable the matching feature degrades honestly and is
announced to the user — never faked, never reimplemented in-tree. Security
degrades **closed** (absent per-tool authorization means a conservative
built-in deny/prompt, never a silent allow). The bright line: **port the
floor; never fork the spine.**

## Toolchain

- **Cyrius pin**: `6.2.43` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc`. **0.10.1** took 6.2.40 → 6.2.43 (`cyrius lib sync`, 67 floor
  modules; no thoth source change). The 0.7.0 line had run on 6.2.40. Earlier:
  **0.6.6** took 6.2.15 → 6.2.37 — a toolchain refresh:
  `cyrius lib sync` re-synced 98 floor modules (two new snapshot modules,
  `protobuf` and `yantra`); floor-only churn, no thoth source change, 199
  assertions unchanged. **0.6.4** took 6.1.38 → 6.2.15 — a toolchain refresh:
  `cyrius lib sync` re-synced 97 floor modules (incl. new `*_agnos` peer-splits and
  the expanded `tls_native_*` set from the 6.2.7 agnos-completeness pass); floor-only
  churn, no thoth source change, 187 assertions unchanged. This is the refresh that
  lit up aarch64 (the cycc `#pure`/pass-1 scanner fix landed in v6.2.2). History
  (each matching the then-installed `cycc`): 0.2.1 took 6.1.23 → 6.1.32 with the 6.1.25 bayan
  data-domain carve; 0.3.0 took 6.1.33 — dep-resolver CVE hardening; 0.4.0 was on
  6.1.34, no stdlib migration; **0.4.1** took 6.1.34 → 6.1.37 — forced by a cycc
  guarded-`include` behavior change that fired sigil's redundant `src/sha_ni.cyr`
  include; the 6.1.37 sigil drops it. The re-sync touched only the
  transport/crypto floor — `sigil`, `sandhi`, `tls`, `tls_native`, `ws`,
  `syscalls_{windows,x86_64_agnos}` — no stdlib API migration, no thoth source
  change. **0.5.1** took 6.1.37 → 6.1.38 — a routine refresh, floor-only churn
  (`alloc`, `alloc_agnos`, `atomic`, `str`), again no source change). M5 added
  the **`math`** stdlib dep (the vendored avatara bundle's
  `f64_le`/`f64_ge`) and re-synced `lib/` to the pin via `cyrius lib sync`
  (88 modules).
- **Multi-OS substrate present in the vendored stdlib** (`lib/`), behind one
  stable interface:
  - syscalls — `syscalls_x86_64_agnos`, `syscalls_x86_64_linux`,
    `syscalls_aarch64_linux`, `syscalls_macos`, `syscalls_windows`
    (plus `syscalls_linux_common`)
  - alloc — `alloc_agnos`, `alloc_macos`, `alloc_windows`
  - args — `args_agnos`, `args_macos`, `args_win`
  - process — `process_agnos`, `process_win` (the `/run` shell escape rides
    this portable surface)

  AGNOS is the primary target; Linux, macOS, and Windows are capability-gated
  reach targets.

## Targets (build matrix)

The one source tree fans out to targets at **build time** via the build driver
`scripts/build.sh` (`linux` | `win` | `aarch64` | `agnos` | `all`); no per-OS
source. Cross-target lanes re-verified at 0.6.6 (Cyrius 6.2.37) on this x86_64
Linux host; the macOS lane was last verified 0.6.4 (its native Mach-O build needs a
Mac host) — see [ADR-0008](../adr/0008-multi-target-builds.md):

| Target | Flag | Status | Output |
|---|---|---|---|
| x86_64 Linux | _(default)_ | **shipped** — built, tested (199), released | `build/thoth` |
| aarch64 Linux | `--aarch64` | **builds** (re-verified 0.6.6 / Cyrius 6.2.37) — valid static ARM ELF, not yet ARM-run-tested | `build/thoth_aarch64` |
| macOS (arm64) | `macos` _(Mac host)_ | **builds + runs** natively (verified 0.6.4 on Apple Silicon; not re-run at 6.2.37); audit path gated upstream | `build/thoth_macos` |
| AGNOS (x86_64) | `--agnos` | **staged** — old `SYS_LSEEK` blocker RESOLVED; now gated on `SIGHUP` (agnos signal infra DONE, peer just omits signal-number consts — **filed**, fixable) | `build/thoth_agnos` |
| Windows | `--win` | **staged** — `SYS_GETRANDOM` is **fixed** (patra v1.12.4, transient lag); genuine remaining gaps are `SYS_FUTEX` + epoll (Win32 architectural) | `build/thoth.exe` |

**aarch64 (unblocked since 0.6.4, re-verified 0.6.6):** `cyrius build --aarch64`
produces a valid statically-linked ARM ELF (`file` → `ELF 64-bit … ARM aarch64`;
exec-format error on the x86 host confirms it's genuinely cross). It had been
blocked on a cycc `#pure`/aarch64 pass-1 scanner bug (filed
`cyrius/.../2026-06-12-main-aarch64-pass1-missing-annotation-tokens-unexpected-enum`),
**resolved upstream in Cyrius v6.2.2**. Cross-built here; running it on real ARM
hardware is a host-side step.

**AGNOS block (upstream, not thoth) — the lseek gap RESOLVED at 6.2.37:** the
old blocker (`patra.cyr` → `SYS_LSEEK`, the filed
`agnos/.../2026-06-16-cyrius-patra-lseek-syscall-gap.md`) is **closed** — the 6.2.37
agnos peer `syscalls_x86_64_agnos.cyr` now defines `SYS_LSEEK = 58` (and
`SYS_GETRANDOM = 45`). `cyrius build --agnos` now advances past patra and fails
later, in vendored `src/vendor/t-ron.cyr:3436`, on **`SIGHUP`**. This is **not**
"AGNOS has no signals": the agnos peer already defines `SYS_SIGPROCMASK=17` /
`SYS_SIGNALFD=18` with wrappers (signal infra DONE per agnos `syscall-additions.md`),
and t-ron's `sighup_init` uses exactly those. The peer merely omits the signal-NUMBER
constants (`SIGHUP`, … — defined `SIGHUP=1 … SIGPWR=30` on the linux/macos/aarch64
peers), so the bare `SIGHUP` literal can't resolve. A **fixable floor gap, filed**:
`agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md` (the agnos
ABI owner should confirm the numbers rather than have it guessed). Behind it sit
`SYS_FUTEX`/epoll. The lane lights up once the agnos peer gains the signal enum.

**Windows: `SYS_GETRANDOM` was a patra bug (now fixed), NOT a Win32 gap.** Windows
has a CSPRNG — `bcryptprimitives!ProcessPrng`, wired as the `sys_getrandom()` peer
wrapper. patra's `_wal_gen_salts` drew its WAL salts via a raw
`syscall(SYS_GETRANDOM,…)` — a Linux-shaped call the Windows peer deliberately omits
the constant for — so `--win` failed to link. **Fixed in patra v1.12.4**
(`src/wal.cyr`, `#ifdef CYRIUS_TARGET_WIN` → `sys_getrandom()`; verified: patra builds
`--win`, 834 Linux tests still pass). thoth's `--win` lane clears the moment the
toolchain re-bundles patra ≥1.12.4. The genuine, **architectural** Windows gaps remain
`SYS_FUTEX` (patra's mutex; Win uses `WaitOnAddress`) and the sandhi/epoll set (IOCP) —
by-design Win32 differences with no raw-syscall equivalent. `scripts/build.sh` now
separates these `ARCH_GAP`s from the transient `SYS_GETRANDOM`/`SIGHUP` lag.

**macOS (builds + runs, audit path gated upstream):** built natively on an Apple
Silicon host (Cyrius emits Mach-O there; cross-emit from Linux is not the path),
`./scripts/build.sh macos` produces `build/thoth_macos` (Mach-O arm64) which
launches the REPL and exits cleanly — **verified 0.6.4** (not re-run at 6.2.37:
the native Mach-O build needs the Mac host, and the 0.6.6 cross-pass ran on
x86_64 Linux). cycc emits ~86 "syscall
not routed by the Mach-O ARM translation (ESYSXLAT/__got)" warnings: the
`var SYS_*; syscall(SYS_*,…)` first arg doesn't const-fold, so the reroute misses
(upstream cyrius issue `2026-06-16-var-syscall-number-defeats-macho-pe-reroute`).
The basic driver path is fine; patra's `lseek`/`futex` (t-ron's audit ledger) will
fault at runtime once a `[tron].policy` is configured, until that cycc fix lands.

## Source

The driver core (M2), the hoosh seam (M3), and the tool spine (M4):

- `src/main.cyr` — entry; includes the modules callee-first, runs
  `config_load` + `gate_init` then the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers (incl. M4's
  `/tools` and `/call`; **0.5.0:** `/audit`, `/state` shows the stream mode;
  **0.5.1:** `/reset`, `/state` shows the multi-turn context + count; **0.6.0:**
  free-text turns route to the agentic loop when `agent_enabled`, `/state` shows
  the agent mode; **0.6.2:** `/models` lists the hoosh gateway's catalog).
  **0.11.4 ([alias] macros):** `dispatch(line)` is now a thin wrapper over
  `_dispatch_d(line, depth)`; at `CMD_UNKNOWN_SLASH` it tries `alias_expand(line, depth)`
  (`_alias_name_of` bare token + value/arg assembly into a per-depth, cap-bounded buffer)
  and re-dispatches one level deeper, bounded by `ALIAS_MAX_DEPTH` (guard before the write,
  so a cycle is refused, never an OOB). An `aliases` row in `/state` (only when > 0). An
  alias to `/run`/`/write`/`/call` re-dispatches through the SAME t-ron gate; built-ins
  always win (aliases only fill the unknown-slash gap). **0.11.5 (`/dry`):** `cmd_dry`
  (`CMD_DRY`) previews the request `hoosh_send` would compose for a task (multi-turn →
  `hoosh_build_dry`, else `hoosh_build_request`) and skips the POST — side-effect-free +
  network-free; prints endpoint/flags/body, degrades honestly when the seam is absent, and
  annotates (never fetches) the agentic `tools` array.
- `src/seams.cyr` — the capability-seam registry; statuses fully dynamic. **0.6.5
  (M6 ladder):** adds the **capability-effect** dimension (`CapState`
  full/degraded/absent) on top of the binding mode — `seam_cap_state` derives it
  from live status (t-ron degrades closed, never absent), `seam_cap_full` /
  `seam_cap_fallback` carry the prose; `cmd_seams` renders both axes. See
  [architecture note 002](../architecture/002-capability-ladder.md).
- `src/session.cyr` — session state (incl. the copy-on-set model) + the avatara
  persona overlay (**M5**: `persona_*` sourced from `egyptian_thoth()` via the
  `prof_*` accessors; `persona_system_prompt()` builds the soul+spirit+operating
  clause once). **0.5.1 (multi-turn):** the capped conversation history
  (`session_history_*` — append/accessors/pop/clear; stable content copies).
  **0.10.2 (tokens):** the session token tally (`session_tokens`/`session_tokens_seen`/
  `session_add_tokens` — running sum + a seen-flag for omit-until-present; cleared by
  `/reset`). **0.10.3 (cost):** the session cost tally (`session_cost_micro`/`_seen`/
  `_unpriced_count` + `session_add_cost`/`session_note_unpriced`) and the pure `cost_fmt`
  `$d.cc` formatter (truncates down); also cleared by `/reset`.
- `src/roundlog.cyr` — **0.7.0**: the session-local agentic tool-**round** trace
  `/audit` surfaces. A ring (last 16 rounds) of `{turn, round, calls[]}` with each
  call's verdict (`allow`/`deny`/`noname`) + ok/err; recorded by the agentic loop
  (`roundlog_open`/`roundlog_add_call`), rendered by `roundlog_report`, cleared by
  `/reset`. Display-only loop-structure view, orthogonal to and independent of
  t-ron's security chain — owns no security logic, never touches the libro chain.
- `src/config.cyr` — `thoth.cyml` runtime config (`[hoosh]`, **M4:**
  `[daimon]` url, `[tron]` policy/agent; **0.5.0:** `[hoosh].stream`
  bool via a `_cfg_bool` reader; **0.5.1:** `[hoosh].history`; **0.5.2:**
  `[log].file` / `[log].level`; **0.10.3:** the `[pricing.<model>]` table — `_price_load`
  caches each model's `input`/`output` rate (micro-USD per 1K tokens) into a stable fixed
  table at load, `config_price_input`/`_output` look it up verbatim by model id, `_cfg_int`
  parses an integer rate (`-1` absent, `0` explicit-free); **0.11.4:** the `[alias]` table —
  `_alias_load` caches each `name = "expansion"` pair into a stable fixed table (cap 64;
  blank skipped, duplicate key keeps the first, a name ≥ 256 chars skipped as unmatchable),
  `config_alias_lookup`/`config_alias_count`).
- `src/log.cyr` — **0.5.2**: structured driver-event logging over the vendored
  sakshi logger. `log_init` binds to `[log]` (off unless configured); the pure
  `event=… key=value` builder (`log_begin`/`log_kv_str`/`log_kv_int`/`log_message`)
  + `_log_parse_level` + the level-gated `log_commit`. Instruments `gate.cyr`
  (authz verdicts), `hoosh.cyr` (turn results), `commands.cyr` (model switch).
- `src/hoosh.cyr` — **M3**: the hoosh seam client (request build, sandhi POST,
  response/error extraction). **M5**: `hoosh_build_request` takes a `system`
  param; `hoosh_send` passes the avatara persona as a `{role:system}` message.
  **0.5.0:** SSE streaming — `hoosh_build_request` gained a `stream` param;
  `_hoosh_stream_turn` + `_hoosh_sse_cb` print `hoosh_extract_delta` deltas as
  the frames arrive (default on, `[hoosh].stream=false` reverts to blocking).
  **0.5.1 (multi-turn):** `hoosh_build_messages` + `_hoosh_history_start`
  serialize the byte-budgeted conversation tail; `_hoosh_blocking_turn` extracted;
  both turn paths leave the reply in `_hoosh_acc` for history; `HOOSH_REQ_CAP`
  raised to 256 KiB. **0.6.2 (catalog):** `hoosh_list_models` GETs `/v1/models`
  and prints the catalog (`_hoosh_models_url` builds the endpoint, pure
  `hoosh_extract_models` returns the `data` array). **0.10.2 (tokens):** pure
  `hoosh_extract_usage` (+ shared `_hoosh_usage_total`) reads `usage.total_tokens` from a
  blocking body or a streaming usage frame (`-1` when absent); both turn paths feed it to
  `session_add_tokens`; streaming requests send `stream_options:{include_usage:true}` and
  `_hoosh_sse_cb` reads content + usage on one parse. **0.10.3 (cost):** generalized to
  `_hoosh_usage_field(v,key)` (prompt/completion/total); pure `hoosh_cost_micro` +
  `_hoosh_account_usage` price each response at the ACTIVE model's `[pricing]` rate (price-at-
  accumulate) — a half-declared rate degrades to unpriced+noted, never billed at `$0`.
  **0.11.5 (`/dry`):** `hoosh_build_dry` composes the request body NON-destructively (history
  tail + the pending user turn, no append) so `/dry` is side-effect-free; `hoosh_model_cur`
  exposes the exact model precedence; `hoosh_dry_buf` lazily allocates the shared request buffer.
  **0.11.6 (JSON envelope):** `_json_escape_n_into_cap` is the length-bounded escape core (so
  the one-shot reply, held by length, escapes faithfully incl. an embedded NUL);
  `_json_escape_into_cap` now delegates to it at `strlen` (byte-identical for all callers).
- `src/daimon.cyr` — **M4**: the daimon seam client (MCP host registry list,
  tool call build/POST, MCP tool-result extraction). **0.6.0:** `daimon_invoke`
  (invoke + return result as a cstr) and `daimon_tools_value` (fetch the tool
  array) for the agentic loop.
- `src/agent.cyr` — **0.6.0**: the model-driven agentic tool-calling loop.
  Advertises daimon's tools to hoosh (`agent_format_tools`), parses `tool_calls`
  (`agent_tool_calls`/`agent_tc_*`/`_agent_raw_tool_calls`), assembles each
  request (system + budgeted history + ephemeral tool rounds + `tools`), and
  drives the loop (`agent_turn`) — each tool call t-ron-gated, results fed back as
  `{role:tool}`, capped at `AGENT_MAX_ITERS`. `agent_enabled` gates on
  daimon-wired + `[hoosh].tools`. **0.6.1:** streams via SSE when `[hoosh].stream`
  is on (content live; `tool_calls` assembled from fragmented deltas by index, via
  `_agent_accum_delta`/`_ag_build_array`); per-iteration split into
  `_agent_iter_stream`/`_agent_iter_block` with a shared outcome.
- `src/gate.cyr` — **M4**: the t-ron authorization choke point (`gate_init` /
  `gate_authorize`) + the fail-closed `confirm` fallback. **0.5.0:**
  `gate_audit_report` surfaces t-ron's libro-backed audit chain (counts,
  integrity, risk score, recent events) for the `/audit` command; the pure
  `audit_kind_str` verdict-label is thoth's only glue over it.
- `src/exec.cyr` — the portable local shell escape for `/run`.
- `src/util.cyr` — buffered stdin `read_line`, `emit`/`emit_n`, small helpers.
  **0.9.1:** the **output-capture sink** — `_out_mode` (OUT_FD1 default / OUT_RING),
  `out_mode`/`out_mode_set`, `emit_raw`/`emit_raw_n` (always fd 1, blind to the mode —
  the TUI chrome + painter use these), the OUT_RING branch in `emit`/`emit_n` (→
  `feed_write`), and the mode-aware stdlib shadows `oprintln`/`ofmt_int` (byte-identical
  to `println`/`fmt_int` under OUT_FD1; the 9 dispatch files call these so their output
  is captured under OUT_RING). **0.11.0:** the **`OUT_NULL`** discard mode (one-shot arms
  it around the turn so chrome is suppressed), `emit_err`/`emit_err_n` (always fd 2, for
  one-shot diagnostics), and the `_one_shot` flag (`one_shot_active`/`one_shot_set` — the
  t-ron confirm reads it to fail closed).
- `src/oneshot.cyr` — **0.11.0**: the one-shot / argv front-door. PURE + unit-tested:
  `_oneshot_parse` (the argv classifier → `ONESHOT_NONE`/`RUN`/`VERSION`/`HELP`, joining
  positionals into a bounded heap task buffer) + `oneshot_mode` (snapshots `argc`/`argv`).
  I/O: `_oneshot_append_stdin` (slurps stdin as the payload when fd 0 is not a tty) and
  `one_shot_run` (runs the turn under `OUT_NULL`, then prints only `hoosh_last_reply` to
  fd 1; stderr error + nonzero exit otherwise). Routes through the existing
  `cmd_task → hoosh_send/agent_turn` seam — no new spine path. [ADR-0011]. **0.11.6 (JSON envelope):** the `--json`/`-j`
  modifier flag (an `elif` on the `-p` chain — sets `_oneshot_json` without forcing a run;
  reset before the `n<=1` early return) + the pure `oneshot_json_envelope`
  (`{response, model, turns, tokens?, cost?, elapsed_ms}`; reply escaped by length,
  tokens/cost omit-until-present, `elapsed_ms` via `clock_now_ms`); a sized buffer
  guarantees valid JSON; failure emits nothing to stdout in either mode. **0.11.7 (`-o`
  tee):** the `-o`/`--out <file>` modifier flag (consumes the next argv token as the path,
  not a positional; does not force a run; reset before the early return) + `_oneshot_write_out`
  (writes the answer + a trailing newline so the file matches stdout, create+truncate at 0644
  via the portable `lib/io.cyr` wrappers; degrades closed). The user's OWN redirection — NOT
  t-ron-gated (the path is argv-fixed before the turn; the model can't influence it). **0.11.8
  (shell completion):** the `--completion`/`--completions <shell>` print-and-exit mode
  (`ONESHOT_COMPLETION`, short-circuits like `--version`, captures the next token as the shell →
  default bash, unsupported → stderr + nonzero) + `oneshot_print_completion` →
  `_completion_bash`/`_completion_zsh` (EMIT static scripts; no spine path / security surface;
  flag lists mirror `_oneshot_parse`).
- `src/feed.cyr` — **0.9.1**: the self-managed T2 feed. A ring (2048 lines × 2 KiB, one
  4 MiB bump alloc) capturing dispatch output (`feed_write` seals a slot per newline,
  evicts oldest O(1) when full; escape-boundary-aware store truncation), plus the PURE
  load-bearing `feed_clip(dst, dst_cap, src, src_len, max_cols)` — paints a stored line
  into a width-W column, color escapes verbatim (zero width), never severing a CSI /
  UTF-8 glyph, suppressing `ESC[…K`, `dst_cap`-bounded. The painter (`feed_repaint`),
  the dispatch-window capture (`tui_run_line`), and the confirm bracket
  (`tui_confirm_begin`/`_end`, called from `gate.cyr`) live in `src/tui.cyr`. Replaces
  0.9.0's DECSTBM scroll-region; the prerequisite for the file-tree pane + SIGWINCH.
  **0.9.2:** `feed_repaint` also renders the unsealed pending line (incremental streaming
  paint via `feed_stream_tick`, pinged from the SSE callbacks). **0.11.3 (soft-wrap):** the
  PURE `feed_clip_seg(dst, dst_cap, src, src_len, skip_cols, max_cols)` paints a visible-column
  WINDOW of a stored line (carries SGR color across a wrap via a 64-byte whole-or-drop carry;
  same CSI/UTF-8/`ESC[…K`/`dst_cap` guarantees as `feed_clip`, which is UNCHANGED), plus
  `feed_rows_for` (`ceil(vis/width)`, blank = 1 row) and `_feed_total_phys` (the document's
  soft-wrapped height); `feed_scroll()` is redefined to PHYSICAL rows. `feed_repaint`
  (`src/tui.cyr`) now reflows each wide line across rows instead of truncating, and
  `tui_relayout` clamps the scroll offset on a width change.
- `src/ftree.cyr` — **0.9.3**: the file-tree pane. PURE + unit-tested: the tree/feed
  layout geometry (`tui_tree_w`/`tui_feed_left`/`tui_feed_width`) and the flattened-tree
  model (parallel fixed-slot arrays; `_ftree_insert_at` splices children on expand,
  `ftree_collapse_at` removes a subtree, `ftree_path` reconstructs an absolute path by
  walking ancestors). I/O (live): `ftree_load`/`ftree_expand` list directories via
  `lib/fs.cyr` `dir_list`/`is_dir`, dirs-first, rooted at `$PWD` (portable — no
  `SYS_GETCWD`). The paint (`tui_draw_tree`: tree cols `[1, tree_w]` + `│` separator, a
  reverse-video selection bar) + the nav keys (Ctrl-B/Tab/↑↓→← + focus) live in
  `src/tui.cyr`; `feed_repaint` paints the feed into `[tree_w+2, cols]` when shown.
- `src/inhist.cyr` — **0.11.1**: the composer input-history recall ring. PURE +
  unit-tested: a 128-slot ring of SUBMITTED lines (same shape as `src/feed.cyr` — head/
  count/`% INHIST_CAP`, O(1) eviction) with `inhist_push` (ignoredups vs the newest +
  skip-empty), `inhist_entry_ptr`/`_len`, and the nav cursor
  `inhist_nav_up`/`_down`/`_reset`/`_at_draft`/`_pos` over `[0, count]` (count == "the live
  draft"). DISTINCT from the multi-turn conversation history (`session_history_*`). The TUI
  glue (`_tui_recall_*` — draft stash + load-into-composer) and the Up/Down `tui_loop`
  binding (composer focus, palette-gated) live in `src/tui.cyr`; TUI-only, so the REPL/piped
  floor is untouched. **0.11.2** adds the OPT-IN persistence I/O section (gated on
  `[history].file`): `_inhist_load_file` (streaming load → ring), `_inhist_probe_writable`
  (non-destructive create-if-absent at 0600, no truncate), `_inhist_write_file`
  (rewrite-the-ring on save; checks write returns → -1 on short write), and
  `inhist_persist_init`/`_save`/`_active`/`_broke`/`_broke_ack` — degrade-closed (unwritable
  or mid-session write failure announced, never faked). Portable via lib/io.cyr
  (`file_open`/`_read`/`_write`/`_close`); 0600 is the best-effort CREATE mode, never
  asserted in the UI.
- `src/vendor/` — committed spine dist bundles. **M4**: `bote-core.cyr`
  (bote 2.7.3, the MCP protocol), `t-ron.cyr` (t-ron 2.1.5, authorization),
  `libro.cyr` (libro 2.7.2, t-ron's audit chain). **M5**: `avatara.cyr`
  (avatara 2.7.1, the Thoth/Librarian archetype). Re-sync via
  `scripts/sync-{bote,tron,libro,avatara}.sh`; never hand-edit.

Binary: ~2.6 MB (`build/thoth`, x86_64-linux) — the sandhi/TLS transport
surface plus the four vendored spine bundles dominate (most of the avatara
bundle is DCE-unreachable).

## Tests

- `tests/thoth.tcyr` — **599 assertions** over the pure logic: M2's
  `classify_input`, `token_is` / `arg_after`, the seam registry, session state,
  `cstr_starts_with`; M3's JSON escaping, chat-request building,
  response/error extraction, config defaults, and the copy-on-set model
  switch; M4's daimon call building + MCP result extraction, t-ron verdicts
  through the real vendored engine (allow/deny globs, deny-by-default unknown
  agent/tool — doubling as the libro `chain_append` SIGILL canary), and the
  `[daimon]`/`[tron]` config defaults; M5's persona group (identity sourced from
  the avatara archetype, soul/spirit prose, the built system prompt) and the
  hoosh request-shape cases (no system preserves the prior shape, empty system
  omitted, non-empty system prepended as `{role:system}`); and **0.5.0's**
  audit group — three real `tron_check` calls then asserting the logged
  event/denial counts, the libro chain length + integrity, newest-first
  ordering, and the pure `audit_kind_str` label; and **0.5.0's** streaming
  group — the `stream:true` request shape, `hoosh_extract_delta` across
  content/role-only/finish/`[DONE]` frames, and the `[hoosh].stream` toggle
  through the real TOML parser; and **0.5.1's** multi-turn group — history
  append/accessors + the stable-copy guarantee, pop/clear, the drop-oldest cap,
  `_hoosh_history_start` budgeting, and the `hoosh_build_messages` shape; and
  **0.5.2's** logging group — the structured `event=… key=value` builder (incl.
  null-value `-` and negative ints), the `_log_parse_level` cases, and the
  `[log]` config defaults / `log_active`-off; and **0.6.0's** agentic group —
  tool advertisement formatting, `tool_calls` parsing (id/name/arguments + the
  no-calls case), the raw tool_calls extractor, the agentic request shape,
  `agent_enabled` gating, and (**0.6.1**) the streamed delta assembly (fragmented
  `arguments` reassembled, re-parsed through the same accessors); and **0.6.5's**
  capability-ladder group — the effect-state resolver (vendored seams full,
  hoosh/daimon absent unconfigured, t-ron degrades closed not absent), the
  `cap_state_label` cases, and the full/fallback prose semantics. The 0.7.0–0.9.1
  groups extend it: **0.7.0** `test_roundlog` + `test_parallel` + `test_bounds_hardening`
  (the agentic tool-round trace, the parallel snapshot copy, the untrusted-input clamp);
  **0.8.x** `test_ui` + `test_diff` + `test_highlight` (the presentation surface, the
  LCS diff core, the vyakarana highlighter); **0.9.0** `test_tui` (the composer line
  editor + layout geometry + palette matchers); and **0.9.1** `test_feed` +
  `test_feed_ring` + `test_capture` (the escape-aware clip — width/`dst_cap`/`ESC[K`/
  UTF-8 — the ring seal/evict/flush machine, and the OUT_RING capture sink's
  logical-line reconstruction + `oprintln`/`ofmt_int` byte-identity); and **0.9.2**
  `test_spinner` (the pure braille frame cycle — `spin_glyph` mod `SPIN_FRAMES`,
  `spin_advance`); and **0.9.3** `test_ftree` (the file-tree layout geometry +
  flattened-tree model: append/insert/move-clamp/collapse-subtree, the ancestor-walk
  `ftree_path`, and a real `src/` dir-listing smoke); and **0.9.4** the `/clear`
  classification, `feed_clear` (ring + scroll reset), and the `/c` palette match; and
  **0.10.0** `test_theme` (the theme axis — dark byte-identical anchor, the light palette,
  the T1 SGR-table rebuild on a switch, and the PT_PLAIN floor staying empty under both
  themes); and **0.10.2** `test_usage` (the token producer — `hoosh_extract_usage` across a
  blocking body, a streaming usage frame, a plain delta, a `usage` without `total_tokens`,
  and an unparseable body; the session accumulator's sum / seen-flag / absent-ignored /
  `/reset`-clears semantics); and **0.10.3** `test_cost` (the pricing math, the `$d.cc`
  formatter truncating down, the `[pricing.<model>]` table with verbatim dashed-id match +
  missing-key→`-1`, the cost accumulator + honest-omit flags, an end-to-end price-at-accumulate
  assertion through the active model, and the unpriced- + half-declared-model degrade paths);
  and **0.11.0** `test_oneshot` (the pure argv classifier — `NONE`/`RUN`/`VERSION`/`HELP`,
  the `-p` force, flag-vs-positional, positional joining — and the bounded task buffer,
  driven by a hand-built argv snapshot); and **0.11.1** `test_inhist` (the input-history
  ring — store/ignoredups/skip-empty/eviction/order — the full nav state machine
  draft↔newest↔oldest with clamps + the draft boundary, and the composer load/stash/restore
  glue); and **0.11.2** `test_inhist_persist` (the opt-in history file — load→ring, the
  NON-DESTRUCTIVE-init guarantee (file bytes unchanged after binding), save→rewrite→reload
  round-trip, the unwritable-path degrade; the 0600 create-mode asserted empirically by
  `stat` after the suite); and **0.11.3** `test_softwrap` (`feed_rows_for`, the windowed
  `feed_clip_seg` — skip/window, SGR continuity across a wrap + cumulative carry, `ESC[K`,
  `dst_cap`, UTF-8, and a forced-PT_ANSI defensive-close proof — and `_feed_total_phys`); and
  **0.11.4** `test_alias` (the `[alias]` table load — blank/dup-first-wins/over-256-name skip —
  the bare-token name extraction, `alias_expand` value+args assembly, per-depth buffer
  disjointness, and the no-alias byte-identical floor); and **0.11.5** `test_dry` (the exact
  `hoosh_build_dry` body shapes — bare/system/streaming/history-tail — and the no-mutation
  invariant); and **0.11.6** `test_json_envelope` (the `--json`/`-j` flag parse and the
  envelope across field combos — incl. the embedded-NUL by-length escape and model-id escaping);
  and **0.11.7** `test_oneshot_out` (the `-o`/`--out` parse — path-not-a-positional, dangling
  `-o`, reset, `--json` composition — and the writer round-trip + trailing-newline + degrade);
  and **0.11.8** `test_completion` (the `--completion`/`--completions` parse — COMPLETION mode,
  the captured shell, default/reset/short-circuit; the emitted bash/zsh scripts are
  host-validated by `bash -n`/`zsh -n` + a functional `COMPREPLY` check).
  Passes
  on `cyrius test`.
- `tests/thoth.bcyr` — benchmark stub (no-op).
- `tests/thoth.fcyr` — fuzz stub.

## Dependencies

**Current (declared in `cyrius.cyml`, all stdlib).** Driver core: `string`,
`fmt`, `alloc`, `io`, `vec`, `str`, `slice`, `syscalls`, `result`, `tagged`,
`process`, `assert`, `bench` (`result` / `tagged` / `process` back the
portable `/run` shell escape). Data formats: **`bayan`** — the Cyrius 6.1.25
data-domain carve (json / toml / cyml / base64 / bigint / u128 / csv in one
distlib fold); it carries both the `thoth.cyml` config surface (with `fs`)
and the JSON wire format, and must precede `sigil` (u256) and the transport.
Call sites use the canonical `bayan_*` names. M3 hoosh transport: **`sandhi`**
(the HTTP/TLS client, folded into stdlib as `lib/sandhi.cyr`) plus its full
transitive set — `net`, `http`, `tls`, `ws`, `sakshi`, `sigil`, `args`,
`hashmap`, `thread`, `thread_local`, `fnptr`, `async`, `atomic`, `chrono`,
`mmap`, `dynlib`, `fdlopen`, `freelist`, `ct`, `keccak`. (`sakshi` arrived as a
sandhi transitive; **0.5.2** consumes it directly for thoth's structured driver
log — `src/log.cyr`.) M4 vendored-bundle
surfaces: `regex` (t-ron's policy `glob_match`), `random` (sigil's ML-DSA /
AES-GCM refs), `patra` (libro's structured logging). M5 vendored-bundle surface:
`math` (the avatara bundle's `f64_le`/`f64_ge`; the other f64 ops are builtins).
**Ordering constraint
(M4):** `atomic`/`thread`/`thread_local`/`ct`/`keccak`/`random` must precede
`sigil`, or libro's `chain_append` SIGILLs (sigil's hash path self-installs a
per-thread scratch bank) — t-ron 2.1.5's documented note, now thoth's too.
Libs are opt-in and Cyrius does **not** resolve transitive deps, so the set
is declared by hand and ordered low-level-floor-first (see the `[deps]`
comment in `cyrius.cyml`).

**sandhi conn-off-fd collision — RESOLVED (cyrius 6.2.40, 2026-06-24).** A prior
toolchain-bundled sandhi (**1.6.12**, cyrius 6.2.39) carried a critical client bug:
the server and client conn structs both defined `enum SandhiConnOff` with
`SANDHI_CONN_OFF_FD` at different offsets (client 8 / server 16); under cyrius
last-definition-wins the client resolved it to 16, colliding with its own
`SANDHI_CONN_OFF_TLS_CTX` — `finalize` zeroed the socket fd, so every hoosh request
went to fd 0 and the gateway saw nothing. **Fixed in sandhi 1.6.13** (server offsets
namespaced to `SANDHI_SRVCONN_OFF_*`) and folded into the toolchain at **cyrius
6.2.40**; thoth has stayed on the **stdlib `"sandhi"`** entry (pristine `lib/`) the
whole time — no `[deps.sandhi]` pin was ever needed. thoth is now on **6.2.43**
(0.10.1), so this is closed; recorded as the canary for the dep-style-vs-stdlib-style
ordering hazard (a `[deps.sandhi]` block perturbs thoth's hand-ordered stdlib set and
breaks `patra`'s `SK_WARN` resolve — keep sandhi as a plain stdlib entry).

**Vendored (committed dist bundles in `src/vendor/`, not `[deps]` blocks):**
bote-core **2.7.3**, t-ron **2.1.5**, libro **2.7.2** (t-ron's audit chain;
keep in lockstep with t-ron's own `[deps.libro]` pin), avatara **2.7.1** (the
Thoth/Librarian archetype; needs the `math` stdlib dep, carries a benign
`ERR_NONE = 0` matching libro's and a self-contained `xalloc`). bote's and
t-ron's manifests declare git sub-deps that `cyrius deps` resolves
transitively into colliding compile sets, so the self-contained bundles are
consumed directly — the pattern hoosh established (avatara likewise ships a
`cyrius distlib` bundle, not a server). Re-sync via
`scripts/sync-{bote,tron,libro,avatara}.sh <tag>`.

**Spine seams.**

- **hoosh** — LLM inference gateway: **wired (remote-client over HTTP via
  sandhi)**. Consumed as a running gateway, not a linked crate (hoosh ships no
  distlib — it is a server). Re-verified at hoosh **2.4.5**; its 2.2.3–2.4.5
  growth (tool calling, batch, `/v1/tools/*` MCP endpoints, DLP, observability,
  17 providers, configurable routing strategy) is server-side or M4+ seam
  material — the chat contract thoth consumes is unchanged. See
  [ADR-0005](../adr/0005-hoosh-seam-remote-over-sandhi.md).
- **daimon** — agent orchestration + MCP tool execution + host registry:
  **wired (remote-client over HTTP via sandhi)** when `[daimon].url` is
  declared. `/tools` lists the registry, `/call` invokes. **Re-verified
  wire-compatible against daimon 1.2.6** (2026-06-11), which ships the fix for
  the registry-aliases-request-buffer bug thoth filed. 1.2.6's `GET
  /v1/mcp/tools` returns the manifest `{"tools":[{name,description}],"count":N}`
  (thoth parses, ignores `count`) and `POST /v1/mcp/call` passes the upstream MCP
  `result` through (`content[0].text` + `isError`); both match thoth's seam — no
  code change needed. Round-trip confirmed against a 1.2.6-faithful mock (real
  daimon's server binary won't run inside thoth's build sandbox — signal 16 — so
  full-stack live e2e is a host-side step).
- **bote** — the MCP protocol: **wired (native — vendored bote-core 2.7.3,
  in-process)**.
- **t-ron** — MCP per-tool authorization: **wired (native — vendored t-ron
  2.1.5 + libro 2.7.2, in-process)** when `[tron].policy` loads; otherwise
  absent with the fail-closed confirm gate standing in, announced. Deny is
  final; unknown agents/tools deny by default.
- **avatara** — personality / archetype overlay; the Thoth / Librarian persona:
  **wired (native — vendored avatara 2.7.1, in-process)**. The persona is sourced
  from `egyptian_thoth()` (the `prof_*` accessors) and threaded into the hoosh
  system prompt; native by construction (always available from the bundle). See
  [ADR-0007](../adr/0007-m5-avatara-seam-native-persona-system-prompt.md).

The off-AGNOS reach transport vs. the AGNOS-native binding distinction is
deferred to a later ADR.

## Known limitations

- All five seams are wired; no seam is absent by milestone. The avatara persona
  is a fixed archetype (`egyptian_thoth`), not runtime-switchable, and reached
  only as the vendored bundle — the live/co-resident avatara binding is the same
  deferred reach-transport question as the other native seams.
- t-ron's bundle carries a benign `ERR_NONE = 0` shared with libro's identical
  constant (same value; last definition wins) — re-check on bundle bumps.
- **daimon registry bug — RESOLVED in daimon 1.2.6** (was 1.2.4): the MCP host
  registry aliased the transient request buffer, corrupting registrations as
  later requests arrived. Filed by thoth as
  `daimon/docs/development/issues/2026-06-11-mcp-registry-aliases-request-buffer.md`;
  fixed upstream (daimon commit `6af75a4`). thoth's seam is re-verified
  wire-compatible with 1.2.6 (see the daimon seam note above). Full-stack live
  e2e (thoth → t-ron → real daimon → bote MCP → back) is a host-side step —
  daimon's server binary won't run inside thoth's build sandbox (signal 16).
- thoth is **not** exposed to the cyrius address-taken-local-array static-overlap
  bug daimon hit in 1.2.6 (its `docs/.../cyrius-addr-taken-local-array-static-overlap`):
  that needs an 8-byte-slot `var a[N]` written at its last slot via `store64(&a…)`;
  thoth's address-taken locals (`tmp[24]`, `line[4096]`, `ans[64]`) are byte
  buffers written via `store8` within bounds. Re-check if a `store64(&local…)`
  is ever introduced.
- t-ron's bundle duplicates sigil's `chacha20_xor` (same signature and
  semantics; last definition wins) — benign per t-ron's own 2.1.5 notes, but
  worth re-checking on sigil bumps since sigil's TLS ChaCha20 path now runs
  t-ron's copy.
- t-ron authorization is per-tool name + payload scan; the model-driven turn
  (`free text` → hoosh) is not a gated action (it executes nothing locally).
- hoosh responses **stream by default** (**0.5.0**): SSE deltas print as
  they arrive (`[hoosh].stream=false` reverts to the blocking round-trip). One
  asymmetry: the streaming result exposes the HTTP status but not the body, so a
  non-2xx *error message* is only surfaced in blocking mode — streaming announces
  the status and points the user at `stream=false`.
- The hoosh request carries the avatara persona as a `{role:system}` message
  (M5) and (**0.5.1**) the multi-turn conversation tail (`[hoosh].history`,
  default on; `/reset` clears it). Remaining fixed bits: `max_tokens` 4096 and no
  other request tuning. Context is a byte-budgeted window (oldest turns drop) held
  in-process only — not persisted across runs. `[hoosh].history=false` reverts to
  the stateless single-turn shape.
- t-ron audit events live in its in-process libro ring; **0.5.0's** `/audit`
  surfaces them (counts, chain integrity, agent risk score, recent events). The
  audit view is read-only and session-scoped (the ring is in-process, not
  persisted across runs). **0.5.2** adds thoth's own **sakshi-structured driver
  log** (`[log]`, off by default; `event=… key=value` for turns, authz verdicts,
  model switches) — operational, distinct from t-ron's cryptographic chain. It
  covers the driver event spine but not yet every command (`/read`, `/tools`,
  `/call` results are not logged); broaden as needed.
- `/read` is read-only but unrestricted; sandboxing posture stays with t-ron,
  not an in-tree allowlist.
- `/write` takes single-line content; multi-line editing is future work.

## Consumers

_None yet._ — "at least one downstream consumer green **on AGNOS**" is **v1.0 gate 2**
(see [`roadmap.md`](roadmap.md) → *Path to v1.0*); it follows gate 1 (the AGNOS lane
lighting up). A tracked blocker, not a gap to fill in-tree.

## Next

See [`roadmap.md`](roadmap.md) for the sequencing. **M0–M7 are done and shipping** (0.1.0 →
0.11.8): the driver core, the hoosh seam (inference + mid-session model switch), the M4 tool
spine (daimon/bote/t-ron), the M5 avatara overlay, the model-driven agentic loop with
**parallel tool execution** + `/audit` tool-rounds (0.7.0), the M6 multi-target build ladder +
the live capability ladder (0.6.5), the M7 presentation ladder (T1 amber/colored diffs 0.8.x →
the T2 rich-TUI 0.9.x → `/theme` 0.10.0), the **0.10.x data producers** (tokens 0.10.2 + cost
0.10.3, honest-omit per [ADR-0010](../adr/0010-data-producer-honest-omit.md)), and the **0.11.x
terminal-citizen line in full** — the one-shot/argv front-door (0.11.0), input-history recall +
opt-in persistence (0.11.1–0.11.2), feed soft-wrap (0.11.3), `[alias]` prompt macros (0.11.4),
`/dry` (0.11.5), `--json` envelope output (0.11.6), `-o`/`--out` file tee (0.11.7), and shell
completion (0.11.8).

**Remaining work is no longer thoth feature work.** The leftover 0.11.x riders are deferred
(live spine-health — not yet wanted) or AGNOS-impossible (clipboard — needs an upstream cyrius
`process` stdin-feed primitive); the rainbow theme is deferred (needs **anuenue** vendored); and
the **0.12.x git producer** is externally gated on **sit** shipping `.git/` read-mode (thoth
never hand-rolls a `.git/` parser — ADR-0010).

**The path to v1.0 is dominated by AGNOS lighting up, not by feature work in
thoth.** Four gates (see [`roadmap.md`](roadmap.md) → *Path to v1.0*): (1) the AGNOS
lane clears once the agnos peer ships the `SIGHUP` signal-number constants (filed
upstream; zero thoth change); (2) ≥1 downstream consumer green on AGNOS (external);
(3) a security review (not scheduled); (4) the SemVer-vs-CalVer 1.0 decision
(deferred ADR-0004). x86_64 Linux ships; aarch64 builds; macOS builds+runs (audit
path gated upstream); Windows staged on architectural floor gaps. Full-stack live
e2e against the real spine (hoosh/daimon) is a host-side step — the build sandbox
blocks a compiled binary's TCP.
