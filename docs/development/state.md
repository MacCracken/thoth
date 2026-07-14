# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.38.0** — **`/theme rainbow`** (2026-07-14). The last deferred theme lands, consuming the newly-vendored
**anuenue 1.2.0** (`src/vendor/anuenue.cyr`, `scripts/sync-anuenue.sh`) — anuenue grew a `[lib]` profile for this
consumer, exporting ONLY its pure HSV geometry (`ANUENUE_PHASE_MOD` + `hsv_rainbow`, standalone over zero deps).
thoth authors only the phase→SGR glue; it never reimplements the hue (spine rule). rainbow is a **per-grapheme
render mode, not a role table**: the hue advances `UI_RAINBOW_STEP` (18) per GLYPH (not per byte — a 3-byte UTF-8
glyph is one step), 85 glyphs per cycle. It still CARRIES the dark role table, so chrome (status/tree/labels) stays
readable while prose cycles. **Two hooks, mutually exclusive by sink** — because the sealed feed slot is
`FEED_LINE_CAP` (2048 B) and a ~19-byte escape per glyph would overflow it past ~100 cols and DROP TEXT (which is
exactly why the feed stores 2-byte role MARKERS): the LINE tier tints at `ui_emit` (OUT_FD1 only), and the TUI tints
at PAINT (`feed_clip_seg`, budget `PAINT_CAP` = 24 KB), hued by VISIBLE COLUMN so a repaint is deterministic and
`feed_repaint` recolors scrollback instead of shimmering. Invariant: **color is best-effort, text is not** — an
exhausted `dst` emits the glyph UNTINTED rather than dropping it. Degrades honestly: needs **truecolor** (1530 hues
don't survive a 256/16 quantize) — below it `/theme` switches but ANNOUNCES why it isn't cycling; PT_PLAIN stays
byte-identical (verified: 0 escapes). **Live-verified on a pty** both tiers (line: per-glyph hues continuing across
turns; rich TUI: 92 distinct hues painted). Also **fixed** the ⌃T toggle: `1 - ui_theme()` hardcoded a two-theme
flip, so from rainbow it produced `-1` (an invalid theme) and the next press turned `-1` back into rainbow —
stranded. Now cycles `% UI_THEME_COUNT` (dark → light → rainbow → dark), which is what that constant was for.
Suite green (247 + 1525 + 180 + 3). Pin **6.4.62**. **NEXT**: the GUI tier (its own `OUT_NULL` renderer leaf never
sees these hooks).

**0.37.0** — **Hardening pass** (2026-07-14; no new features). Fixed a heap overflow: the shell capture/result
buffers were alloc'd once at `[shell].max_output`, but `/reload` re-parses it — raising the cap then re-running a
command overran the old smaller block; `_shell_bufs_ensure()` now re-allocs on any cap change (adversarially reviewed
complete; `test_shell_bufs_realloc` locks it in; happy-path confirmed live). Bounded the deny-message glob copy
(pre-existing, review-surfaced). Deleted the dead UNBOUNDED escaper twins (`_json_escape_into` / `_hoosh_emit_msg`) —
every live build uses the bounded core; test migrated (byte-identical). Fixed the stale `alloc(32)`→`alloc(48)`
message-struct comment. Suite green (247 + 1497 + 180 + 3). **Audited, deferred (need dep releases):** the ~89%
`fn_table` / identifier ceilings (levers are the sit read-carve + a bote jsonx micro-profile; `CYRIUS_DCE` does NOT
help); the 13 MB static-data warning is vendored-sigil and unfixable from thoth. Pin **6.4.62**.

**0.36.5** — **`/save` JSON + plain exports** (2026-07-13). `/save --json <file>` writes one machine-readable
object (`{"thoth", "messages":[{role,content,model?}]}`) for jq/CI; `/save --plain <file>` writes bare
`role: content`; bare `/save` is unchanged (markdown, byte-identical). Both new formats are TIER-NEUTRAL (the
conversation, not the rendered scrollback). JSON builds one message at a time into a bounded buffer and flushes, so
a long history can't outgrow it (a reply can be 64 KiB; escaping can sextuple it). Unit-tested (flag parse, escaping
of quotes/newlines, no scaffolding leakage, markdown default intact) + live-verified (the export parses as valid
JSON). Suite green (247 + 1490 + 180 + 3). Pin **6.4.62**. **NEXT**: model-picker health/pricing if hoosh exposes
it; otherwise the 0.36.x arc is complete and the four v1.0 gates remain.

**0.36.4** — **History overflow: honest, and optionally summarized** (2026-07-13). thoth had TWO overflows with
opposite semantics and reported only the harmless one: the framer's byte budget merely SKIPS messages (still in the
store/feed/`/save`) yet said "N oldest **evicted**"; `SESS_HIST_MAX` **permanently frees** message #41 and said
nothing. Now `conv_dropped` counts real losses and `/state` splits all three: `N oldest not sent · N recapped ·
N dropped from the record`. **`[hoosh].summarize`** (default off — it spends an extra call) adds a cheap, silent,
isolated side-call that recaps the skipped range into a system message, cached per conversation and folded
INCREMENTALLY (previous recap + only newly-skipped messages = one small bounded call per advance); wired into both
framers; usage accounted; any failure degrades to an honest gap, never a faked recap. Also fixed a latent OOB
(`conv_load_add`, the resume path, hadn't grown with the conv struct). **Live-verified** (26-turn overflow:
`35K / 32K · 3 not sent · 3 recapped · 2 dropped`), which caught a real bug — the cap drops from the FRONT and
shifts indices, so recap coverage went stale and failed its own guard; coverage now shrinks with drops, making the
recap a SUPERSET that still describes what the cap destroyed. Suite green (247 + 1474 + 180 + 3). Pin **6.4.62**.
**NEXT (0.36.x)**: `.5` export formats.

**0.36.3** — **Tables in the terminal: mdhl renders an aligned grid** (2026-07-13). Completes the tables story (GUI
got them in `.1`): header cells `ROLE_ACCENT` above a faint rule, body cells padded to each column's widest value +
aligned per the delimiter; widths via `feed_visible_cols` (SGR/wide-glyph aware). Detection reuses the shared model
(`md_is_delim_row`/`md_row_split`/`md_cell_align`) with the same GFM rule as the GUI (pipe header + matching-column
delimiter). **No streaming latency**: rides mdhl's 0.18.3 live-card trick — prose streams as always, and a delimiter
under a matching header DROPS the header's sealed feed row (`feed_drop_last(1)`) and buffers, re-emitting the grid on
close. `_mdhl_live()`-gated (OUT_RING), so the line REPL + `PT_PLAIN` floor keep raw-pipe bytes, byte-identical.
**Adversarially reviewed** — rewind confirmed sound; all three dimensions caught + reproduced a **major byte loss**:
a table's rows never stream (the buffer is their only copy), so an over-`MDHL_TBL_CAP` table silently dropped the
tail (600 rows → 212 lost) and the fallback dropped the delimiter. Fixed: overflow **spills** header+delimiter+rows
verbatim then streams the rest (bytes always complete); an over-`MDHL_TBL_MAXW` grid spills too. `test_mdhl_table` +
`test_mdhl_table_overcap` (asserts the exact 503-row count). Suite green (247 + 1451 + 180 + 3). Pin **6.4.62**.
**NEXT (0.36.x)**: `.4` summarize-on-overflow; `.5` export formats.

**0.36.2** — **One markdown classifier: mdhl driven by the shared model** (2026-07-13). mdhl's prose + inline
classification (`_mdhl_inline_line`/`_mdhl_emit_inline`) now drives from `src/mdmodel.cyr` (`md_classify` +
`md_inline_scan` runs) instead of its own predicates — line/TUI and GUI share ONE classifier; the six duplicated
functions (`_mdhl_heading`/`_blockquote`/`_list_emit`/`_find_byte`/`_find_bold`/`_inline_scan`) are gone.
**Byte-identical** for line/TUI (verified by `test_mdhl_inline` strip-coverage + exact bold-`ESC[1m` count); the
fenced-code path + the `PT_PLAIN` verbatim floor are untouched. **Adversarially reviewed** — caught + fixed a real
byte-drop I introduced: the shared `md_inline_scan` caps runs at `MD_RUN_CAP=512` (the GUI is fine — it colors
per-byte via `md_role_at`), but `_mdhl_emit_inline` iterated only recorded runs, dropping the tail on a >512-span
line; now it emits any uncovered tail verbatim (`test_mdmodel_runcap` guards it). Suite green (247 + 1451 + 164 + 3).
Pin **6.4.62**. **NEXT (0.36.x)**: `.3` line/TUI table rendering (mdhl buffers + emits an aligned grid via the model
— the `.1`-deferred piece); `.4` summarize-on-overflow.

**0.36.1** — **Pipe tables in the GUI** (2026-07-13). GitHub-style pipe tables (header + `|---|:--:|--:|` delimiter +
body) render as an aligned monospace grid: header cells `ROLE_ACCENT` under a faint rule, body `ROLE_MUTED`, columns
padded to the widest cell + aligned per the delimiter. The shared model (`src/mdmodel.cyr`) gained the parsing
(`md_row_split`/`md_is_delim_row`/`md_cell_align`, surface-agnostic so the `.2` mdhl migration reuses it); the GUI
grid layout (`_gfeed_md_table`, two-pass widths→draw) is the feed leaf. Detection needs a `|` header + a delimiter row
with a **matching column count** (so a pipe-prose line above a `---` stays prose). Unit-tested (`test_mdmodel_table` +
`test_gui_table`: parity, row count, alignment, non-table regression guard). **Adversarially reviewed** — caught +
fixed a real false-positive (any-delimiter match → spurious 1-col table), now column-count-gated + regression-tested.
Suite green (247 + 1451 + 161 + 3). Pin **6.4.62**. **NEXT (0.36.x)**: `.2` migrate mdhl onto the model (line/TUI
inherits tables); `.3` summarize-on-overflow.

**0.36.0** — **Structural markdown in the GUI** (2026-07-13; opens the 0.36.x rendering arc). GUI assistant replies
render with structure instead of flat text: ATX headings (`ROLE_ACCENT`), `**bold**` brighter (`ROLE_FG` — fixed
monospace cell, so emphasis is color not weight), `` `inline` `` + fenced code (`ROLE_BLUE`, code on a background
rect), list items (accent marker + hanging indent), blockquotes (indented, faint). Landed reply + live partial (which
degrades on incomplete markdown). Backed by a **new shared model `src/mdmodel.cyr`** — a pure facts-not-bytes
classifier (the reply-render analogue of `surface.cyr`): `md_classify` (block kind + cells), `md_fence_open/_close`,
`md_inline_scan`/`md_role_at` (contiguous plain/bold/code runs). Predicates mirror `mdhl` so a later cut migrates the
line/TUI engine onto it; the GUI feed (`_gfeed_md`, a styled word-wrap switching color per inline run) is the first
leaf. `mdhl` line/TUI untouched (no regression). Unit-tested (`test_mdmodel` + `test_gui_markdown`: parity, structure,
command colors). **Adversarially reviewed** (model / wrap-parity+safety / integration) — all clean; one cosmetic nit
fixed. Suite green (239 + 1451 + 147 + 3). Pin **6.4.62**. **NEXT (0.36.x)**: `.1` tables (shared model + GUI grid +
mdhl); `.2` migrate mdhl onto the model; `.3` summarize-on-overflow.

**0.35.4** — **`/state` surfaces reasoning effort + folded count** (2026-07-13). A new `reason` row in `/state`:
the `[hoosh].reasoning` effort (`off (set …)` or `<effort> effort`) plus the session's reasoning activity — the
number of turns whose reasoning was captured, via the 0.35.3 `reasonlog` (new `reasonlog_total`). The folded count
is the concrete "is reasoning streaming?" signal: 0 on a model that keeps reasoning internal (Opus 4.8) even at high
effort (`· none captured yet (this model may keep reasoning internal)`), else `N turn(s) folded this session`.
Extracted as `_state_reason_row` (pure config + reasonlog, no probe) and unit-tested through the real emit path via
the OUT_RING capture sink; a `/state`-only prose row (config rows stay in `cmd_state`, not the surface.cyr
view-model), so the pinned TUI strip is unchanged. Live-verified both states. Suite green (1451 + 107 + 3). Pin
**6.4.62**. **NEXT (0.35.x)**: maybe persist reasoning into the conversation store so a fold survives resume.

**0.35.3** — **Persistent per-turn reasoning fold** (2026-07-13). The 0.35.2 thinking fold read the live
`_reason_acc`, which `_hoosh_acc_reset` wipes each round — so it vanished when the reply landed. Now each answered
turn's reasoning is persisted in a new **`reasonlog`** ring (`src/reasonlog.cyr`) keyed by the turn tag — the same
per-turn-ring pattern as `roundlog`/`memlog`. `reasonlog_record(turn, text, len)` captures the final round's
chain-of-thought at all three reply-finalize sites (normal / Esc-interrupted / non-agentic), beside
`roundlog_attach_calls_to_last`; **`greason_build_turn`** renders a landed turn's fold above ITS tool cards, keyed by
`session_history_turn(i)`, mirroring `gtool_build_turn`/`gmem_build_turn`. Live + landed folds share one renderer
(`_gfeed_reason_at`) so the handoff is seamless + mutually exclusive; Ctrl+R still collapses all. Ring bounded
(`REASONLOG_CAP = 8`, ages out) + lazily alloc'd only when a model streams reasoning (never on Opus 4.8: `len 0` → no
record); `RSN_TEXT_CAP = 65536` matches the accumulator (no landing truncation). Session-scoped like `memlog` (a
resumed message reloads turn 0 → no fold). Unit-tested (ring: record/find/newest-wins/aging/reset; GUI:
`test_gui_reason_perturn` per-turn filter + measure/draw parity + persistence-after-later-turns + collapse). Suite
green (1444 + 107 + 3). **Adversarially reviewed** (memory-safety / capture / render-parity) — all clean. Pin
**6.4.62**. **NEXT (0.35.x)**: `.4` surface reasoning in `/state`; maybe persist reasoning into the conversation
store so it survives resume.

**0.35.2** — **Reasoning-effort control + a live thinking fold** (2026-07-13). A new **`[hoosh].reasoning = off |
low | medium | high`** control: both request builders emit a top-level `"reasoning_effort":"<level>"` (after
`max_tokens`, before `stream`) when set — off is byte-identical to before, so every request-shaping assertion holds.
hoosh 2.5.0 maps it to the provider's native effort (Anthropic adaptive thinking + `output_config.effort`); this is
the piece that **works today on Opus 4.8** (it raises/lowers effort but keeps reasoning internal). Parse:
`_reasoning_level_from` (only low/medium/high → 1/2/3); accessors `config_hoosh_reasoning` (0-3) /
`config_hoosh_reasoning_effort`. **The fold**: when a model exposes reasoning, hoosh streams `reasoning_content`
deltas; both SSE paths now parse them (before the content early-return) into `_reason_acc` (mirrors `_hoosh_acc`;
`hoosh_last_reason`/`_len`), and `_gfeed_flow`'s mid-turn block renders a distinct muted **thinking** block above the
tool cards + partial answer, growing live on the 0.35.0 pump. **Collapsible via Ctrl+R** (`greason_toggle`,
persists); reset per turn/round (`_reason_acc_reset` folded into `_hoosh_acc_reset`). **Inert on Opus 4.8**
(`_reason_acc` stays empty → no fold); lights up on a reasoning-streaming model. Unit-tested (level map, effort
string, request emission on/off, accumulator); suite green (1431). Pin **6.4.62**. **NEXT (0.35.x)**: `.3` persist
per-message reasoning so a landed turn keeps its fold (today it is live-only).

**0.35.1** — **Live tool-call cards during the round** (2026-07-13). The GUI's bordered tool-call cards (name ·
ok/err/deny · ms/bytes · args) were drawn only post-turn; now `_gfeed_flow`'s `gturn_active` block renders
`gtool_build` (the current turn's roundlog cards) above the streaming partial, so — since the roundlog records each
call as it completes and the 0.35.0 pump repaints between calls — **a card grows a row as each tool returns**.
`gtool_build == gtool_build_turn(session_turns())`, the same cards the per-message loop draws once the reply lands,
so the mid-turn → post-turn handoff is seamless (mutually exclusive, no double-render). Zero producer change;
measure/draw parity holds. Headless-tested (`test_gui_toolcards_live`); live animation compositor-gated. Pin
**6.4.62**. **NEXT (0.35.x)**: `.2` a thinking/reasoning fold (`thinking_delta`).

**0.35.0** — **GUI mid-turn pump: the desktop GUI streams the reply LIVE** (2026-07-13; opens the 0.35.x arc). A GUI
turn runs synchronously (`cmd_task` under `OUT_NULL`), blocking the present loop — so the window froze on a static
"working" frame for the whole turn. Now the model's output appears word-by-word as it streams. The 0.34.3 stop-poll
hook (`_gstop_poll`, `src/gui/gpresent.cyr`), called on the interrupt seam at each SSE frame / round / tool-call
boundary (both streaming paths), became the **pump**: (a) drains the Wayland fd for the stop key (Esc still aborts),
then (b) **throttled** (~30fps via the TUI's tested `_stream_should_paint`) + **scanout-race-gated** (`gwl_win_ready`)
repaints the window. `gfeed` renders the growing partial straight from `_hoosh_acc` (`hoosh_last_reply()`, populated
on both SSE paths even under `OUT_NULL`) as a provisional agent bubble (same layout as a landed reply → seamless
handoff; falls back to the "working" mark before content this round / between tool rounds). **Zero producer change**
(rides the existing per-frame interrupt-seam checkpoint; `agent.cyr`/`hoosh.cyr` untouched). Headless-tested (live
partial render + working-mark fallback + measure/draw parity). Live animation compositor-gated (user-verified).
Residual: each repaint rebuilds the frame command list on the no-rewind bump heap (throttle-bounded per turn; a
reused command-buffer pool is the future optimization). Pin **6.4.62**. **NEXT (0.35.x)**: `.1` live tool-call cards
during the round; `.2` a thinking/reasoning fold (`thinking_delta`).

**0.34.4** — **Per-message remember + feedback** (2026-07-13; **closes the 0.34.x arc**). **`/bookmark`** saves the
last assistant reply into mneme as a note (via the `/remember` `memory_append` path — `mneme_create_note` when bound,
else local; `thoth_remember`-gated; new `session_last_assistant_content`). **`/thumbs up`/`down`** rate the last
reply's recalled mneme notes: `up` records them useful via **`mneme_search_feedback`** (through daimon), `down` is
honest that mneme has no negative tool. `citations_capture` (`src/memory.cyr`) now also parses the recall's
**`search_id`** + first **note id** from mneme's search result into live state, consumed by a new
`memory_feedback(search_id, note_id)`; it rates the MOST RECENT recall and clears on any no-recall turn (so `/thumbs
up` honestly says "no recalled notes to rate" otherwise). Unit-tested (parse + no-stale guard + classify + last-reply
helper) + **LIVE-verified** end to end (`/remember` → recall → `/bookmark` grew the vault → `/thumbs up` → mneme
"Feedback recorded"; degrades honest) + **adversarially reviewed** — which caught + fixed a real heap overflow: the
t-ron gate-params marshaller `_params_one` escaped unbounded into a 32 KiB buffer (safe for the input-line-bounded
callers, but `/bookmark` feeds a whole 64 KiB-capable reply), now cap-bounded + regression-tested. Pin **6.4.62**.
**The 0.34.x chat-UX arc is COMPLETE** — message actions
(`.0`), stop/interrupt TUI+seam (`.1`) + GUI (`.3`), the empty-schema agentic fix (`.2`), remember/feedback (`.4`).
**NEXT arc: 0.35.x** — GUI + agentic streaming (mid-turn pump, live tool cards, thinking fold).

**0.34.3** — **GUI stop affordance: Esc aborts a turn in the desktop GUI** (2026-07-13). A GUI turn runs
synchronously (`cmd_task` under `OUT_NULL`), blocking the present loop, so mid-turn keys queue unread. A new
**`_gstop_poll`** hook (`src/gui/gpresent.cyr`) — registered as the **0.34.1 interrupt seam's** poll
(`intr_check_hook_set`) and called by `agent_turn`'s `intr_check()` at each stream frame / round / tool-call
boundary — non-blockingly `poll(2)`s the Wayland fd and raises the interrupt flag on **Esc**, so the turn aborts.
Minimal stop-poll subset of 0.35.0's full mid-turn pump (input only, no repaint). The two SSE per-frame interrupt
polls now route through `intr_check()` so the hook fires during streaming — the **TUI is byte-identical** (no hook
there → `intr_check` == `intr_poll`). An Esc-interrupted turn with no partial shows a neutral **"- stopped -"**
notice (new `gturn_stop`/`gturn_stopped`), distinct from the red failure notice; the greeting guard excludes it.
Unit-tested (`test_gui` stopped-notice + parity + greeting guard; seam via `test_interrupt`). Live Esc-in-window is
compositor-gated (user-verified). **Needs hoosh ≥ 2.4.13** (an interrupted stream crashed the older gateway —
SIGPIPE; fixed there). **Completes the 0.34.x stop/interrupt work** (`.1` TUI + seam, `.3` GUI). Pin **6.4.62**.
**NEXT (0.34.x)**: `.4` per-message remember + feedback.

**0.34.2** — **Fix: an empty tool `inputSchema` silently emptied every agentic turn** (2026-07-13). A tool that
daimon advertises with an empty `inputSchema` — which the **`mneme_*`** tools all do (`{}`) — made `agent_format_tools`
(`src/agent.cyr`) emit `parameters: {}`, an **Anthropic-invalid** schema (`input_schema` must be `{"type":"object",…}`).
Forwarded by hoosh, Anthropic rejected the WHOLE request, surfacing as **"response had neither tool calls nor content"**
under streaming and **HTTP 502** under `stream=false` — so one mis-advertised tool poisoned all 19 registry tools and
the agentic loop was unusable against the standard local stack (the "large tools payload" symptom from the 0.34.x
live tests was really this — NOT payload size). thoth now falls back to the permissive `{"type":"object"}` whenever a
tool's `inputSchema` is absent, empty, or lacks a top-level `"type"` — it never emits an invalid schema regardless of
what daimon advertises. **Live-verified** end-to-end against the full 22-tool registry (stream + block both return a
clean reply; were empty / 502). Regression-tested (`test_agent`). Root fix upstream: **mneme 1.1.1** now sends each
tool's real `inputSchema` in its daimon registration (it had omitted it → `{}`); thoth's tolerance stays as
defense-in-depth. Pin **6.4.62**.

**0.34.1** — **Stop/interrupt through the whole agentic loop** (2026-07-13). The Esc-abort substrate
(`src/intr.cyr`) is now wired through the entire agentic tool-calling loop, so **Esc** in the rich TUI cancels a
turn during **tool execution** and **between rounds** (the non-streaming block path too), not only mid-stream as
before (0.17.4). `agent_turn` arms the Esc-poll around each round's tool phase; `_agent_run_calls_serial` polls
`intr_check()` between tool calls (a multi-tool round stops before the rest); a final drain + `intr_pending()` check
after the tools stops the loop before the next model request. The streaming abort (kind 4) and the new tool-phase
abort share one honest landing — `_agent_finish_interrupted` (keep a streamed partial, else pop the unanswered user
turn) — so a cancelled turn always leaves history a clean sequence. The t-ron confirm's cooked read is bracketed by
`intr_suspend`/`intr_resume` in the TUI confirm hooks so it works while the poll is armed. NEW **front-end-agnostic
interrupt seam** (`intr_check` / `intr_check_hook_set` / `intr_signal` / `intr_armed` / suspend+resume) so the SAME
loop checkpoints serve the TUI (stdin drain) and, next, the **GUI stop key** (0.34.2, which plugs into `intr_signal`
via `intr_check_hook_set`). **TUI-only, OUT_RING-gated** — the floor stays byte-identical. Unit-tested (the seam +
the interrupt landing keep-partial/pop). The mid-turn Esc delivery reuses the exact `intr_arm`/`intr_poll`/`intr_disarm`
of the shipped 0.17.4 streaming interrupt; end-to-end Esc needs a human on a real terminal (a headless pty can't
inject a mid-turn keystroke — the same limit the shipped streaming interrupt has). **Adversarially reviewed — 0
defects** (arm/disarm balance, confirm suspend/resume incl. the parallel executor, flag lifecycle, drain ordering,
history integrity, floor); accepted edge: a *type-ahead* confirm answer during the armed tool phase is drained and
must be retyped (safer — no blind pre-approval). Pin **6.4.62**. **NEXT (0.34.x)**:
`.2` GUI stop affordance (a minimal between-rounds GUI input pump → the interrupt seam); `.3` per-message remember +
feedback.

**0.34.0** — **Message actions: `/retry` + `/edit`** (2026-07-13; opens the 0.34.x chat-UX arc). Two of the
most-felt chat gaps: **`/retry`** (alias **`/regenerate`**) re-runs your last message for a fresh reply, and
**`/edit <new text>`** replaces your last message and re-runs. Both **rewind the last turn** (drop the prior reply +
user echo) via new pure session helpers (`src/session.cyr`) — `session_last_user_index` + `session_rewind_to_last_user`
(returns the dropped user message's **stable, never-freed** content) — then run a turn: `/retry` re-runs the **exact
stored prompt VERBATIM** (already `@mention`-expanded; re-expanding would double-inject the file blocks, see
`mention.cyr`), while `/edit` runs the new text through the normal `cmd_task` path so fresh `@mentions` expand.
`cmd_task`'s turn core was factored into a shared **`_task_dispatch(prompt)`** (byte-identical to the old inline
flow). **History-safe AND non-destructive on failure**: each refuses **without rewinding** on an empty conversation
or an absent hoosh seam; and the rewind is **snapshotted** (removed messages + the conversation title) so
`session_rewind_settle` **commits** only when a fresh reply actually landed (via a length-independent
`session_history_last_is_reply_for`, correct at the `SESS_HIST_MAX` cap) and otherwise **restores** the prior
exchange byte-for-byte — a `/retry` that hits a transport/HTTP error, an empty completion, or a stateless
non-recording turn keeps the previous reply *and* the user's prompt. TUI/line-REPL commands (the GUI composer
bypasses `dispatch` — a follow-up). Unit-tested (`test_rewind`: rewind/restore/commit + title-restore-on-rollback +
classify asserts, **1389** core assertions) + **adversarially reviewed** (a multi-lens find→verify pass caught two
real history-loss hazards — stateless-mode + transport-failure loss — fixed by the snapshot/restore design; re-review
confirmed the mechanism sound) + **LIVE-verified** end-to-end against a real hoosh (turn → `/retry` reproduces →
`/edit` replaces, conversation stays 2 messages — no doubling; and a `/retry` against a **killed hoosh** RESTORES
the resumed exchange instead of losing it). Pin **6.4.62**. **NEXT (0.34.x)**: `.1` finish stop/interrupt through
the agentic loop + a GUI stop affordance; `.2` per-message remember + feedback.

**0.33.7** — **Cross-conversation `/search`** (2026-07-13). `/search <text>` (`src/commands.cyr`) case-insensitively
scans every message of every conversation, listing matches grouped by conversation (`*` active marker + number +
title, then each match's role + a highlighted context snippet) with a count footer + `/switch <n>` hint. Distinct
from `/find` (the TUI in-buffer feed search); spans the whole store, any mode. Caps at 60 matches; snippets flatten
control bytes + cap context. Unit-tested (the finder + classify) + live-verified. **Closes the 0.33.x chat-management
arc** (store → commands → persistence → richer message schema → GUI sidebar → search).

**0.33.6** — **GUI conversation sidebar** (2026-07-13). A left pane in the desktop GUI (`src/gui/gconv.cyr`) over
the `conv_*` store — each conversation (title + "N msg"), the active one accent-marked. Keyboard-driven: **Ctrl+K**
toggles it (hidden by default), **Tab** cycles composer → file-tree → conversations, **↑/↓** select, **Enter**
switches (+ snaps the feed to that conversation). `gframe_build` now lays out an accumulating left band (conv pane →
tree → feed); byte-identical when the sidebar is hidden. Mirrors the file-tree pane (palette/scroll/theme).
Headless-tested (width/scroll/render/nav/full-frame layout) + confirmed by a rendered golden frame. Interactive
compositor confirm is the user's (the render pipeline is the same one that feeds wl_shm).

**0.33.5** — **Per-message tool calls** (2026-07-13). Each reply now keeps the tool calls it produced (name, arg
summary, gate kind, ok/error), snapshotted from the roundlog and persisted in the `THOTH-SESSION-2` format as
trailing `TOOL\t<len>\n<kind>\t<ok>\t<name>\t<args>\n` frames (same unified frame, dispatched by token, re-attached
to the reply on load). Live capture funnels through `roundlog_attach_calls_to_last` (`src/roundlog.cyr`, idempotent);
the store carries no roundlog dependency. `/save` lists each reply's `_tools:_`. New `session_history_tool_count/
_name/_args/_kind/_ok`. Unit-tested (round-trip beside model + citations) + live-verified both ways. **Completes the
richer persisted message schema** — a resumed conversation carries role + text + model + cited sources + tool cards.

**0.33.4** — **Per-message citations** (2026-07-13). Each reply now keeps the recalled-source TITLES it cited,
persisted in the `THOTH-SESSION-2` format as trailing `CITE\t<len>\n<title>\n` frames (the same unified frame as
`CONV`/records, dispatched by token, re-attached to the reply on load). Live capture funnels through
`citations_attach_to_last` (`src/memory.cyr`, idempotent); the store carries no memory.cyr dependency. `/save` lists
each reply's recalled sources. New `session_history_citation_count/_title`. Titles flattened (tab/newline → space);
an orphan CITE is a safe no-op. Unit-tested (round-trip beside the model field + the orphan guard) + live-verified
both ways. Second cut of the richer persisted message schema (after 0.33.3 model; tool_calls next).

**0.33.3** — **Per-message model attribution** (2026-07-13). Each assistant reply now records the model that
produced it (`src/session.cyr`) — a stable per-message copy (never an alias of the shared session model buffer a
mid-session switch overwrites), persisted in the `THOTH-SESSION-2` format via an optional record field
(`<role>\t<len>\t<model>\n<content>\n`, backward-readable). A resumed conversation keeps its per-reply attribution;
`/save` annotates each reply (`## assistant (claude-opus-4-8)`). New `session_history_model(i)`. Unit-tested +
live-verified both ways. On-brand for thoth's mid-session model switching. First cut of the richer persisted message
schema (citations/tool_calls to follow).

**0.33.2** — **Multi-conversation persistence** (2026-07-12). `[session].file` now persists the whole store, not
just the active conversation: a new **`THOTH-SESSION-2`** format frames each conversation (`CONV\t<len>\n<title>\n`
header + that conversation's records) behind a magic line carrying the active index. Resume rebuilds titles,
per-conversation messages, and the active conversation; old `THOTH-SESSION-1` files still load (into the default
conversation — the reader dispatches on the magic). The parser is bounds-checked against a corrupt file (load what
parsed, never an OOB read). New `conv_load_begin`/`conv_load_add`/`session_total_messages`. Unit-tested (real
multi-conversation file round-trip + v1 back-compat) + live-verified both ways. Toolchain pin `6.4.58`→`6.4.62`.

**0.33.1** — **Conversation commands** (2026-07-12). `/conversations` (`/convos`) lists conversations (active `*` +
title + msg count); `/new [title]`, `/switch <n>`, `/rename <title>`, `/delete <n>` (never the last, active-index
fixup). An untitled conversation auto-titles from its first user message. Over the 0.33.0 `conv_*` store (in-memory;
multi-conversation persistence is 0.33.2). Unit-tested + live-verified (no model needed).

**0.33.0** — **Multi-conversation store** (2026-07-12; opens the 0.33.x chat-management arc). The single message
thread is now the ACTIVE conversation of a keyed store (`_conv_store` of {id, title, created/updated, msgs}) in
`src/session.cyr`; every history op routes through `_sess_hist_vec()` → the active conversation, so all consumers +
`[session].file` persistence are unchanged (one conversation active + persisted today). New `conv_*` API + a clamped
`_conv_at` (crash-safe floor). Unit-tested (isolation / switch / reset). Switching commands, GUI sidebar, cross-conv
search, and multi-conversation persistence come next in 0.33.x.

**0.32.6** — **Notebook mode** (2026-07-12). **`/notes <query>`** searches the mneme vault directly (a read via
daimon's `mneme_search`, `memory_notebook_search`) — memory as a browsable destination, the counterpart to per-turn
recall. Needs the seam bound, degrades honestly otherwise. Live-verified end-to-end (no model turn needed). This
**closes the 0.32.x memory arc**: write (`/remember`) → recall-in-loop (injection + citations + grounding + GUI
strip) → browse (`/notes`).

**0.32.5** — **GUI memory surfacing** (2026-07-12). The recalled-sources + grounding lines are `ui_emit` (lost under
the GUI turn's `OUT_NULL`), so a new **`memlog`** ring (`src/memlog.cyr`) persists each turn's recalled source titles
+ grounding verdict (written from `grounding_emit`), and a new **`gmem`** feed element (`src/gui/gmem.cyr`) draws a
two-row strip (recalled sources + colored verdict) above each turn's reply — matched by turn tag, like the tool
cards. Ring unit-tested; `gmem` fixed-height, reuses the card helpers.

**0.32.4** — **Grounding indicator** (2026-07-12). After a turn that recalled memory, thoth scans its own reply for
`[N]` citations vs the recalled source count and shows a colored verdict line (line/TUI): **green** grounded (valid
cites), **amber** unverified (recalled, none cited), **red** ungrounded (a cite beyond the recalled sources). A tight
`[N]` band avoids code-index false positives. Honest + checkable (thoth parses its reply, not mneme's domain).
Verdict logic unit-tested; rendered lines verified (green/amber/red). `grounding_verdict`/`grounding_emit`.

**0.32.3** — **Citations** (2026-07-12). The recalled context is model-only, so citations surface the sources:
the injection now tells the model to cite a used source inline as `[N]` (mneme numbers the hits), thoth captures
each recalled note's title + path (a defensive parse of mneme's result, `citations_capture`), and shows a
"recalled N note(s) from mneme: [1] Title …" line when recall fires (line/TUI; GUI rides the feed work).
Presentation only (ADR-0012); live-verified. (Bring-up caught a parser crash — thoth's `strstr` returns an index,
not a pointer — now fixed + genuinely tested.)

**0.32.2** — **Semantic recall via mneme** (2026-07-12). When `[memory].enabled` and the memory seam is bound
(daimon hosts `mneme_*`), a turn's memory context is a live `mneme_search` keyed on the turn (`memory_context(query)`,
`src/memory.cyr`) — the hits injected verbatim, degrading to the local `.thoth/memory` reader on any failure. The
query is threaded through the live turn sites; `/dry` passes `0` to stay network-free. thoth stays a consumer
(sends the query, injects mneme's text opaquely). Live-verified end-to-end against a real mneme.

**0.32.1** — **GUI pane toggles** (2026-07-12). Two control chords hide/show the desktop GUI's chrome so the
conversation feed can take the whole window: **Ctrl+B** the file-tree pane, **Ctrl+S** the status strip (the feed
reclaims the space; focus never sticks on a hidden pane; unbound `Ctrl+<letter>` is swallowed). Provisional
keybindings (cross-platform chord may change), mapped in one place (`gkey`). Toolchain pin `6.4.57` → `6.4.58`.

**0.32.0** — **The mneme memory seam** (2026-07-12). thoth consumes **mneme** (the AGNOS memory/RAG domain, now
Cyrius-ported) through daimon's MCP registry: a cached `mneme_*` probe binds `SEAM_MEMORY` → REMOTE, and
`/remember` + the `memory_write` tool route to `mneme_create_note` when bound, degrading to the local
`.thoth/memory` flat file otherwise (a producer swap behind `memory_append`; `/state`'s memory row reflects it).
Live-verified both ways against a real daimon. Also: **crash-safe atomic edit/create writes** — `_edit_do` →
`file_write_atomic`, `_write_do` → `file_create_exclusive` (cyrius **6.4.57**, closing the ADR-0017 non-atomic
residual), and the toolchain pin `6.4.51` → `6.4.57` with `lib/` refreshed via `cyrius lib sync`. Recall-via-mneme
(query-keyed semantic injection) is the next cut. See [`CHANGELOG.md`](../../CHANGELOG.md).

**0.31.5** — **Non-2xx daimon HTTP response recorded as a failed tool call** (the 0.30.18 loose end), 2026-07-12.
The agentic loop's tool executors read the result but ignored the HTTP status — a non-2xx response (server error /
unknown tool / bad request) whose body carried MCP text without an `isError` field was recorded as a SUCCESSFUL
tool result (green `ok`). Now both executors treat non-2xx as failure (`rl_ok=0`) and surface daimon's error text
or a synthetic `(tool call failed: daimon returned HTTP <status>)`. `daimon_invoke` (serial) checks
`sandhi_http_status` → `_daimon_last_is_error=1`; `daimon_fetch_into` (parallel) gained a `status`-out param
(worker `ctx+56`, `PAR_CTX_SZ` 56→64) that phase-3 reads and handles identically. Matches `daimon_call`/`/call`.
**Verified**: 1502 assertions (`test_daimon` +2) + **LIVE** (unknown tool → HTTP 400 → `is_error=1` + the HTTP-400
message → `rl_ok=0`) + adversarial review. Pin **6.4.51** (wrapper 6.4.56). **This clears the last edit/daimon
follow-up** — the write/diffs arc + its hardening are complete; the remaining open item is upstream (the filed
cyrius `file_rename`/`file_write_atomic` + AGNOS `O_EXCL` for crash-safe atomic writes).

**0.31.4** — **Cleaner edit/create arg on the diff card**, 2026-07-12. Now that the colored diff renders below an
`edit`/`create_file` call, the raw JSON args line above it was noise. `_gtool_card` (`src/gui/gtool.cyr`) now shows
just the **clean path** (in `ROLE_BLUE`) for any call with an `editlog` entry — `edit ok 12ms/40B src/x.cyr`, not
the JSON — reusing the `editlog_find`/`editlog_path` the diff already looks up (no JSON parse at paint). Other tools
keep raw args (faint). Draw-only, so the card height + feed measure/draw parity are unchanged. **Verified**: 1500
assertions (`test_gui_toolcards_diff` +2) + main builds + PPM eyeballed. Pin **6.4.51** (wrapper 6.4.55). Also
**filed a cyrius issue** (`docs/development/issues/2026-07-12-thoth-portable-atomic-file-write.md` in ~/Repos/cyrius):
a portable `file_rename`/`file_write_atomic` + AGNOS `O_EXCL` so edit/create/`/write` can be crash-safe (atomic
temp+rename) — the fix for the non-atomic-write residual, requested for the next cyrius release. **NEXT (remaining
thoth follow-up)**: the `daimon_invoke` HTTP-status hardening (from 0.30.18).

**0.31.3** — **`create_file`: the model can make NEW files** (ADR-0017), 2026-07-12. The create half of the
write capability. `create_file(path, content)` (`src/edit.cyr`) writes a brand-new file — **CREATE-ONLY**, it
REFUSES if the file exists (no blind-clobber; modifying stays `edit`'s surgical job). Same envelope as edit:
opt-in `[edit].enabled`, jailed cwd-only, `thoth_edit`-gated, local+serial. Shares the `_edit_*` buffers + editlog
recording; feeds editlog with `old=""` so a new file shows as all-GREEN additions on its card. **Verified**: 1496
assertions (`test_edit` +16: `_write_do` create / refuse-if-exists / empty-file / parse+jail refusals) + **LIVE**
(gated create → `+2 -0` all-add editlog → file on disk → second create refused). Adversarially reviewed. Pin
**6.4.51** (wrapper 6.4.55). **NEXT (remaining follow-ups)**: cleaner edit-arg display on the card (the JSON args
line is noisy under the diff); the `daimon_invoke` HTTP-status hardening (from 0.30.18); atomic edit/create writes
(needs a portable stdlib `xrename`).

**0.31.2** — **Colored diff cards in the GUI feed** (the arc payoff), 2026-07-12. When the model `edit`s a file,
its tool-call card now shows the change: the stored `editlog` diff renders below the `edit` call line — deleted
lines RED (`- …`), added lines GREEN (`+ …`) — sourced from thoth's own edits. `_gtool_card` (`src/gui/gtool.cyr`)
looks up `editlog_find(turn,round,call)` per call and draws the stored del/add lines (clipped to width; faint
`… more` / `(diff too large to show)` when truncated). READ-ONLY over editlog — no LCS recompute at paint. Diff
rows fold into the card height via one `_gtool_call_diff_rows` helper used by BOTH measure + draw passes, so the
feed's measure/draw parity (bottom-anchor) is preserved. `editlog.cyr` added to the LEAN `thoth_gui.tcyr`.
**Verified**: 1482 assertions (`test_gui_toolcards_diff` +5: parity, del=red/add=green, height growth) + main
builds + PPM eyeballed (`edit ok … {"path":"src/x.cyr"}` with `- OLD` red / `+ NEW` green) + adversarial review.
Pin **6.4.51** (wrapper 6.4.55). **COMPLETES the colored-diffs arc** (0.30.16 cards → .17 args → .18 isError →
.19 per-turn → 0.31.0 edit tool → .1 editlog → .2 diff card). **NEXT (edit-tool follow-ups)**: create-new-file
support; a cleaner edit-arg display on the call line (the JSON is noisy); the `daimon_invoke` HTTP-status
hardening (from 0.30.18).

**0.31.1** — **`editlog`: record each edit's diff for the colored diff card**, 2026-07-12. The producer half of
the colored-diffs arc (patch within the 0.31 arc). `src/editlog.cyr` = a session ring of the model `edit` tool's
recent changes keyed by `(turn,round,call)` (aligns with `roundlog`). On each applied edit it computes the line
diff **once** (sit's escape-free `compute_file_diff`) and stores the **changed lines** (del/add) — so the GUI
card (0.31.2) renders by walking stored lines, **never recomputing the LCS per repaint** (bump-heap-per-frame is
the trap that forced this design). Bounded: 16 edits, ≤48 lines each (≤200 B, control→space, trailing-\n
stripped), all adds/dels counted past the cap; over-LCS-cap edit stores path+counts only. Recording site:
`agent.cyr` edit dispatch calls `editlog_record(session_turns(), roundlog_cur_round(), ci, edit_last_*)` right
after a successful edit (before the next edit reuses `_edit_old`/`_edit_new`); `editlog_reset` wired to `/reset`.
**Verified**: 1477 assertions (`test_editlog` +27) + **LIVE** integration (real gated edit → `editlog_find` returns
`+1 -1` with the exact `-`/`+` lines, indentation preserved) + adversarial review. Pin **6.4.51** (wrapper 6.4.55).
**NEXT**: 0.31.2 = the GUI colored diff card — `_gtool_card` looks up `editlog_find(turn,round,call)` for each
`edit` call and draws the stored del/add lines in ROLE_RED/ROLE_GREEN (draw-IR; grows the card height). Then
create-new-file support; the `daimon_invoke` HTTP-status hardening.

**0.31.0** — **Model `edit` tool: thoth can now WRITE code** (ADR-0017), 2026-07-12. New capability arc (minor
bump). The symmetric completion of the ADR-0015 read tools: `edit(path, old_string, new_string)` (`src/edit.cyr`)
does a **surgical** replacement of the UNIQUE occurrence of old_string and applies it to disk — 0 matches →
not-found, >1 → not-unique, both **refused, never applied** (no blind-clobber). Degrades **closed** everywhere:
**opt-in** `[edit].enabled` (default off, like shell); **jailed** cwd-only via `_project_jail_ok` (NOT
`_project_read_ok`, so writes can't follow read `/allow` grants); **gated** under a **distinct `thoth_edit`** verb
(separate from `/write`'s `thoth_write`); local + forced-serial. Foundation for the colored-diffs arc (0.31.1
record → 0.31.2 GUI diff card, both via `compute_file_diff`'s escape-free ann-ops). **Verified**: 1450 assertions
(`test_edit` +28: pure core + real-file `_edit_do` + parse/jail refusals) + **LIVE** end-to-end against a real
t-ron allow-policy (parse → jail → VK_ALLOW → surgical apply → `file_write_all` → file changed, `+1 -1`) +
adversarial review (safety/core/wiring). Pin **6.4.51** (wrapper drifted to 6.4.55; benign). **NEXT (colored-diffs
arc)**: 0.31.1 = `editlog` producer (snapshot old/new keyed by turn/round; recompute the diff on demand) → 0.31.2
= GUI colored diff card (draw-IR walk of the `compute_file_diff` ann-vec, grown into `_gtool_card`). Also open:
create-new-file support; the `daimon_invoke` HTTP-status hardening (from 0.30.18).

**0.30.19** — **Tool-call cards render PER-TURN**, 2026-07-12. 0.30.16–.18 carded only the current turn, so a
turn's cards vanished when you sent the next message; now each turn's cards sit above ITS OWN reply throughout
the scrollback. Each `session_history` message is turn-tagged (`session_turns()` at append; struct 16→24 B,
`session_history_turn(i)`); `gfeed._gfeed_flow` renders `gtool_build_turn(..., session_history_turn(i))` above
EVERY assistant (was last-only). Turn tag is **in-memory only** — `[session].file` format byte-unchanged
(`_sess_write_file` uses the accessors), resumed messages get turn 0 (no cards — honest), and turns aged out of
the 16-round roundlog ring show none. Measure/draw parity preserved. No producer/spine change. Also FIXED (pre-existing, surfaced by the review and
amplified by the per-turn loop): `gpresent`'s "didn't complete" detector used a net-growth check (`len <= _n0`)
that false-fired at the `SESS_HIST_MAX`=40 cap (eviction pins the length) — every successful turn read as failed,
showing a bogus notice + a duplicate current-turn card. Replaced with `gturn_reply_landed()` (last row is an
assistant tagged the current turn — length-independent). **Verified**: 1422 assertions
(`test_gui_toolcards_perturn` +6, `test_gturn_reply_landed` +4) + main builds + PPM eyeballed (turn 1's `shell`
card stays above `a1` while turn 2 `a2` is card-less below) + adversarial review (struct/persistence, parity,
attribution → SHIP; the cap bug it found is fixed here). Pin **6.4.51** (wrapper drifted to 6.4.55; benign). **NEXT (GUI arc)**: colored **diffs** — still no first-class
source (thoth exposes no file-edit tool; `roundlog` keeps no result text), so it needs its own producer/source
decision, likely the next real discussion. Loose hardening item from 0.30.18: `daimon_invoke` doesn't check HTTP
status (unlike `daimon_call`).

**0.30.18** — **Tool-call status honors the MCP `isError` flag**, 2026-07-12. `daimon_invoke` discarded a tool
result's `isError`, so `roundlog.ok` (→ the GUI card colour + `/audit`/telemetry) meant only "did the body
parse," not "did the tool succeed" — a tool returning `isError:true` WITH valid text was carded green `ok`. Fix:
`daimon_invoke` captures `daimon_extract_is_error(body)` into a last-call slot (`daimon_invoke_is_error()`, serial
→ race-free); the parallel executor reads `isError` off the raw body it already re-parses in phase 3 (main-thread,
bayan off the workers); a pure `_agent_tool_ok(text_ok, is_error)` records success only when text parsed AND
`isError` isn't set. `isError:false`/absent unchanged (no regression). Error text still reaches the model — only
the recorded FLAG changed. Thoth-side consumption fix, **no spine change**. **Verified**: 1412 assertions
(`test_daimon` +5 truth table incl. the fixed case) + main builds + **LIVE** against a running daimon (`web_search`
no-SearXNG and `libro_retention` bad-args both return `isError:true`+text → `daimon_invoke_is_error()==1` →
recorded ok flips to 0) + adversarial review (wiring/concurrency/semantics → SHIP). Pin **6.4.51** (wrapper
drifted to 6.4.55; benign). **NEXT (GUI arc)**: per-turn card interleave (cards are current-turn-only; needs a
per-message turn tag) and colored **diffs** (no first-class source — thoth exposes no file-edit tool and
`roundlog` keeps no result text; needs its own producer/source decision). Separate hardening item surfaced by the
review: `daimon_invoke` doesn't check HTTP status (unlike `daimon_call`), so a non-2xx body lacking `isError` can
still record `ok`.

**0.30.17** — **Tool-call cards + `/audit` show each call's ARGUMENTS**, 2026-07-12. A bare `shell` on the card
became `shell {"command":"git status"}`. The `roundlog` producer now snapshots a per-call arg summary
(`RL_ARG_CAP`=128 B, **sanitized**: control bytes → space so a multi-line JSON arg can't break a one-line
card/row) at BOTH loop record sites (`agent.cyr` serial `ar` + parallel `_par_args`); new `roundlog_call_args`
accessor. The GUI card (`gtool.cyr`) draws args faint after the telemetry, **clipped** (`max_cp`) to the card's
remaining width — draw-only, so card height stays one line/call and the feed measure/draw parity is untouched;
`roundlog_report()` (`/audit`) prints args after the name. Thoth-side, **no spine change** (args were in-process
at the record site, just unpersisted). **Verified**: 1407 assertions (`test_roundlog` +3: args copied /
control-byte→space / null→empty; `test_gui_toolcards` +1: args drawn) + main builds + PPM eyeballed (`shell ok
88ms/256B {"command":"cyrius test"}`). Pin **6.4.51** (wrapper drifted to 6.4.55; benign). **NEXT**: the
`isError` fidelity fix (0.30.18) — `daimon_invoke` discards the MCP `isError` flag so `roundlog.ok` reflects
only "did text parse," not tool success (`daimon_extract_is_error` exists; thoth-side). Then per-turn card
interleave (needs a per-message turn tag) and colored diffs (no first-class source — needs its own decision).

**0.30.16** — **T3 GUI: tool-call cards in the feed**, 2026-07-11. The GUI now SHOWS which tools thoth ran to
produce an answer, as bordered cards in the conversation feed (tool activity was previously invisible on the
desktop — the present loop suppresses the turn's output with `OUT_NULL`). NEW `src/gui/gtool.cyr`: a PURE,
headless-testable view-builder that reads the EXISTING `roundlog` producer (`src/roundlog.cyr`, the session ring
`/audit` renders) and emits draw-IR cards — per round a bordered box + left accent bar, a `tool round N` header,
one line per call = name (accent) + status word (**ok** green / **err**·**deny**·**noname** red) + `ms/bytes`
(faint). `gfeed._gfeed_flow` interleaves the block above the CURRENT turn's assistant reply (and above the
failure notice); `gtool_build` honours the `cmds==0` measure/draw parity the bottom-anchor needs. **Data-side
finding that shaped the scope**: the tool-round PRODUCER already existed (`roundlog`), so this is a RENDERING
cut — **no producer/session/spine change**. The record site holds the tool **args** (16 KB) + **result text**
(128 KB) in-process but `roundlog` persists only name/kind/ok/ms/bytes; and thoth exposes NO file-edit tool
(only `memory_write`/`shell`/`read_file`/`list_dir`), so a colored **diff** has no first-class source today.
**Verified**: 1400 assertions (+9 `test_gui_toolcards`: measure==draw parity, per-round borders, ok=green /
err+deny=red, current-turn filtering, feed interleave) + main builds + a rasterized `/tmp/thoth_gui_cards.ppm`
eyeballed (card renders correctly between the user turn and its reply). Pin **6.4.51** (wrapper drifted to
6.4.54; benign). **NEXT (GUI arc, decisions pending — see below)**: (a) tool **args** on cards — small
`roundlog` extension to snapshot a truncated arg summary (`shell: git status`, not bare `shell`); (b) an
`isError` fidelity fix — `daimon_invoke` discards the MCP `isError` flag so `roundlog.ok` reflects only "did
text parse" (thoth-side, `daimon_extract_is_error` exists); (c) per-turn card interleave (needs a per-message
turn tag); (d) colored **diffs** — no clean source without an edit tool or a diff-shaped result parser.

**0.30.15** — **T3 GUI: composer history recall (Up/Down)**, 2026-07-11. The GUI composer recalls previous
submissions with the arrows, over the SAME `inhist` ring the TUI/REPL use (`src/inhist.cyr`, added to the LEAN
`thoth_gui.tcyr`). Mirrors `_tui_recall_key`: **Up** stashes the live draft on the first step then walks OLDER,
**Down** walks NEWER and restores the draft past the newest. NEW `gcomp_set(ptr,len)` + `ghist_up`/`ghist_down`/
`ghist_record` (+ draft stash) in `src/gui/ginput.cyr`; `gkey` routes composer-focused Up(103)/Down(108) to
recall (tree-focused Up/Down still navigate the tree) and records each submission (`inhist_push` +
`inhist_nav_reset`); `gui_run` calls `inhist_init()`. **Verified**: 1391 assertions (+10 `test_gui_history`:
submit records, Up/Down walk newest↔oldest, Down-past-newest restores the draft, a typed draft is stashed +
restored around recall, a tree-focused Up still moves the tree) + main builds. PURE + unit-tested; the present
loop is main-only. In-session only (wiring to `[history].file` is a small follow-up). Pin **6.4.51** (wrapper
drifted to 6.4.54; benign). **NEXT (GUI arc)**: tool-call cards + colored diffs — the big visual one; needs a
tool-round PRODUCER first (`session_history` keeps only user/assistant; tool rounds are ephemeral) — its own
mini-arc (a recorder + live mid-turn paint).

**0.30.14** — **T3 GUI: conversation-feed scrollback**, 2026-07-11. The feed bottom-anchors to the newest
message (0.30.3); after a long chat older messages clip off the top. Now **PgUp/PgDn** page through them, **End**
jumps to the latest. NEW `gscroll_*` state (`src/gui/ginput.cyr`, before gfeed in the include order so `gkey`
drives it + `gfeed_build` reads it): `_gscroll` = px scrolled UP from the bottom (0 = newest); `gfeed_build` sets
the feed height + clamps the offset to the overflow each frame and shifts the flow up by it. `gkey` maps
PageUp(104)/PageDown(109)/End(107); a submitted turn (and the empty greeting) RESETS the scroll so the reply is
seen. A faint `-- more below (End) --` hint renders when scrolled off the bottom. **Verified**: 1381 assertions
(+8 `test_gui_scroll` in the LEAN `thoth_gui.tcyr` — scroll-up shifts the flow down, clamps at the top, PgUp/End
wiring, submit-resets) + a golden PPM of the scrolled state (older messages + the hint) + main builds. PURE +
unit-tested; the present-loop repaint on a scroll key is main-only (verify live). Pin **6.4.51** (wrapper
drifted to 6.4.53; benign). **NEXT (GUI arc)**: composer history (Up/Down over the inhist ring); then tool-call
cards + colored diffs (needs a tool-round producer — its own mini-arc).

**0.30.13** — **T3 GUI: tree Enter on a file → `@mention` in the composer**, 2026-07-11. Completes the file-tree
keyboard nav (0.30.10): Enter on a file in the focused tree inserts `@<repo-relative-path> ` into the composer +
hands focus back, riding the 0.21.0 `@mention` machinery (`cmd_task` expands `@path` → the file's content). NEW
`gtree_mention(li)` (`src/gui/ginput.cyr`) builds the path as the git-badge lookup does (absolute `ftree_path`
minus the `ftree_cwd()` prefix) + appends `@`+relpath+space via the composer buffer; Enter on a DIR still
toggles. **Verified**: 1373 assertions (+4 in the LEAN `thoth_gui.tcyr`: file Enter → `@src/main.cyr ` + composer
focus; dir Enter still collapses, inserts nothing) + main builds. PURE/unit-tested; the mention expansion is
already covered + live-verified. Pin **6.4.51** (wrapper drifted to 6.4.53; benign). **NEXT (GUI arc)**: feed
scrollback (page older messages on the bottom-anchor); composer history (Up/Down over the inhist ring);
tool-call cards + colored diffs (needs a tool-round producer).

**0.30.12** — **T3 GUI: fix the 0.30.11 owl-eye throb (glitchy surface + invisible pulse)**, 2026-07-11. Live
testing found two bugs. (1) **Surface glitch** — the top of the window flickered with bg-coloured overdraw
because the throb loop presented EVERY tick into the SINGLE `wl_shm` buffer while the compositor was still
scanning out the prior frame (a buffer-reuse race; sparse event-driven repaints rarely hit it). FIX: NEW
`gwl_win_ready()` (`gwindow.cyr`) = `frame_done && !buf_busy`; the present loop (`gpresent.cyr`) marks a redraw
`_gui_pending` and flushes it ONLY when ready (the release/frame-callback events arrive on the wl fd and are
consumed by `gwl_win_poll_events`). (2) **Invisible pulse** — the eye read as a colourless blink because the
pulse blended toward the BACKGROUND (dim phase ~invisible). FIX (`geye_color`): the triangle wave now glows the
base toward WHITE (peak ~50%), staying visibly amber/red at every phase; 12-step wave; ~120ms tick. **Verified**:
1369 assertions (+1 — the peak glow is never the bg) + main builds. The throb colour is PURE/unit-tested; the
frame-throttled present loop is main-only (compositor-gated — RE-VERIFY live: the eye should pulse smoothly
amber, no header glitch). Pin **6.4.51** (wrapper drifted to 6.4.53; benign). **NEXT (GUI arc)**: Enter-on-a-file
→ `@path` into the composer; tool-call cards + colored diffs (needs a tool-round producer); feed scrollback.

**0.30.11** — **T3 GUI: the `{(o>` owl prompt + a throbbing owl-eye status indicator**, 2026-07-11. Two GUI
touches: (1) **restored the signature `{(o>` owl prompt** (`src/gui/gfeed.cyr`) — the composer prompt AND every
user turn in the feed now use `{(o>` (the brand glyph the TUI/REPL use), replacing the plain `>` the GUI had
carried since 0.30.1 (text offsets widened for the 4-glyph prompt). (2) **the owl's eye `o` THROBS as a live
status indicator** ("the head as indicator"): base colour = hoosh health (red when DOWN via `hoosh_health()`,
else amber accent), pulsing a triangle brightness wave so the window feels alive at rest. The eye is its own
draw-command (`_geye_cell`, recorded by `gframe_build`); the present loop polls with a ~300ms throb tick,
advances a phase, and rewrites ONLY that cell's colour before re-rasterising. **Leak-free**: the frame command
list is CACHED (`_gui_cmds`/`_gui_dirty`, rebuilt only on keystroke/resize/turn), so the idle throb costs zero
per-frame allocation; `poll(2)` services events only when the wl fd is readable, else it just throbs.
**Verified**: 1368 assertions (+8 `test_gui_eye` in the LEAN `thoth_gui.tcyr` — distinct+symmetric pulse, the
`o` cell is a mutable TEXT command, base tracks hoosh up/down) + frame PPMs render the split `{(o>` unchanged +
main builds. Throb math + eye-cell recording are PURE/unit-tested; the timed present loop is main-only
(compositor-gated — verify the animation live on Wayland). Pin **6.4.51** (wrapper drifted to 6.4.53; benign).
**NEXT (GUI arc)**: Enter-on-a-file → `@path` into the composer; tool-call cards + colored diffs (needs a
tool-round producer); feed scrollback; composer history.

**0.30.10** — **T3 GUI: file-tree keyboard navigation**, 2026-07-11. The file-tree pane (0.30.5, static)
becomes interactive with TUI-style focus. NEW in `src/gui/ginput.cyr`: `gfocus`/`gfocus_set` (COMPOSER/TREE),
`gtree_key` (evdev ↑103/↓108 move · →106 expand · ←105 collapse · Enter toggles the selected dir, over
`ftree_*`), and `gkey` — the focus-aware dispatch that replaces `gcomp_key` as the present loop's entry: **Tab**
toggles composer↔tree (only to a populated tree), **Esc** quits, a printable key while tree-focused returns to
the composer + types it, else composer keys route to `gcomp_key`. `gpresent.cyr` feeds keys through `gkey`.
Focus is VISIBLE: the tree's selected row shows a bright full-row highlight + accent bar when focused (dim bar
otherwise; `_gtree_selbg`), and the composer's prompt + caret are bright only when composer-focused.
**Verified**: 1360 assertions (+17 `test_gui_nav` in the LEAN `thoth_gui.tcyr` — Tab toggle, arrow move/clamp,
Enter/→/← expand-collapse, printable→composer, Esc/submit, empty-tree guard) + a **golden PPM** of the
tree-focused frame (bright selection on `docs`, dimmed composer — visually confirmed) + main builds. The nav
logic is PURE + unit-tested; the present-loop wiring is main-only (compositor-gated — verify live on Wayland).
First cut to exercise the 0.30.9 lean gui binary for iteration. Pin **6.4.51** (wrapper drifted to 6.4.53;
benign). **NEXT (GUI arc)**: Enter-on-a-file → `@path` into the composer; tool-call cards + colored diffs
(needs a tool-round producer); feed scrollback; composer history.

**0.30.9** — **curated per-domain test binaries** (the payoff of the 0.30.8 decoupling), 2026-07-11. The single
`tests/thoth.tcyr` (one binary of the whole codebase) is replaced by independent, curated `tests/*.tcyr`, each
including ONLY its domain's transitive `src` deps so it runs fast in isolation: **`thoth_gui.tcyr`** LEAN (103 —
draw pipeline + view-builders + surface; `surface→hoosh→gate→t-ron` + `intr` + GUI modules, NO
`tui`/`mdhl`/`feed`/`commands`/`vyakarana`), **`thoth_render.tcyr`** LEAN (107 — diff/highlight/mdhl +
`vyakarana`/`feed`/`fsearch`/`git`), **`thoth_core.tcyr`** FULL (1133 — the commands/tui-coupled integration
tests: core + agent + tui, full-include because the hub couples them to the whole codebase). Helpers sorted:
shared byte-buffer utils → NEW `tests/cases/testutil.cyr` (dep-free); domain helpers → their case file;
`test_memory` (uses `classify_input`) → `core`. **1343 assertions** across the 3 binaries (was 1341 in one; +2 =
`test_surface`'s config-conditional asserts now run in isolation — more coverage, not a regression). `cyrius
test` runs all three. **HONEST scope**: only `gui`/`render` are cleanly LEAN; `agent` is *nearly* lean but for
two residual layering violations the 0.30.8 pass didn't cover (`agent → spin_label_*` [tui], `shell →
_params_one` [commands]), and `tui`/`core` are inherently full (the `commands`/`tui` dispatch hub) — decoupling
those is a future arc. **No `src` change this cut** (tests-only; the shipping binary is unaffected). Pin
**6.4.51** (wrapper drifted to 6.4.53; benign). **NEXT**: the GUI arc at 0.30.10 — file-tree keyboard nav.

**0.30.8** — **decouple the lower layers from the TUI (dependency inversion)**, 2026-07-11. thoth grew out of
one file and had never been layered; three lower modules reached UP into presentation, coupling every GUI/TUI
test to the whole codebase (cyrius refuses reachable-undefined — the wall the 0.30.7 split hit). This refactor
breaks all four couplings via extraction + registered fnptr sinks: (1) **`intr_*` → NEW `src/intr.cyr`**
(turn-interrupt is signal/termios SUBSTRATE, not TUI — moved verbatim, included after `ui`/before
`hoosh`/`agent`/`tui`; callers now poll it downward). (2) **`util → feed`**: `OUT_RING` routes through
`_ring_emit` → a `_ring_sink` fnptr the renderer sets to `&feed_write` at startup. (3) **`gate → tui_confirm`**:
the confirm's live-screen bracket via `confirm_hooks_set(&tui_confirm_begin,&tui_confirm_end)` (unregistered →
skipped). (4) **`hoosh → mdhl/feed_stream`**: reply render/stream via `reply_sink_set(&mdhl_reply,&mdhl_reset,
&mdhl_feed,&mdhl_finish,&feed_stream_tick)` (registered for ALL tiers; **raw-emit fallback** so a reply is never
dropped). Cyrius fnptr idiom: `&fn` + `fncall0/fncall2` (explicit-arity as a statement; `callptr` is
expression-only). **Verified**: 1341 assertions (unchanged) + build green + **LIVE** against a real hoosh
gateway — `stream=false`/`stream=true` replies render (plain + fenced), the rich-TUI feed renders a turn, and
the gate confirm prompt renders live with the tool running on `y` (PTY-driven); **floor byte-identical** (piped
one-shot). **Reviewed** via a 4-lens find→verify **workflow — 0 findings** (registration timing / reply sink /
ring+confirm / intr+floor all clean). **PAYOFF PROVEN**: a curated lean GUI test (`surface→hoosh→gate→t-ron` +
`intr` + the GUI modules; NO `tui`/`mdhl`/`feed`/`commands`/`vyakarana`) now compiles + passes (103 asserts) —
the coupling that forced the one-binary split is gone. The one-binary test structure (0.30.7) is RETAINED for
now (this only makes curated per-domain files *possible*). Pin **6.4.51** (wrapper drifted to 6.4.52; benign).
**NEXT**: optionally convert the test suite to curated per-domain `.tcyr` (now unblocked); GUI file-tree
keyboard nav; tool-call cards + colored diffs (needs a tool-round producer); feed scrollback.

**0.30.7** — **test suite split into topical case files**, 2026-07-11. `tests/thoth.tcyr` (~4,095 lines in one
file) is now a thin DRIVER — the src-module include block + `include "tests/cases/*.cyr"` + a verbatim `main()`
— with the ~72 test fns moved into **`tests/cases/`**: `core.cyr` (1,403), `tui.cyr` (1,184), `agent.cyr`
(572), `render.cyr` (361), `gui.cyr` (347), `helpers.cyr` (the 9 shared helpers, included first). **A PURE
mechanical refactor** — `main()` is byte-for-byte the same 72 calls, every definition stays present via the
includes, so it remains ONE compiled binary and is behavior-identical: **1341 assertions, 0 failed** (unchanged).
**Kept as one binary DELIBERATELY** (not independent per-domain `.tcyr`): cyrius refuses to emit with
reachable-undefined functions, and thoth's modules are coupled — `surface → hoosh → gate → tui_confirm_*` and
`hoosh → intr_*` (tui) / `mdhl_*` / `memory_context` / `log_*`, `util → feed_write` — so a *curated lean*
per-domain split (the first-picked approach) is blocked: every GUI/TUI test transitively needs `tui → commands →`
the whole codebase. A truly lean split would need a product refactor (extract `intr_*`/`tui_confirm_*` out of
`tui.cyr`; decouple hoosh's display calls behind a sink) — its own future arc, out of scope here. So splitting
the SOURCE (readable files, one compile) was chosen over independent binaries (isolated runs, N× compile). **To
add a test**: body → the right `tests/cases/*.cyr`, wire the call into `tests/thoth.tcyr`'s `main()`. Pin
**6.4.51** (wrapper auto-drifted to 6.4.52; benign). **NEXT (GUI, 0.30.x)**: file-tree keyboard nav; tool-call
cards + colored diffs (needs a tool-round producer); feed scrollback; composer history.

**0.30.6** — **toolchain refresh (cyrius 6.4.49 → 6.4.51) + the full file-tree tests the output cap had forced
lean**, 2026-07-11. cyrius **6.4.51** resolves thoth's filed output-cap issue: the emitted-binary `output_buf`
grew from a FIXED **16 MiB to 1 GiB on Linux** (macOS/Windows follow in .52 via a large-alloc path). Background:
the test program `tests/thoth.tcyr` is ONE translation unit that includes the whole driver + every vendored
spine dep + the full suite, so at 0.30.5 it hit the 16 MiB cap (over by ~3,832 bytes) when the file-tree pane +
tests landed — forcing the `gtree` test lean. Now RESTORED to full fidelity: the dir/file/header color scan
(dir→`ROLE_BLUE`, file→`ROLE_MUTED`, header→project name), the empty/bare/root `_gtree_basename` cases, the full
`_gtree_scroll_first` clamp (top/bottom), a **golden PPM** of the standalone pane, and a **real-repo render
smoke** exercising the git-badge path (`_gtree_gitkind`: `ftree_path`→strip-cwd→`git_status_of`) on live files.
**A PURE refresh + test restoration — NO product-code change** (`src/gui/gtree.cyr` is byte-for-byte its 0.30.5
reviewed self). **Toolchain**: `cyrius lib sync` moved 7 stdlib files (`alloc*` variants, `sakshi`, `sandhi`,
`syscalls`); vendored dists unchanged (already current — avatara 2.8.0 / sit 1.3.4 / sankoch 2.5.1 / libro
2.7.10 / bote 3.1.1 / t-ron 2.1.7 / vyakarana 2.2.3 / darshana 0.9.0). **Verified**: 1341 assertions (+9,
`test_gui` gtree restored) — the exact test that overflowed at 16 MiB now compiles with 1 GiB headroom + main
builds + LIVE floor byte-identical on 6.4.51 (`--version` = `thoth 0.30.6`, piped one-shot exits clean, `/seams`
ladder). Pin **6.4.51** (matches the wrapper — drift gone). **The 16 MiB test-binary constraint is CLEARED on
Linux** — a separate lean GUI test binary is no longer needed; GUI tests grow in the shared binary again.
**NEXT (GUI, 0.30.x)**: file-tree keyboard nav (focus / ↑↓ move / →← or Enter expand-collapse into `gpresent`
keys); tool-call cards + colored diffs (needs a tool-round producer); feed scrollback; composer history.

**0.30.5** — **T3 GUI: the file-tree pane**, 2026-07-11. The desktop window gains the mockup's (Thoth.dc.html)
LEFT column. NEW **`src/gui/gtree.cyr`** — a view-builder like `gstatus`/`gfeed` over ftree.cyr's flattened
tree model (the SAME model the TUI pane reads): `gtree_build` emits a project-name header + one row per visible
node — a depth indent, a `v`/`>` expand marker, the name (**dir = `ROLE_BLUE`, file = `ROLE_MUTED`**, exactly as
`tui_draw_tree`), and a git badge (`M`/`A`/`D`, files only, via the 0.22.4 `ftree_path` → strip-cwd →
`git_status_of` path in `_gtree_gitkind`, mirroring `_tui_tree_row_gitkind`); a selection bar marks
`ftree_sel()`; rows scroll to keep the selection in view (`_gtree_scroll_first`). **Responsive** (`gtree_w`):
`gframe_build` reserves a 230px left column + a vertical rule and shrinks the feed when the window is ≥ 640px
wide, and hides the tree on a narrower window — the feed is BYTE-IDENTICAL to before when the tree is hidden
(status strip + composer still span full width). `gui_run` calls `ftree_load()` + `git_probe()` at startup so
the pane is populated and its badges (+ the status strip's git field) have data. STATIC render this cut
(keyboard nav — focus / ↑↓ / expand-collapse — is the follow-up, mirroring feed render 0.30.1 → interactive
0.30.2). **Verified**: 1332 assertions (+9 `test_gui`: `gtree_w` thresholds, `_gtree_basename` incl. the root
edge, `_gtree_scroll_first` clamp, a synthetic-tree render, a dir row's `ROLE_BLUE`) + the frame **golden PPMs
now show the populated tree pane** with a live `M` badge on the modified `main.cyr` — visually confirmed + main
builds. **Reviewed** via a 3-lens find→verify **workflow** (safety / layout / correctness): 2 lenses clean (no
OOB, no layout overlap, feed unaffected when hidden), 1 CONFIRMED cosmetic nit (an empty pane header when
`cwd == "/"` — `_gtree_basename` returned the trailing NUL; FIXED — a trailing `/` is no longer a separator, so
root → `/`, with a test). **Test-binary cap**: the test binary is at the **16 MiB output cap** (the same cap
that keeps `gwindow`/`gpresent` main-only) — the gtree test is kept LEAN (a verbose version overflowed by ~4KB);
`gtree_build`'s full render is also exercised in the frame PPMs. A **dedicated GUI test binary** (a separate
lean `.tcyr` with only the GUI's transitive deps) is the next INFRA step before further GUI tests can grow. Pin
**6.4.49** (wrapper drifted to 6.4.50; benign). **NEXT**: file-tree keyboard nav (focus / ↑↓ move / →← or
Enter expand-collapse, wiring into `gpresent` keys — after the test-binary split); tool-call cards + colored
diffs (needs a tool-round producer); feed scrollback; composer history.

**0.30.4** — **T3 GUI: turn feedback — a working indicator + an honest "didn't complete" notice**, 2026-07-11.
The GUI ran a turn SYNCHRONOUSLY (`cmd_task` under `OUT_NULL`) with the window frozen on the old frame for the
turn's duration. Now the present loop paints ONE "working" frame BEFORE the blocking turn: the just-submitted
message is echoed as a provisional bubble + a "thoth is working…" indicator, both folded into the
bottom-anchored feed so they stay visible; on completion the feed repaints with the reply. NOT an animated
spinner — the turn blocks the event loop and this substrate has no threads, so it is a single honest pending
frame. NEW **`gturn_*`** state (`src/gui/ginput.cyr`): `gturn_begin` COPIES the submission (the composer is
reset before the turn), `gturn_end`/`gturn_active`/`gturn_text`. The present loop (`gpresent.cyr`) does
`gturn_begin` → `gcomp_reset` → pre-turn paint → turn → `gturn_end`; `_gfeed_flow` renders the pending bubble +
working line when active (measured into the flow, parity-safe). **Failure honesty**: the window renders ONLY
`session_history`, and a failed turn POPS the user message (unreachable hoosh / transport / HTTP / empty
completion → history net-unchanged), so the message would vanish silently — the **3-lens find→verify review
CONFIRMED this**. So a turn that appends no assistant reply now raises a transient RED "the turn did not
complete — is hoosh reachable? try /reprobe" notice (`gturn_fail`/`gturn_failed`, detected by `len <= n0` or
last role ≠ `assistant`) — a transient flag, NOT a `session_history` entry (never pollutes the model context);
a new submit clears it. **Verified**: 1323 assertions (+13 `test_gui`: pending active/text/copy, measure/draw
parity WITH the pending block, greeting-vs-working routing, the failure flag + exact-notice render + its parity
+ a new-submit clear) + working / failed **golden PPMs** (the pending bubble + "thoth is working…", and the red
notice below a conversation — visually confirmed) + main builds. The turn itself is network- + compositor-gated
(verify live). Pin **6.4.49** (the wrapper auto-drifted to 6.4.50; benign). **NEXT**: tool-call cards + colored
diffs in the feed (needs a tool-round producer — `session_history` is user/assistant only, tool rounds are
ephemeral); the file-tree pane (a view-builder over `ftree_*`, git badges free via `git_status_of`); feed
scrollback (Up/Down / wheel to page older on the bottom-anchor); composer history (Up/Down over the inhist
ring); optionally restore the failed submission to the composer for one-key retry.

**0.30.3** — **T3 GUI: the feed follows the conversation (bottom-anchored auto-scroll)**, 2026-07-11. The GUI
feed drew top-down from the region top and clipped anything past the bottom, so after ~3–4 turns the NEWEST
reply scrolled off-screen and was invisible. Now `gfeed_build` MEASURES the flow height (a new `_gfeed_flow`
called with `cmds == 0` — the SAME wrap/layout code as the draw pass, no emit, so measured height == drawn
height byte-for-byte) and, when it overflows the region, anchors the flow to the BOTTOM via new
`gfeed_anchor_y(total, y, h)` (`total > h - GFEED_GAP` → `y + h - total`, which is above the region top so the
existing CLIP hides the older messages that scroll off; else top-anchor at `y + GFEED_GAP`). So the newest
message sits flush above the composer and older messages clip off the top — the mockup's auto-scroll-to-bottom
behavior; a short conversation still top-anchors (natural reading order). **Verified**: 1310 assertions (+12
`test_gui`: measure/draw height parity, the fit-vs-overflow anchor decision, a command-scan proving the newest
line is on-screen while the oldest clips above the top, a leading-space wrap guard, + a rastered **golden PPM**
of an overflowing feed — newest exchange flush to the bottom, oldest clipped mid-line, visually confirmed) +
main builds. **Reviewed** via a 3-lens find→verify **workflow** (parity / anchor-math+clip / regression):
1 CONFIRMED nit (a PRE-EXISTING wrap bug the cut surfaced — a message whose content STARTS with a space and
wraps hit the space-break push with `last_sp_cols == 0`, and `max_cp == 0` means UNCAPPED in `gr_fb_text`, so
the whole string drew on line 1; FIXED — the empty leading-space segment is skipped, with a regression test),
and 1 refuted-negligible nit (a ≤4px shave off the OLDEST line when `total` is within ~4px of the region
height — documented, arguably the intended flush-bottom behavior). No parity break, no OOB (a negative
bottom-anchored `y` is clamped by the rasterizer's `gr_fb_plot`), floor byte-identical (GUI-only). Pin
**6.4.49**. **NEXT**: the turn working-state ("thoth is working…" — echo the pending message + a working
indicator on send, folded into the bottom-anchored flow so it's visible before the blocking turn); then
tool-call cards + colored diffs (needs a tool-round producer — session_history is user/assistant only);
the file-tree pane; feed scrollback (Up/Down / wheel to page older, on this anchor).

**0.30.2** — **T3 GUI: interactive — type in the window, Enter runs a turn**, 2026-07-11. The GUI becomes
USABLE. NEW **`src/gui/ginput.cyr`**: `ginput_ascii(code,shift)` (evdev keycode + shift → printable ASCII, US
QWERTY, ported from jalwa/puka) + a **composer text buffer** (`gcomp_append`/`_backspace`/`_reset`/`_len`/
`_cstr`) + `gcomp_key(code,shift)` (Esc→quit / Enter→submit / Backspace / printable→append). `gpresent.cyr`'s
key handler feeds each window key through `gcomp_key`; `gframe_build`'s composer line renders the typed text +
a caret (hint when empty); on **Enter** `gui_run` runs the turn (`cmd_task(gcomp_cstr())` wrapped in `OUT_NULL`
so the turn's progress chrome doesn't leak to the launch terminal — the user msg + reply append to
`session_history`, then the feed repaints with them) + clears the composer; **Esc** quits. The
`gpresent.cyr` include MOVED after `commands.cyr` so `gui_run` resolves `cmd_task` (Cyrius callee-first). So the
full loop works: **type → Enter → turn → reply in the feed**. **Verified**: 1298 assertions (+12 `test_gui`:
the keymap [letters/shift/digits/symbols/space/arrow-non-printable] + the composer buffer
[append/backspace/cstr/key-dispatch]) + a golden PPM of the interactive state (a conversation + a half-typed
composer "> and criterion benches|" with a caret — visually confirmed) + main builds. The keymap + composer
are PURE + unit-tested; the actual TURN is network- + compositor-gated (unverifiable in the sandbox — verify on
the user's machine). A repaint BLOCKS for the turn's duration (no spinner yet; matches the TUI). identifier
buffer ~86% (soft). Pin **6.4.49**. **NEXT**: a turn spinner (non-blocking feel); tool-call cards + colored
diffs in the feed (map `Thoth.dc.html`); the file-tree pane; feed scrollback; composer history (Up/Down).

**0.30.1** — **T3 GUI: the conversation feed + composer layout**, 2026-07-11. The window becomes an app — the
body renders the CONVERSATION (the mockup's main region), not placeholder text. NEW **`src/gui/gfeed.cyr`**:
`gfeed_build(cmds,x,y,w,h)` reads the SAME `session_history_*` the TUI feed + `/save` read and lowers each
message to draw-commands (user → a `>` accent marker + text; agent → plain body), each **word-wrapped** to the
pixel width via `_gfeed_para` — codepoint-accurate (uses the graster UTF-8 decoder), breaks at spaces,
hard-breaks an over-long word, and draws each wrapped line as a `(start,cols)` SLICE through `gd_push_text`'s
`max_cp` cap (NO per-line copy). Empty conversation → an honest `_gfeed_greeting` empty-state (the app's
opening screen, never a faked exchange). `gframe_build(w,h)` (MOVED here from `gpresent.cyr` so it is
headless-testable) assembles the three-region layout: status strip (top, the 0.28.0 view-model) · feed
(middle, clipped) · composer line (bottom, a `>` prompt + hint). So the GUI now shows a real conversation:
the status view-model drives the strip, and the feed reads the history producer. `gpresent.cyr` shrinks to
just the raster+present loop. **Verified**: 1286 assertions (+5 `test_gui`: word-wrap multi-line / single-line
/ null-safe + a full 2-message frame render) + a golden PPM (a user+agent exchange wraps + lays out correctly
— visually confirmed) + main builds + `thoth gui` degrade path unchanged. Live `thoth gui` shows the greeting
empty-state until input is wired (NEXT cut). identifier buffer ~86% (soft). Pin **6.4.49**. **NEXT**:
input→action — capture evdev keys (already flowing via `gwl_win_next_key`) into a composer buffer, submit on
Enter → run a turn → append to history → repaint (makes it interactive); then tool-call cards / diffs in the
feed, and the file-tree pane.

**0.30.0** — **T3 GUI, Phase 2: a runnable `thoth gui` Wayland window** + the cyrius **6.4.49** refresh,
2026-07-11. The desktop tier becomes REAL: the GUI is now in the SHIPPING binary with a sovereign Wayland
present shell + a `thoth gui` subcommand. **Toolchain**: cyrius **6.4.46 → 6.4.49** (latest; `cyrius lib sync`,
71 files; the pin now matches the wrapper — drift warning gone). The newer toolchain's larger code-buffer
headroom (it starts at 8 MB and grows to 64 MB — the earlier "91%" was a soft first-line warning, never a wall)
is what lets the GUI draw pipeline (`gdraw`/`graster`/`gstatus` + vendored kashi) move from the test binary
into **`main.cyr`**. NEW **`src/gui/gwindow.cyr`** — a self-contained Wayland client (wl_registry/compositor/
shm + xdg-shell + memfd/mmap XRGB8888 wl_shm + evdev keyboard, raw wire, no libwayland), PORTED VERBATIM from
jalwa's `wayland.cyr` (a puka fork) with a `jlw_→gwl_` / `JLW_→GWL_` rename + app-id "thoth"; thoth owns its
copy (port the FLOOR — the window substrate, destined to extract to aethersafha). Seam: `gwl_win_open`/
`_present_begin`/`_present_commit`/`_poll_events`/`_next_key`/`_resize_apply`/`_close`. NEW
**`src/gui/gpresent.cyr`** — `gui_run()` (the event loop: poll the wl fd → `gwl_win_poll_events` → resize/key/
close → repaint) + `gframe_build(w,h)` (the window frame = the 0.28.0 status strip + a rule + a body greeting,
over the TESTED draw pipeline) + `_gpresent_frame`/`_drain_keys`/`_poll_fd`. **`thoth gui`** subcommand
(`ONESHOT_GUI`, `src/oneshot.cyr` requires `gui` as the sole arg; `src/main.cyr` routes to `gui_run`). **Degrades
HONESTLY** with no compositor: a stderr note ("no Wayland compositor available — set WAYLAND_DISPLAY …") + a
nonzero exit, never a hang or fake window. **Verified**: main builds (15.86 MB, under the 16 MiB output cap;
`thoth gui` prints the honest degrade + exits 255 in this headless sandbox; `--version`/`/seams`/piped floor
unchanged) + 1281 assertions (the headless draw pipeline stays unit-tested; the present shell is main-only —
the test binary would exceed the 16 MiB output cap, and the shell is compositor-gated / smoke-only anyway).
**LIVE-CONFIRMED** (2026-07-11): the user ran `thoth gui` on a real Wayland compositor — the window opens with
the status strip + body preview text rendering correctly. (The headless sandbox only exercises the honest
degrade path; the live window needs a compositor — Hyprland/wlroots, or aethersafha on AGNOS.) **Per-frame**: repaints are EVENT-DRIVEN so the bump-heap command leak is bounded (thoth's `alloc` has
no mark/rewind → `alloc_reset` is not a per-frame arena; a reused command pool is the future opt). **Identifier
buffer** now ~86% (the vendored client adds 357 `gwl_wl_*` symbols) — a soft warning, headroom remains.
**REVISES ADR-0009** (T3 = thoth-as-its-own-sovereign-Wayland-app, NOT thoth-in-puka — see the ADR addendum).
Pin **6.4.49**. **NEXT**: verify `thoth gui` on a real compositor; then more view-builders (feed / tool-card /
composer from `Thoth.dc.html`) + input→action wiring (evdev keys already flow through `gwl_win_next_key`).

**0.29.0** — **T3 GUI, Phase 1: the headless draw pipeline**, 2026-07-11. Starts the DESKTOP tier — the
payoff the Stage-B view surface was setting up — following jalwa's proven, phased, headless-testable pattern
(draw-IR → CPU raster → view-builder; the Wayland present shell is a later cut). Three NEW pure modules under
**`src/gui/`**: **`gdraw.cyr`** (the draw-command IR — RECT/TEXT/BORDER/CLIP as packed 8-slot cells
`[kind,x,y,w,h,color,text,aux]` on a `vec`; `gd_push_*` builders + `gd_*` accessors), **`graster.cyr`** (a CPU
rasterizer executing the command list into an XRGB8888 `wl_shm`-layout buffer — `gr_fb_fill_rect`/`_border`/
`_glyph`/`_text` + a one-level clip + `gr_raster`; UTF-8→CP437-folded text over the **kashi** VGA 8×16 font;
ported from jalwa's raster + puka's fb, thoth owns its copy — port the floor), and **`gstatus.cyr`**
(`gstatus_build` — the status STRIP view-builder that lowers the 0.28.0 `status_snapshot()` FACTS into
draw-commands, mirroring `tui_draw_status`'s fields + omit gates). **The status view-model now has THREE
renderers** — line rows (`/state`), the TUI strip, and the GUI strip — over ONE facts model, no new producer.
Colors are `ui.cyr`'s `_ui_rgb(role)` verbatim (already packed XRGB), so the GUI shares the TUI's amber/light
palette + `/theme` for FREE; the health dot the TUI draws as `●` the GUI draws as a filled rect
(facts→richer-mark). Vendored **kashi 1.0.2** (`src/vendor/kashi.cyr`, freestanding, zero-stdlib). **Verified**:
1281 assertions (+23 `test_gui`: draw builders, `fill_rect`/`border`/glyph pixel checks, `gr_text_cols`
codepoint width, a full strip render) + a **golden PPM** rastered headless (rendered "thoth 0.28.0 Thoth model
claude-opus-4 [green dot] turns 0 main +14 surface T0 plain theme dark" in the amber palette — validated
visually). **Process**: designed via a workflow (survey + 3 competing designs → the facts-not-bytes view-model
approach), reviewed via a 3-lens find→verify workflow — 2 CONFIRMED (same real bug: `_gstatus_txt` advanced
the layout pen by `strlen` BYTES while the rasterizer advances by CODEPOINT, drifting a non-ASCII git
branch / persona name; FIXED with `gr_text_cols`), plus a null-guard, a strip clip, and a documented frame-arena
requirement; no reachable OOB/crash. **HONEST SCOPE**: the GUI modules compile + test in the TEST binary ONLY,
NOT in `main.cyr` — no `gui` subcommand or present shell yet, so the SHIPPING binary is unchanged. They wire
into `main` at the present-shell cut, after the code-buffer lift (main is ~91% of the 3.14MB code cap; the user
is handling that separately). A repaint loop MUST bracket each frame with `alloc_reset()` (frame arena). Pin
**6.4.46** (wrapper auto-drifted to 6.4.49; benign). **NEXT**: the present shell (a puka-forked sovereign
Wayland client → a runnable `thoth gui`, needs the code-buffer lift + a compositor to verify), and/or more
view-builders (feed / tool-card, mapping `Thoth.dc.html`). Revises ADR-0009 (T3 = thoth-as-Wayland, not
thoth-in-puka) — an ADR update is due at the present-shell cut.

**0.28.0** — **the status view-model (Stage B opens)**, 2026-07-10. Realizes ADR-0009's declared-but-unbuilt
**semantic surface** for the status fields. NEW **`src/surface.cyr`**: `status_snapshot()` reads the ~10
status producers ONCE into a packed i64 cell array (SF_* fields × SFC_* cells) and NORMALIZES them into FACTS
(enums + ints + cstr ptrs — never bytes/color/layout); accessors `status_present`/`status_state`/`status_ival`/
`status_ival2`/`status_sval` (each guards `_sf_rows==0` → crash-safe before the first snapshot). The rich-TUI
status bar (`tui_draw_status`) AND the `/state` report (`cmd_state`) now render their overlapping fields from
this ONE model instead of each re-reading producers + re-implementing the omit gates. The ctx KiB formula is
single-sourced into the PRODUCER (`hoosh_ctx_kib`/`hoosh_ctx_budget_kib`, `src/hoosh.cyr`). `cmd_state`
`git_probe()`s before the snapshot (moved up; behavior-preserving); the ~13 `/state`-only config rows are
untouched. **A PURE REFACTOR** — byte-identical at every tier: a piped `/state` byte-diff (before vs after)
was IDENTICAL modulo the volatile git dirty count, a PTY status-bar capture IDENTICAL likewise, and the edge
branches (null model → `(none set)`/`default`, health-absent, git-absent, T0 surface) separately verified.
**Value delivered** (honestly NOT a LOC win — the content layer was already tier-neutral via the ui.cyr/emit
choke points): **drift-safety** (the presence gates + model fallback that had silently diverged between the
bar and `/state` are now single-sourced + tested once) and **GUI-readiness** — because the model holds facts
not bytes, a future **T3 Wayland status widget** is a third leaf-writer over the SAME accessors (no draw-IR
committed now; its shape is learned when the GUI is built, per jalwa). **Process**: designed + reviewed with
multi-agent **workflows** — a survey + 3 competing designs judged adversarially (Design A "facts-not-bytes
snapshot" won; the honest verdict: the keystone earns its keep on GUI-readiness + drift-safety, not dedup),
then a 3-lens find→verify review of the result (all 3 lenses converged on ONE nit — the value accessors
lacked the `_sf_rows==0` guard `status_present` had — CONFIRMED unreachable-today but a latent trap for the
future T3 consumer; fixed before the cut; no byte-identity or correctness defect found). **Verified**: 1258
assertions (+18 `test_surface`) + LIVE byte-diffs at both tiers + edge-branch checks. Pin **6.4.46** (wrapper
auto-drifted to 6.4.49; benign). **NEXT (Stage B continues)**: adopt the surface for the feed/tool-card/diff
(the bigger GUI prize per the architecture judge), then the **T3 Wayland GUI** (thoth as its own sovereign
Cyrius Wayland app — jalwa-style draw-IR → kashi raster → wl_shm → puka-forked shell; `Thoth.dc.html` spec;
revises ADR-0009's "thoth-in-puka"). See CHANGELOG/roadmap.

**0.27.0** — **toolchain refresh + tier-consistency parity fixes**, 2026-07-10. Opens the **simple↔rich
consistency line** (rich = the rich TUI experience; simple = line-mode back-and-forth; anything that is *not*
a rich-TUI blocker works at BOTH). **Toolchain**: cyrius **6.4.29 → 6.4.46** (`cyrius lib sync`, 71 stdlib
files); vendored dists re-synced — bote-core **3.1.1**, darshana **0.9.0**, libro **2.7.10**, sankoch-zlib
**2.5.1**, sit-read **1.3.4** (avatara 2.8.0 / t-ron 2.1.7 / vyakarana 2.2.3 unchanged; darshana is manually
vendored — no `sync-darshana.sh` yet). **Three parity fixes**, each closing a rich-only-but-pure-data gap:
(1) **`/reprobe`** (alias **`/ping`**, `cmd_reprobe`) re-checks hoosh reachability from ANY tier — the
shared/line-mode equivalent of the TUI's Ctrl-R, wrapping the existing `hoosh_health_probe()` — plus a
**`health` row in `/state`** for the cached reachability that was previously only the TUI status-bar dot;
(2) **`/save` in line mode** sources the tier-neutral conversation history (`session_history_*`) as a markdown
transcript when there is no feed ring (`cmd_save`/`_save_history`), closing the 0.24.1 line-mode gap;
(3) **`[history].file` persistence in line mode** — the REPL now records each submit into the inhist ring +
mirrors it to the file when configured (`src/main.cyr` shared init + load announce, `src/repl.cyr`
record/persist/broke-note; inhist was previously inited only inside `tui_loop`), plus **`/history`** to list
the ring in both tiers (Up/Down recall stays a rich-only raw-mode affordance). The plain/piped/one-shot
**FLOOR stays byte-identical** (persistence OFF by default; the new records are silent memory ops).
**Verified**: 1240 assertions (+10: `/reprobe`+`/ping`+`/history` classify, the `/save` history-path
round-trip) + LIVE in line mode — `/reprobe` reports honest unreachable, the `/state` health row, `/save`
writes a history transcript, and a real two-process **cross-session round-trip** where session 2 recalled
session 1's inputs from `[history].file`. Pin **6.4.46** (the wrapper auto-drifted to 6.4.48; a benign 2-patch
drift). **NEXT: Stage B** — the tier-agnostic **view surface** (`src/surface.cyr`; ADR-0009's semantic
intents) so simple/rich render ONE model and the future **T3 GUI** (jalwa-style sovereign Wayland,
`Thoth.dc.html` as the spec) becomes a fourth renderer rather than a front-end fork.

**0.26.0** — **`.thoth/` home discovery + honest readiness**, 2026-07-09. Config + project memory now live
under a discoverable `.thoth/` home (like `.git/`): `.thoth/config.cyml` + `.thoth/memory/`, found by walking
UP from the CWD then `~/.thoth/` (legacy `./thoth.cyml` still read). The rich-TUI greeting no longer claims
READY off the silent localhost default when no config was discovered — it states the config source honestly.
Fixes "launched in another repo, couldn't find hoosh, yet said READY." `src/config.cyr` (`_thoth_root_resolve`
/ `config_path` / `config_source` / `config_root`), `src/memory.cyr` (`memory_dir` / `memory_index_path` off
the same root), `src/tui.cyr` greeting; ADR-0016; 1231 assertions; live-verified (upward/legacy/absent config,
rich-TUI greeting, upward memory). Toolchain: bote 3.1.1 + daimon 1.4.1 re-pinned to cyrius 6.4.34 (the native
TLS record-layer fix), the libssl web-tools workaround dropped.

**0.25.1** — **composer soft-wrap**, 2026-07-09. The prompt input now word-wraps at the screen edge + grows
the input area, instead of horizontal-scrolling one long line (user-reported). `src/tui.cyr` composer is now
PHYSICAL-row aware (mirrors the 0.11.3 FEED soft-wrap): a logical line of L bytes wraps across `L/avail + 1`
rows (`avail = cols - 6`; the +1 hosts the end cursor). NEW pure helpers `_comp_avail`/`_comp_total_rows`
(height oracle, replaces `led_lines()` at every geometry call site: `tui_composer_height/top`,
`tui_sep_bottom_row`, `tui_feed_bot` — so the feed band + rules track the grown composer)/`_comp_cursor_prow`/
`_comp_prow_to_offset`. `tui_park_cursor` = `top + (cursor_prow - vscroll)`, col `6 + cursor_col%avail`;
`tui_draw_composer` walks logical lines → their `avail`-wide byte segments, painting the vscroll window
`[vf, vf+H)` (prompt on the first visible row, 5-col indent on the rest). `led_up`/`led_down` now move by
VISUAL (wrapped) row (`_comp_prow_to_offset`), edge→history only at the true top/bottom physical row. Removed
`_comp_row_hstart` (h-scroll gone). Limit (documented): byte-based wrap — a multibyte glyph straddling a wrap
boundary may render as a replacement char (same class as the feed's glyph-width-1 limit; no regression from
the old clamp). **Verified**: 1230 assertions (+14 soft-wrap: `_comp_avail`/`_comp_total_rows`/`_comp_cursor_prow`/
`_comp_prow_to_offset` at a narrow width, visual up/down across wrapped rows + edges, a wrapped line + hard
newline summing rows) + LIVE over a PTY (40-col terminal, an 80-char line wrapped to 3 rows). Pin **6.4.29**.

**0.25.0** — **role modality: the third persona axis** (avatara 2.8.0 + thoth), 2026-07-09. The long-planned
role axis, built end-to-end — NOT "avatara-blocked" (that earlier conclusion was WRONG; it was adjacent-easy
work done to defer the hard ask). An archetype is a personality vector (15 traits + 14 emphases + soul/spirit +
one domain) with no role field; a ROLE is **derived from a personality aspect**. **avatara 2.8.0** adds
`src/aspect.cyr` (trait-derived aspects — `aspect_count`=8/`_name`/`_role`/`_trait_offset`/`_index_by_name`,
`profile_aspect_weight`, `profile_dominant_aspect` [f64 argmax, ties→lowest, null-safe]; universal over all 374
archetypes, no per-archetype authoring; released via `version-bump.sh 2.8.0` → `dist/avatara.cyr`, vendored to
`src/vendor/avatara.cyr` [local copy; the GitHub-tag `sync-avatara.sh 2.8.0` runs on push]). **thoth**:
`persona_role()` precedence = user override → selected aspect's role → default (still "the Librarian" for the
signature Thoth; else the DOMINANT trait aspect — avatara-sourced, never thoth-authored per-archetype prose;
replaces the old `desc` default); `_persona_aspect`/`_persona_role_override` (both reset by `persona_set` on a
switch); `persona_role_select_aspect`/`_override_set` [COPIES the label]/`_reset`/`persona_aspect`. The active
role is woven into `persona_system_prompt` ("In this session you take the role of …") so it STEERS the turn,
rebuilt in place on change. NEW **`/role`** (`cmd_role`, `CMD_ROLE=28`): no-arg lists the archetype's aspects
(marks active `*` + dominant); `/role <aspect>` leans in; `/role <any label>` sets a custom role (Librarian /
Deep Thinker / Personal Scribe / Keeper of Symbols); `/role reset`. **Verified**: avatara 82 assertions
(+11 aspect), thoth 1216 (+`test_role`; updated the persona-switch default-role assertion to the aspect) + LIVE
(`/role` lists Thoth's aspects with "the Measurer" dominant; `/role measurer` → the Measurer; `/role Keeper of
Symbols` → custom; `/role reset` → the Librarian). Pin **6.4.29**; avatara built under 6.4.29 (its 6.2.11 pin is
a benign drift warning). Design: trait-derived base, user-overridable, evolve later (avatara's index-stable API
can grow per-archetype overrides). Bundled in this working set with the 0.24.4 `/reload` review-fixes (below).

**0.24.4** — **`/reload` (re-read thoth.cyml mid-session)**, 2026-07-09. Closes the `0.24.x` arc + review-fixes
(config_parse_ok → honest degrade on an unreadable file; hoosh_auth_cache_reset → a rotated token applies). `cmd_reload`
(`src/commands.cyr`, `CMD_RELOAD=27`): `file_exists(CONFIG_PATH)` guard (absent → "nothing to reload", no
state touched) → `config_load()` (re-parse rebuilds `[alias]`/`[shell]`/`[pricing]`/read_roots + all `_cfg_*`)
→ `agent_tools_cache_reset()` (NEW in `src/agent.cyr` — drops `_agent_tools_ready`/`_agent_tools_len` so a
changed `[shell].enabled`/`[hoosh].tools` or a now-reachable daimon re-advertises next turn) → an HONEST report.
The hot/bind-once split is grounded in the actual data flow: **hot** (runtime reads per-use) = `[alias]`
(dispatch), `[shell]` rules/caps (per call), `[ui]` (per turn), `[pricing]` (at accumulate), `[hoosh]` flags
model/stream/history/tools/parallel (per turn), `[memory].enabled` (per turn); **additive** = `[project]`
read_roots (`project_grant_root` dedups, never revokes); **bind-once / restart** = `[hoosh]`/`[daimon]` url
(the SEAMS + first-use-cached `_hoosh_endpoint`/`_models_ep`/`_catalog_ep`), `[tron].policy`, `[log]`,
`[persona].name`, `[history]`/`[session]` file (all bound at startup). Never claims a reload changed something
it didn't. **Verified**: 1201 assertions (+3 `test_reload`: `agent_tools_cache_reset` clears the flag+len,
`config_load` re-run is safe/no spurious rebuild — `cmd_reload` itself reads the gitignored thoth.cyml so it is
LIVE-verified not unit-tested, per the CI-fixture rule) + LIVE (added a `[alias]` to thoth.cyml mid-session →
pre-reload `/zzz` unknown → after `/reload`, `/zzz` expanded to its target; "reloaded" confirmed). Pin
**6.4.29**. **The 0.24.x polish arc is COMPLETE** (model picker · `/save` · resume · niceties · `/reload`);
only role modality remains, deferred (avatara-blocked). NEXT: the v1.0 gate items (AGNOS-dominated; see
[[thoth-next-items-gate-map]]) or a new user-directed line.

**0.24.3** — **turn-completion niceties ([ui] bell + elapsed)**, 2026-07-09. Two opt-in, INTERACTIVE-ONLY
touches that close the terminal-citizen line (OSC-0 title was 0.22.3). `[ui].bell` → a terminal BEL (0x07) on
turn completion, written to fd1 via `_ui_emit_bell` (emit_raw_n of a [0x07,0] buffer — bypasses the OUT_RING
feed sink, like the OSC-52/kitty escapes, so it works over SSH + never corrupts the TUI frame). `[ui].elapsed`
→ a faint `(N.Ns)` line after each reply (`_task_emit_secs`: ms/1000 . (ms%1000)/100, clamped at 0). Wiring:
`cmd_task` now times the turn (`t0 = clock_now_ms()` before `agent_turn`/`hoosh_send`, captures rc, calls
`_task_turn_feedback(t0)`, returns rc unchanged) — `_task_turn_feedback` gates on `one_shot_active()==0` so
one-shot/`--json`/piped output is byte-identical, then rings bell + prints elapsed per the toggles. Config:
`[ui]` section → `_cfg_ui_bell`/`_cfg_ui_elapsed` (via `_cfg_bool`, default 0) + `config_ui_bell/_elapsed`. A
`/state` `ui` row when either is on (omitted when both off → floor byte-identical). Both DEFAULT OFF (consistent
with the shell/memory/history/session opt-in discipline). **Verified**: 1198 assertions (+9 `test_ui_niceties`:
`_task_emit_secs` boundaries incl. sub-second/negative/large, one-shot suppression, interactive emission,
both-off floor) + LIVE (a REPL turn with `[ui]` on emitted the `0x07` BEL + `(2.0s)`). Pin **6.4.29**.
Followed by 0.24.4 (`/reload`, above).

**0.24.2** — **conversation resume ([session].file)**, 2026-07-09. Opt-in persistence of the conversation
history (role + content per message) across restarts — relaunch and pick up where you left off. DISTINCT from
`[history].file` (composer keystrokes) and the mneme seam (durable facts). INTERACTIVE-ONLY (main.cyr binds it
after the one-shot dispatch returns; one-shot never persists). All logic in a new `src/session.cyr` section.
**Format** (framed, length-prefixed so multi-line content needs NO escaping): `THOTH-SESSION-1\n` then
`<role>\t<clen>\n<clen content bytes>\n` records. `_sess_write_file` (rewrite the window each save, checks
every `file_write`), `_sess_load_file` (read ≤3 MiB, verify magic, parse → `session_history_append`;
HARDENED — rejects a non-numeric / i64-overflowed / oversized `clen` before any pointer math, so a hostile
file can't OOB), `_sess_role_literal` (maps parsed roles to STABLE literals — `session_history_append` stores
the role POINTER uncopied; content IS copied), `_sess_probe_writable` (non-destructive 0600 create),
`sess_persist_init/_save/_active/_broke/_resumed/_greeting`. **Save hooks**: the 3 assistant-append sites
(agent.cyr ×2, hoosh.cyr ×1) save ONLY on success (a popped/failed turn leaves the last-good file); `cmd_reset`
rewrites it empty (so `/reset` isn't undone by resume). **Wiring**: `config_session_file` (`[session].file`),
init in main.cyr (interactive-only), greeting in `print_banner` + the TUI greeting, broke-note in both loops,
a `resume` row in `/state` (shown only when active → floor byte-identical). **Secrets** (mirrors 0.11.2): OFF
by default, best-effort `0600` on fresh create, degrade-closed, honest residuals documented (pre-existing
looser file not re-tightened, AGNOS drops the mode, symlink-follow); writes the conversation in PLAINTEXT —
never asserts a mode it can't enforce. **Verified**: 1189 assertions (+25 `test_session_persist`: uint fmt,
role-literal mapping, save→clear→load round-trip incl. MULTI-LINE content, foreign-magic skip, absent-file,
init+activate+resave, >40-record count-cap) + LIVE across a real restart (process 1 learned codeword
PLATYPUS-7 → process 2 announced "resumed 2 messages" and recalled PLATYPUS-7; file mode `0600` confirmed).
**4-lens adversarial review** (parser / role-pointer / hooks / secrets): persistence sound; REFUTED the
clen-overflow OOB (the proactive `clen < 0 || clen > total` guard holds) + caught & FIXED two low findings —
(1) the greeting overstated the resume count (counted parsed records, not the post-eviction `session_history_len()`);
(2) the format doc's "raw bytes" claim was imprecise (content is a NUL-terminated cstring — an interior NUL
terminates it, as it must since a raw 0x00 can't be re-sent in a JSON string). Pin **6.4.29**. Followed by
0.24.3 (turn-completion niceties, above).

**0.24.1** — **`/save <file>` transcript export**, 2026-07-09. Writes the TUI feed scrollback to a file as a
plain-text/markdown transcript. NEW `feed_strip_ansi_into` (`src/feed.cyr`): pure ANSI stripper — drops
thoth's 2-byte role/reset markers (`ESC`+`0xB0..0xB7`/`0xBF`), CSI runs (`ESC '[' … 0x40..0x7E`), and other
2-byte `ESC` forms; text (incl. UTF-8) passes verbatim (only `ESC`-introduced runs removed). NEW `cmd_save`
(`src/commands.cyr`, `CMD_SAVE=26`): open `O_WRONLY|O_CREAT|O_TRUNC` `0644` via the portable `lib/io.cyr`
wrappers (same as the `-o` tee), write a `# thoth transcript` header + each `feed_line_ptr/_len` line stripped
into `_save_buf` (`SAVE_BUF=2048==FEED_LINE_CAP`) + `\n`, checking every write. NOT t-ron-gated (the user's own
export to a named path, like `-o`; the model can't invoke a slash command). Degrades honestly: no arg → usage;
empty ring (line mode never captures the feed) → note; open-fail / short write → announced, never faked. HONEST
LIMITS (documented): the feed ring is TUI-only + bounded (`FEED_ROWS=2048` — older scrollback evicted, not
saved). **Verified**: 1164 assertions (+10 `test_save`: stripper over markers/CSI/lone-trailing-ESC/plain +
a real round-trip — populate the ring, save, read the file back, assert header + content + ZERO escape bytes)
+ LIVE over a PTY (`--tier=rich`: `/help` → `/save /tmp/…` → a clean marker-free markdown file). Pin **6.4.29**
(re-pinned — the env drifted the active cycc to 6.4.32; repointed `~/.cyrius` symlinks + `current` to 6.4.29).
Followed by 0.24.2 (conversation resume, above).

**0.24.0** — **model-picker palette** (Ctrl-P), 2026-07-09. Opens the `0.24.x` arc. An interactive TUI modal
over hoosh's model catalog that switches the active model through the EXISTING `/model` seam — no new switch
machinery. NEW `src/mpick.cyr` = pure state/filter/nav: `_mp_add` (bounded copy into packed storage),
`_mp_match` (case-insensitive substring), `mpick_refilter` (rebuild view + clamp cur/scroll), `mpick_query_push/pop`,
`mpick_move` (clamped), `mpick_select_id` (pre-highlight the active model), `mpick_id_at`/`mpick_selected_id`,
`mpick_load` (I/O). Data via NEW `hoosh_catalog_fetch` (GET `/v1/models/catalog`, 404-fallback to `/v1/models`,
returns the parsed model array or 0 + `hoosh_catalog_last_err`; `/v1/models` alone lists PROVIDERS not concrete
models, so the catalog is required). Modal wiring in `src/tui.cyr` (modeled on the Ctrl-F feed-search modal):
`KEY_PICK`=31 (**Ctrl-P** = raw byte 16 + kitty cp 112, both confirmed free), `_mpick_active`,
`_tui_pick_enter` (blocking silent fetch → pre-select active → paint; degrades to a one-line feed note when
hoosh absent/unreachable/empty, no modal), `_tui_pick_paint` (overwrites the feed band with the filtered list,
selected row accent + active target `*`, scroll window keeps cur visible), `_tui_draw_pick_hint` (the `pick:`
strip: query + i/n + keys), `_tui_park_pick`, `_tui_pick_key` (Esc/⌃C cancel, Enter switch, ↑↓ move, type to
filter), `_tui_pick_apply` (the SAME seam as `/model`: `session_set_model_copy` + `term_title_set` + audit),
`_tui_pick_exit` (full repaint). Gated everywhere: loop routing (mpick before fsearch), WINCH repaint,
`tui_draw_hint` + `tui_park_cursor` gates, idle-hint `Ctrl-P model`, `/model` help. TUI-ONLY → line-mode/one-shot
floor byte-identical. **Role modality** (the originally-planned 0.24.0) **deferred** — an archetype aspect
registry is avatara's to provide (thoth exposes only `persona_role()`, one role of the active persona); it stays
a design + upstream-request, not code. **Verified**: 1154 assertions (+19 `test_mpick`: filter CI-substring +
mid-string, nav clamp, query pop restore, select_id, refilter clamps a stale selection, empty-id refusal) +
LIVE over a PTY (`--tier=rich`: Ctrl-P → catalog list [claude-opus-4/gpt-4o/o3-mini] → filter `opus` [gpt-4o
drops] → Enter → `model ->` switch in the feed → Ctrl-X clean exit). **4-lens adversarial review** (memory /
logic / TUI-floor / honesty): modal sound; caught + FIXED one defensive gap — `_mp_add` now refuses an empty
model id (a malformed `{"id":""}` catalog entry is a non-null zero-length Str that would otherwise become a
blank row switching to an empty model). Pin **6.4.29**. Followed by 0.24.1 (`/save` transcript export, above).

**0.23.1** — **user-granted read roots: the user widens the jail** (ADR-0015), 2026-07-08. The 0.23.0 read
tools were confined to the launch cwd; now the *user* (never the model) can grant read access to additional
ABSOLUTE roots — review another repo, or read the **vidya** Cyrius knowledge base and bring the latest
language features back to the project. A permission model like every other restriction. **Read boundary
widened** (`src/project.cyr` `_project_read_ok`): allow a jailed in-project relative path OR an absolute path
— no `..` component — under a granted root; `_project_under_root` prefix-matches on a `/` boundary (`/a/b`
under `/a`, `/ab` not); `project_grant_root` requires absolute + longer than `/`, strips trailing slashes,
dedups (bounded READ_ROOTS_MAX=16, owned copies); `_project_no_dotdot` extracted from `_project_jail_ok` and
reused. **Grant sources**: config `[project].read_roots` (persistent, `_cfg_read_roots_load` — array or
lenient bare-scalar) + `[project].vidya` (`config_vidya`, the `/allow vidya` target); and the new **`/allow`
command** (`cmd_allow`, CMD_ALLOW=25 — no-arg lists read access, `<abs-path>` grants, `vidya` grants the
configured root; the MODEL can't call a slash command → the human authorizes, like `/run`). `/state` gains a
`reads` row (agent-on only → floor byte-identical). `read_file`/`list_dir` tool descriptions updated so a
user-supplied external path is attempted, not pre-refused. **Ordering**: `project.cyr` include moved before
`config.cyr` (config_load grants configured roots). **Verified**: 1135 assertions (+22: grant accept/reject,
dedup/trailing-slash, `_project_read_ok` boundary matrix, end-to-end `/etc` grant flips a refused path) +
LIVE end-to-end (config-granted vidya → model read `/home/.../vidya/VERSION` = "2.8.0"; **negative control**:
grant removed → model got the exact "refused - outside the project and any user-granted read root" string).
Residual carries over: symlink inside a granted root is followed. Pin **6.4.29**. NEXT: **`0.24.x`** — role
modality (deferred from 0.23), model-picker palette, `/reload`, `/save`. See CHANGELOG/roadmap/ADR-0015.

**0.23.0** — **project awareness: the agent can see the codebase** (ADR-0015), 2026-07-08. Opens the
`0.23.x` line, closing the gap that a *coding* agent was blind to the project it was launched in (its context
was prompt + persona + memory FACTS + tool results; code reached it only via `@file` mentions or the opt-in
`shell` hammer). New `src/project.cyr`: model-invokable **`read_file(path)`** + **`list_dir(path)`** riding
the `/read` + file-tree substrate (no new read path, no spine fork; daimon MCP stays additive), dispatched
LOCALLY in agent.cyr (never to daimon), advertised **default-ON**. Security = the **project JAIL**
(`_project_jail_ok`): absolute paths, leading `~`, and any `..` component refused → reads confined to the
launch cwd + below (no `~/.ssh`, `/etc`); the jail is the boundary so reads are NOT t-ron-gated (read-only,
confined); output bounded (64 KiB/file, 16 KiB/listing). **`agent_enabled()` now = `[hoosh].tools` alone**
(was "tools AND (daimon OR shell)") — read/list are always-available local tools, so the loop runs whenever
tools are on; the agent sees the project even hoosh-only. Wiring: `agent_tools_add_project` (always adds both;
call site only reached when agent_enabled), `_agent_round_has_local` (forces serial), the serial dispatch
elifs (`read_file_tool`/`list_dir_tool`, RL_ALLOWED, echo "result: N bytes" not the content). **Security
review (3-lens, jail-bypass/bounds/dispatch): the jail is airtight (no POSIX bypass)** + caught one
regression (fixed): the default-on tools made `tl>0` unconditional, so the tool-cache latch fired even on a
FAILED daimon fetch → a transient daimon-down permanently cached an empty registry; now the latch gates on
the daimon fetch (`SEAM_DAIMON absent || dtv != 0`), restoring the self-heal. **Residuals** (documented):
symlink-inside-project escape (no O_NOFOLLOW); Windows backslash/drive paths (deferred — `--win` doesn't
ship). **Verified**: 1113 assertions (+21 net: `test_project` +22, agent truth-table -1; jail accept/refuse,
read_file/list_dir real + refusals + errors) + LIVE (the model autonomously called `read_file{path:VERSION}`,
jailed-read it, answered "0.23.0"). Pin **6.4.29** (env kept drifting the active cycc to 6.4.30/31; re-pinned
to 6.4.29). Followed by 0.23.1 (user-granted read roots, above).

**0.22.4** — **file-tree git badges** (polish sweep), 2026-07-08. The file-tree pane surfaces changed files
with `M`/`A`/`D` markers from the ALREADY-probed sit status — content-blind, no new worktree walk.
`src/git.cyr`: `git_probe` now copies `sit_repo_status`'s per-file {path, kind} (before `sit_repo_close`, since
sit's paths are arena-owned) into REUSED buffers (`_git_status_buf`/`_ptr`/`_kind`/`_n`, rewritten each probe →
no accretion, bounded GIT_STATUS_MAX=512); `git_status_of(relpath)` linear-scans it (1=modified, 2=new,
3=deleted, 0 = unchanged/no-repo). `src/tui.cyr`: `_tui_tree_row_gitkind(li)` derives the node's repo-relative
path (strip `ftree_cwd()`+`/` off the absolute `ftree_path`) → `git_status_of`; `_tui_paint_tree_row` reserves
a 2-col gutter on EVERY row IN A REPO (colored M/A/D or blank; the name clips to `tw-2`; alignment holds),
badges files only, colors M=ROLE_ACCENT/A=ROLE_GREEN/D=ROLE_RED, and outside a repo emits NO gutter (floor
byte-identical). Review-nit fix: badges off when `tw<3` (no sub-6-col gutter overflow). **Verified**: 1092
assertions (+5, `git_status_of` white-box kinds + gate) + LIVE via PTY (changed `src/tui.cyr`/`src/git.cyr`
render an amber `M`; committed/unchanged + dirs render a blank gutter; matches sit's 13 changed). A 3-lens
review returned one nit (fixed). Toolchain: pin **6.4.29** (env kept auto-drifting the active cycc to
6.4.30/6.4.31; re-pinned the active toolchain to 6.4.29 each time to match). NEXT (new PRIORITY line, per the
user): **project awareness** — model-invokable `read_file`/`list_dir` so the agent can SEE the codebase it was
launched in (today it's blind: only `@file` mentions + the opt-in `shell` hammer), default-ON with the agent
loop, default project-JAILED with a user-grant to widen (review another repo, read **vidya** for Cyrius
features) — a permission model like the other restrictions. See roadmap 0.23.x.

**0.22.3** — **terminal window title** (first polish sweep), 2026-07-08. With the active-persona core done
(0.22.0–0.22.2), the `0.22.x` line now draws vetted **polish-backlog** items (role modality moved to the new
`0.23.x` line). On a real terminal thoth sets the window/tab title to `thoth - <model>` via OSC-0
(`ESC ] 0 ; … BEL`, `emit_raw` to fd1 like `/copy`'s OSC-52), at interactive startup (`main.cyr`, after the
one-shot short-circuit) and on a `/model` switch (`cmd_model`). New `_term_title_build` (pure) /
`term_title_set` (`src/commands.cyr`); gated `ui_tier() == PT_PLAIN → no-op`, so piped/one-shot/CI stays
byte-identical (verified zero escapes on the plain floor). **Security**: the model name is filtered to
printable bytes (C0 `< 0x20` incl. ESC/BEL + DEL `0x7f` stripped) so a crafted `/model` arg or
`[hoosh].model` value can't inject a terminal escape into the title — a pre-cut single-agent review CAUGHT
that the verbatim append lacked the encoding safety `/copy` gets from base64 (fixed + tested before the cut).
**Verified**: 1087 assertions (+2, `_term_title_build`: model in the title + control-byte stripping) + LIVE
in the real rich TUI via a PTY (title = `thoth - claude-opus-4-8`) and a piped run emitting NO OSC escape.
Pin **6.4.29**. NEXT polish candidates: file-tree git badges (fiddly tree-row render), `/reload` (config
hot-reload semantics), transcript export `/save`, model-picker palette, BEL/elapsed turn feedback. See
CHANGELOG/roadmap.

**0.22.2** — **persona blends + shadow**, 2026-07-08. Completes the `0.22.x` active-persona core with two
avatara-native synthesized-persona verbs, still pure consumption. `/persona shadow [name]`
(`persona_shadow`, `src/session.cyr`; `_cmd_persona_shadow`, `src/commands.cyr`): avatara's `shadow()`
inverts the traits + emits its own name/desc/soul/spirit ("Shadow of X" / "Shadow aspect …") → a usable
persona, `persona_set` next turn. `/persona blend <name>[:weight] …` (`persona_blend`; `_cmd_persona_blend`):
a weighted blend via avatara `compose()` — the parser copies each space-delimited token into a reused
256-byte scratch, splits on `:` into name + optional integer weight (`atoi`, clamped 1..99, made f64 by
repeated `f64_add` since there is no int→f64 builtin), `find_and_validate`s each (unknown aborts with an
honest refusal), `weighted_new`s into a vec, needs ≥2, `compose` (Result). compose sets soul/spirit/name from
the DOMINANT (highest-weight, first on ties) component + a `"A + B"` composite name + merged tradition, so a
blend is a usable persona whose voice is the dominant's — surfaced honestly ("the dominant leads the voice").
**Bright line held**: composition + shadow are avatara verbs; thoth authors NO persona prose (blend = the
dominant's, shadow = avatara's shadow text), only parses + builds the weighted vec + surfaces. `persona_role`
name-conditional still applies (blend → "Composite archetype", shadow → "Shadow aspect …"). No dep bump
needed — the vendored avatara `compose` (2.7.1, byte-identical to the 2.7.2 dist) already emits the prose
(an earlier grep miss suggested otherwise; verified in-file). **Verified**: 1085 assertions (+7,
`test_persona_switch` — `persona_shadow(0)`: "Shadow of" name + soul present + role≠Librarian;
`persona_blend` Athena:2+Odin: soul present + composite name leads with Athena) + LIVE in the real binary
(`/persona shadow` → Shadow of Thoth; `/persona blend Athena:2 Odin` → "Athena + Odin", tradition "Greek +
Norse", `/dry` shows Athena's voice; unknown name + single-archetype → honest refusals). A 3-lens adversarial
review returned CLEAN (blend parser bounds, shadow/blend semantics + bright line, dispatch/floor — all clean).
Pin **6.4.29**. NEXT: `0.22.3` role modality (long-term; aspect-registry is an avatara feature to request),
or a polish-backlog sweep. See CHANGELOG/roadmap.

**0.22.1** — **`/personas` discovery**, 2026-07-08. The browse/display companion to 0.22.0's `/persona`
switch — DISCOVERY + display only, no new personality logic, READ-ONLY. `cmd_personas` (`src/commands.cyr`):
no arg prints the ACTIVE persona card (name · tradition · desc + a word-bounded soul excerpt via new
`_persona_excerpt`) then lists the avatara traditions with per-tradition archetype counts
(`vec_len(by_tradition(t))`); an arg browses that tradition (`by_tradition`), listing its archetypes with
their desc and marking the active one `●` (`streq(prof_name(p), persona_name())`); unknown tradition → honest
refusal. All data read from avatara (`all_traditions`/`by_tradition`/`prof_*`) — thoth only surfaces it. The
`/persona` unknown-name refusal now hints `/personas`; `/help` line added. `_persona_excerpt` caps at ~90
bytes and backs up to a word boundary (protects multi-byte glyphs since the cut lands on an ASCII space; the
no-space path is dead — all 374 avatara souls are spaced prose, confirmed by the review). **Verified**: 1078
assertions (+2, `_persona_excerpt`: no-space 100-char → 90, short → its length) + LIVE in the real binary
(`/personas` card + traditions with counts; `/personas Egyptian` lists Thoth ●/Isis/Anubis/…; unknown
tradition + `/persona` bad name → honest refusals). A 3-lens adversarial review returned CLEAN (two nits —
the dead no-space UTF-8 path + a null-soul deref already trusted by the per-turn `persona_system_prompt` path
— both VERIFIED as refuted; the excerpt comment was tightened for honesty). Pin **6.4.29**. NEXT: `0.22.2`
blends + shadow (`compose`/`shadow`, stretch), then `0.22.3` role modality (long-term). See CHANGELOG/roadmap.

**0.22.0** — **the active persona: mid-session `/persona` switch** + the Cyrius **6.4.29** refresh,
2026-07-08. The signature move's twin — thoth switches the backing MODEL mid-session (`/model`); now it
switches the active PERSONALITY mid-session via avatara. Opens the `0.22.x` line. `/persona [name]`
(`cmd_persona`, `src/commands.cyr`, mirrors `cmd_model`): no arg shows the active archetype (name / role /
tradition); an arg resolves through avatara's `find_and_validate` (Result — unknown → honest refusal, active
unchanged) and swaps it, effective NEXT turn. `src/session.cyr`: `persona_set(p)` swaps `_persona_profile` +
marks `_persona_sys_dirty`; `persona_system_prompt` rebuilds IN PLACE when dirty (buffer alloc'd once — NO
per-switch leak; `PERSONA_SYS_CAP` 1 KiB → 2 KiB for arbitrary archetypes, `_append_cstr_cap`-clamped);
`persona_switch(name)` is `is_err_result`-guarded before `result_unwrap`. **Identity split enforced:**
`persona_role()` is name-conditional — default Thoth → "the Librarian" (thoth's framing), a switched persona
→ its avatara `desc` (never thoth-authored per-archetype prose); `persona_tagline()` (the THOTH backronym) is
the APP's fixed naming, constant across switches. **Startup default** `[persona].name` (`config_persona`,
`src/config.cyr`): absent → `egyptian_thoth` (byte-identical floor); unknown → falls back to default, always
surfaced honestly (never faked). Surfaced in the **status bar** (after the version) + **`/state`** (name ·
role · tradition) + `/help`; `thoth.cyml.example` documents `[persona]`. **Bright line held**: avatara owns
personality content + every verb (lookup/validate/compose); thoth only selects + injects + surfaces.
**Verified**: 1076 assertions (+14, `test_persona_switch` — default Thoth/Librarian/Egyptian; switch to
Athena: name, role≠Librarian, role==desc, system prompt rebuilt (snapshot differs, no longer the Thoth
voice); unknown → refusal + unchanged; tagline constant; restore) + the M5 `test_persona` (default) still
passes + LIVE in the real binary (`/persona` show/switch, `/state` row, `/dry` shows the rebuilt Athena
system prompt with thoth's operating clause, unknown → honest refusal). A 3-lens adversarial review found no
code defects. Toolchain: pin `6.4.26 → 6.4.29`, active switched to 6.4.29 (env had drifted to 6.4.30 —
repointed to match the pin); `cyrius lib sync` moved only `lib/sakshi.cyr` + `lib/sigil.cyr`. Pin **6.4.29**.
NEXT: `0.22.1` `/personas` discovery (list traditions / browse / active card), then `0.22.2` blends+shadow.
See CHANGELOG/roadmap.

**0.21.1** — **tree-fed `@` Tab completion**, 2026-07-08. The TUI-input layer on the 0.21.0 expansion core:
pressing `Tab` on a `@<prefix>` in the composer completes the path from the file tree; with the cursor NOT
on a `@`-token, `Tab` keeps its prior composer↔tree focus-toggle. New `ftree_complete` (`src/ftree.cyr`)
splits the prefix at the last `/` and lists that directory via the tree's own `dir_list` — so completion
works at ANY depth without the dir being expanded in the pane, riding the tree's existing ungated read
posture (relative listing = the process CWD, matching `@mention`'s relative resolution). Unique match →
full completion (+ trailing `/` for a dir, so the next `Tab` descends); multiple → longest common prefix.
`mention_prefix_at` (`src/mention.cyr`) finds the `@`-token at the cursor, SHARING the 0.21.0 `@`/boundary/
path-char rules so Tab completes exactly what a submitted `@mention` expands. `led_insert_cstr` + the
`_tui_at_complete` glue insert the suffix via the tested `led_feed` path; the `KEY_TAB` handler tries
completion first (FOCUS_COMPOSER, `@`-token present → consume Tab + repaint via `tui_after_edit`) and falls
through to the toggle otherwise. **A 3-lens adversarial review caught a real mid-token bug** (fixed pre-cut):
`mention_prefix_at` scanned only backward, so a cursor mid-token (`@VERbar`, cursor after `VER`) would splice
the completion into the middle (`@VERSIONbar`); now it requires the cursor at the END of the token (the char
AT the cursor must be a non-path-char), else Tab falls through — regression-tested. The other two lenses
(completion bounds, KEY_TAB floor-identity) were clean. **Verified**: 1062 assertions (+25, `test_tab_complete`
— `mention_prefix_at` boundary/email/empty/start/mid-token/end + `ftree_complete` unique-file/unique-dir-
`/`/subdir/ambiguous-LCP/no-match + `led_insert_cstr`) + LIVE in the real rich TUI by driving it through a
PTY (`@VER` + `Tab` → `@VERSION`; happy path intact after the guard). TUI-only — line/one-shot/PLAIN floor
untouched. Pin **6.4.26**. NEXT: the `0.22.x` active-persona line (mid-session avatara switch), or further
`0.21.x` composer slices (e.g. the model-picker palette). See CHANGELOG/roadmap.

**0.21.0** — **`@file` mentions**, 2026-07-08. Opens the `0.21.x` composer-intelligence line: typing
`@path` in a message injects that file's content into the prompt as explicit, delimited context. New pure
module `src/mention.cyr` (`mention_expand`/`mention_count`, unit-tested) rides the `/read` machinery
(`file_exists` + `file_read_all` into a bounded reused buffer) — NO new read path, NO new security surface
(the content comes from a path the USER typed in their own message; the same trust class as pasting it). A
`@` is a mention only at start-of-text or after whitespace (so `foo@bar` emails / `@handle` prose are never
mangled); path charset `[A-Za-z0-9/._-~]`; a trailing punctuation char is trimmed when the full token
doesn't resolve; a `@token` that doesn't resolve to a readable file stays LITERAL. Multiple mentions
compose, duplicates inject once, directories/empty/unreadable stay literal (`file_read_all` returns <=0 — a
dir opens O_RDONLY then reads EISDIR→0). Format: prose unchanged, then `\n\n--- @<path> ---\n<content>`
blocks appended. Bounds: 16 KiB/file (truncated + marker), 32 KiB total (== `HOOSH_REQ_CAP/8`, hoosh's
per-turn content budget so the context isn't evicted), 16 files; reused module-global buffers (no per-call
heap on the turn hot path). Byte-identical passthrough (returns the ORIGINAL pointer) when nothing resolves,
so ordinary prompts are unchanged. Wired into `cmd_task` (echo the original line, send the expanded prompt,
faint `(+N file(s) attached)` note) and `cmd_dry` (same expansion in the preview; side-effect-free +
network-free); one-shot rides `cmd_task`. **Verified**: 1037 assertions (+16, `test_mention` — passthrough/
email-boundary/single/multi/dedup/nonexistent/trailing-punct/directory) + LIVE in the real binary (`/dry
summarize @VERSION` → body carries `summarize @VERSION\n\n--- @VERSION ---\n0.20.4\n`; `cmd_task` prints the
`(+1)` note counting only the resolved mention). A 3-lens adversarial review (buffer-safety / scan-
correctness / floor-identity, genuine engagement — 19/11/28 tool calls) returned ZERO findings. Residual
(documented): the ASCII path charset means a non-ASCII filename isn't matched (a first-cut limit). NEXT in
the line: `0.21.1` tree-fed **Tab completion** for `@` in the composer (TUI-input layer on this core). Pin
**6.4.26** (unchanged). See CHANGELOG/roadmap.

**0.20.4** — **the model's `shell` tool works on Windows** + the Cyrius **6.4.26** refresh that unblocked
it, 2026-07-08. This is the deferred `0.20.2` (Windows timed capture) item, landing OUT OF ORDER after
`0.20.3`: 6.4.26 shipped `TerminateProcess` (syscall `0xF01D`) — the kill primitive the earlier Windows PE
surface lacked, added upstream in direct response to thoth's filed issue
`2026-07-08-windows-pe-surface-no-terminateprocess` (now RESOLVED). Windows `exec_shell_capture`
(`src/exec.cyr`, the `#ifdef CYRIUS_TARGET_WIN` block) replaces the announce-but-unsupported stub and
`shell_supported()`→1. It mirrors the POSIX **temp-file** design (a FILE, never a pipe): a design workflow +
empirical cass testing PROVED the pipe path deadlocks — a >~4 KiB command fills the anonymous-pipe buffer,
blocks (the PE surface has no `PeekNamedPipe`/overlapped-I/O/threads to drain concurrently), and gets
mis-killed as a FALSE timeout; a file has no writer backpressure so the child always runs to genuine
completion (clean over-cap truncation) or a genuine hang. Opens a CWD-relative `thoth_sh_<pid>_<n>.tmp`
(`CreateFileW`), `SetHandleInformation`-inheritable, stdout+stderr→file via vendored `_win_create_process`,
deadline+`TerminateProcess`+reap via vendored `_win_wait_timeout`, reads back via `file_read_all`,
best-effort `DeleteFileW`. Runs `cmd /s /c "<cmdline>"` with the env INHERITED (PATH reaches cmd.exe);
status maps killed→`-2`/timed=1, else the true unsigned 32-bit exit code (`ec & 0xFFFFFFFF`), fail-closed
`{-1,0}` on open/sethandle/spawn failure. **Verified end-to-end on `cass` (Windows 11 x86_64)** with
byte-identical code: echo capture, merged stdout+stderr (`out\r\nerr\r\n`), over-cap clean-truncate
(code=0, NOT a false timeout — the pipe path fails this), timeout→code=-2/timed=1, partial-output-on-kill
(`start` preserved), exit-code passthrough (3), empty output — all correct. **Residuals (documented, never
faked):** no process-group kill (Job Objects not wired) → a timeout that spawns a surviving grandchild lets
it outlive the shell AND hold the inherited temp-file handle so `DeleteFileW` fails and that one temp file
lingers in the CWD until the grandchild exits (parallels pre-0.20.1 POSIX single-child; confirmed on cass:
exactly the 2 grandchild-`ping` timeout cases leaked, all others cleaned up); temp in CWD not /tmp (no
`GetTempPathW`; read-only CWD → fail-closed); no `O_EXCL`/`O_NOFOLLOW`; unsigned-32-bit exit code shape;
stdin not NUL-redirected (a stdin reader blocks to an honest `-2`). A pre-cut adversarial-review workflow
(3 lenses → verify) caught TWO real defects, both fixed + re-verified on cass: (1) MUST-FIX — an uncapped
`_w_append_cstr(cmdline)` into the fixed 16 KiB wbuf would OVERRUN the bump heap on a model command >8179
bytes (the JSON blob cap is 16384, so the command value alone can reach it); now length-checked and REJECTED
fail-closed (`{-1,0}`, no spawn), verified by a 9000-byte over-long case returning `code=-1 n=0` with no
crash; (2) the wbuf was `alloc`'d fresh every call → a 16 KiB per-call leak on the no-free bump heap; now a
reused module global `_shell_wbuf` (mirrors `_shell_tmp_buf`), verified by a post-guard re-capture. The full
thoth `--win` binary stays
IOCP-gated on `lib/async.cyr` (async/epoll→IOCP, a separate cyrius item); this shell capture is verified via
a minimal exec-only `--win` harness and ships with the Windows binary the moment that gate lifts.
Toolchain: pin `6.4.23 → 6.4.26`, active toolchain switched to 6.4.26 (`.27` is in flight); `cyrius lib
sync` moved only `lib/process_win.cyr` (+`_win_terminate`/`_win_wait_timeout`), `lib/math.cyr`, `lib/io.cyr`.
Linux lanes green, 1021 assertions (Windows path `#ifdef`-gated, not host-testable). Pin **6.4.26**. Next:
the `0.21.x` composer line (`@file` mentions), or the full `--win` lane when the IOCP transport lands.

**0.20.3** — **array-value shell deny/allow config**, 2026-07-08. The `[shell]` deny/allow glob lists —
modelled as `[shell.deny]`/`[shell.allow]` SECTIONS of `label = "glob"` pairs only because bayan (≤ 1.0.4)
had no TOML array-VALUE getter — now accept the natural array form `[shell] deny = ["…"] / allow = ["…"]`,
read via `bayan_toml_get_array` (bayan **1.1.0**, already vendored). New `_shell_glob_array_load` (iterates
the element-Str vec) + `_shell_glob_key_load` (the present/absent decision). **Precedence**: the array key
WINS when present — an explicit empty `deny = []` means zero patterns and does NOT fall through; the
`label = "glob"` section form is a documented back-compat alias, loaded only when the array key is absent.
**Footgun closed** (self-caught in review): a bare scalar string (`deny = "*rm -rf*"`, brackets forgotten)
would have array-parsed to an empty vec → a silently-empty deny-list; instead a scalar is accepted leniently
as ONE glob (`bayan_toml_is_array` distinguishes absent/array/scalar). `thoth.cyml.example` updated (array
canonical, section back-compat) + its stale "timeout kills the /bin/sh not a backgrounded child" note
corrected (0.20.1's process-group kill fixed that). Every edge test-covered (array, empty-array, scalar,
both-present-array-wins, absent-fallback). 1021 assertions (+11, `test_shell`). Pin **6.4.23** (local cycc
has drifted to 6.4.24; build/tests clean — a pin bump earns its own refresh slice, not folded here).

> **`0.20.2` (Windows timed capture) is deferred out-of-order — blocked on a Cyrius gap.** It needs a
> `TerminateProcess` primitive to kill a timed-out child, but the Cyrius Windows PE syscall surface exposes
> spawn/wait/exit-code/pipe (`CreateProcessW`/`WaitForSingleObject`/`GetExitCodeProcess`/`CreatePipe`/
> `SetHandleInformation`, 0xF001–0xF005) and NO terminate — so a hung child can be detected but not killed,
> and shipping it would leak (the safety regression 0.20.1 fixed on Linux). Filed upstream as cyrius issue
> `2026-07-08-windows-pe-surface-no-terminateprocess`. The minimal-`--win`-build → scp → run-on-`cass`
> (Windows 11 x86_64) test pipeline is proven (a `winhello.exe` cross-built here ran on cass), so 0.20.2
> lands + verifies the moment that reroute ships. Next: `0.20.2` when unblocked, else the 0.21.x composer line.

**0.20.1** — **process-group kill on shell timeout** + a Cyrius **6.4.23** refresh, 2026-07-08. A timed-out
shell command `SIGKILL`ed only the direct `/bin/sh`, so a backgrounded grandchild (`daemon &`) survived and
leaked. Fix (`src/exec.cyr`, the Linux `exec_shell_capture`): the child `setpgid(0,0)`s into its OWN process
group before `execve` (the parent also `setpgid(pid,pid)`s to close the fork race), and on timeout the
reaper `kill(-pgid, SIGKILL)`s the whole group — the shell AND any backgrounded grandchild — then
`kill(pid, SIGKILL)`s the child directly (belt-and-suspenders so the blocking reap never hangs even if
`setpgid` didn't take). **Safe**: an independent code-trace confirmed `kill(-pid)` can NEVER signal thoth's
own group (a pgid always equals its leader's pid; a child-pid group is the child's isolated group or
non-existent → ESRCH — never thoth); grandchildren reparent to init, thoth reaps only its direct child (no
zombie leak). Declared **x86_64-only** — `syscall(109)` is setpgid on x86_64 but rseq on aarch64, matching
the path's pre-existing raw `poll(#7)`; the aarch64 lane ships size-gapped, and the comment documents the
exact arch-conditional fix (setpgid #154 + ppoll) if it is ever un-gapped. Proven end-to-end: a marker-based
test confirms a backgrounded grandchild that would `touch` a marker after 1s is ABSENT after a 300ms-timeout
kill + a wait past 1s (the group-kill reached it), and the backgrounding parent still times out promptly (no
hang). Toolchain: pin `6.4.21 → 6.4.23` (`cyrius lib sync`, only `lib/syscalls_x86_64_agnos.cyr` moved — a
new `SYS_READLINK` for AGNOS, unused here; drift cleared). All lanes behave. 1010 assertions (+2,
`test_shell` grandchild-kill). Pin **6.4.23**. Next: `0.20.2` Windows timed capture.

**0.20.0** — **`agent_enabled()` relax — the shell tool works standalone** (opens the 0.20.x
shell/agent-hardening line), 2026-07-08. The agentic tool-calling loop needed daimon (an MCP host) wired, so
the thoth-NATIVE `shell` tool (which needs no daimon) was unusable without one. `agent_enabled()`
(`src/agent.cyr`) now: `[hoosh].tools` required (master switch), then daimon-wired → on (unchanged), OR
`[shell].enabled && shell_supported()` → on (NEW). Tool source = daimon OR shell. The **advertisement** only
fetches daimon's registry when the seam is present; standalone builds the tools array from just the local
tools (`agent_format_tools(buf, 0)` → `add_memory` → `add_shell` = a valid `[…shell…]` array, no network).
Two **null-deref CRASH GUARDS** (design + diff review catch): `_agent_run_calls` returns serial FIRST when
daimon is absent, and the serial path has an `elif SEAM_DAIMON==ABSENT` refusing a non-local tool BEFORE the
`daimon_invoke` branch — because the parallel executor and `daimon_invoke` both `strlen()` the daimon URL via
`_daimon_call_endpoint`, which is NULL when daimon is absent, so a round of hallucinated non-local tools
(default `[hoosh].parallel=on`) would segfault. `/state` (shell + agent rows) + `/tools` reworded — the agent
row shows "shell tool, standalone", `/tools` lists the native shell/memory tools when daimon is absent but
the loop is on. **Security unchanged**: shell stays t-ron-gated (`thoth_shell`) + deny/allow glob-filtered +
local-only, never forwarded; no new tool advertised, none ungated; degrades closed. **Scope**: keyed only on
shell — memory-only standalone intentionally stays off (0.20.0 targets the POSIX shell). **Floor**: a
daimon-wired or shell-off session is byte-identical (every change is gated on daimon-absent or adds a clause
that leaves the daimon path unchanged); verified live (this machine has daimon wired → `/state`/`/tools`
unchanged). Design review found the crash-guard framing + 3 display/test nits (all folded); diff review
raised zero. 1008 assertions (+10, `test_agent` — the full truth table by poking `_cfg_*` globals + a
network-free advertise round-trip). Pin **6.4.21** (local `cycc` has since advanced to 6.4.23 — residual
drift, a future refresh clears it). Live-verify: `[hoosh].tools=true` + `[shell].enabled=true` + NO
`[daimon].url` → a task needing a command runs the shell tool agentically. Next: `0.20.1` process-group kill
on timeout.

**0.19.3** — **live spine-health** (closes the 0.19.x line), 2026-07-08. A cached hoosh reachability driven
by TRAFFIC OUTCOMES (no background timer / idle probe), shown as a dot in the status bar. `src/hoosh.cyr`:
`_hoosh_health` tri-state (UNKNOWN/UP/DOWN) + `hoosh_health`/`_mark_up`/`_mark_down`/`hoosh_health_note(rc)`
(`rc<0` connection failure → DOWN; any answered request, even a non-2xx → UP) + `hoosh_health_probe()` (a
silent `hoosh_reachable` GET → UP/DOWN). Two chokepoints: `hoosh_send` calls `hoosh_health_note(rc)`;
`agent_turn` marks each round by kind (2 transport → down, 4 Esc-interrupt → neutral, everything answered →
up — so a multi-round loop ends on the last round's true outcome). The **status bar** (`tui_draw_status`)
shows a **green ● up / red ● down / faint ○ unknown** dot next to the model, only when a gateway is
configured; the startup greeting seeds the cache via the same probe (READY/unreachable/absent unchanged).
**Ctrl-R** (`KEY_REPROBE`) re-runs the silent probe (while OUT_FD1 — it emits nothing), notes `hoosh:
reachable / unreachable / absent` to the feed, and refreshes the dot — no idle poll. TUI-only display; the
health STATE is set in the REPL too but only shown in the TUI (no REPL floor change). Verified by an
adversarial code-trace: turn-outcome coverage (both chokepoints, non-2xx=UP, Esc=neutral, non-turn commands
don't mark), the Ctrl-R out_mode balance, the width-1 dot glyphs, and no UNKNOWN leak post-startup — all
clean. 998 assertions (+5, `test_hoosh_health` state machine). Pin **6.4.21**. Live-verify (`--tier=rich`):
stop the gateway, run a task → the dot goes red; Ctrl-R re-probes. **This completes the 0.19.x
session-visibility line** (context meter → turn telemetry → `/git` diff → spine-health); next is `0.20.x`
(shell/agent hardening).

**0.19.2** — **`/git <path>` per-file diff**, 2026-07-08. The 0.13.x deferred follow-up: `/git` showed
branch + changed files; now `/git <path>` renders that file's diff (HEAD blob vs working tree), colored +
syntax-highlighted. sit computes the diff (`sit_diff_path` → a vec of annotated line-ops `{kind, line-tuple,
old_no, new_no}`); thoth colors it. New `diff_render_ann(path, ops)` (`src/diff.cyr`) prints a blue path
header + a `+A -B` count line, then reuses `_diff_emit_line` (line-number gutter + colored +/-/space gutter +
`detect_language` body highlight — the SAME renderer `/read` + write diffs use) over each op (del→red/`-`/
`ann_old`, add→green/`+`/`_sit_ann_new`, keep→faint/` `). Full annotated file (changes in context), matching
thoth's other diff views. `cmd_git(line)` now takes an arg: a path → the diff; `sit_diff_path`==0 (unchanged
/ untracked-and-absent / LCS-too-large) → honest "no changes vs HEAD", never a blank or fake diff; bare
`/git` is the unchanged branch + status. Reads only the documented sit surface + line-tuple accessors; no
free (arena model, like `sit_repo_status`); PT_PLAIN degrades to verbatim. Verified LIVE (`/git
src/commands.cyr` → `+17 -3` with a rendered body) + an adversarial code-trace (offsets, count/render
consistency, ops==0/empty/all-add/all-del, non-NUL blob safety, floor — all clean). 993 assertions (+7,
`test_git_diff` — a hand-built ann-ops vec renders header/count/body). Pin **6.4.21**. Next: `0.19.3` live
spine-health.

**0.19.1** — **live agentic-turn telemetry**, 2026-07-08. The `tool-call:`/`result:` feed lines now show
**verdict · elapsed · result-bytes** in a faint sub-line (`    · ok · 142ms · 87B`; just the verdict for a
denied / no-name call), and the spinner reads `running <tool>…` while a call blocks (`running 3 tools…` for
a parallel batch) instead of the generic `working…`. The **roundlog** (thoth's per-round tool ledger) now
records `ms` (wall-time) + `bytes` (result size) per call — `_rl_call_sz` 16→32, `roundlog_add_call(name,
kind, ok, ms, bytes)`, new `roundlog_call_ms`/`_bytes` — so `/audit` (`roundlog_report`) shows them too.
`src/agent.cyr`: the **serial** path times gate+invoke (`clock_now_ms`) and labels the spinner per tool; the
**parallel** path times each call inside its worker (a new `elapsed` field at ctx+48, `PAR_CTX_SZ` 48→56 —
each worker owns its slot, writes before join, read serially in phase 3) and labels the batch. `_agent_call_telem`
emits the sub-line through the same sink as the tool-call lines (feed at OUT_RING, terminal at OUT_FD1;
floor-verbatim at PT_PLAIN; NOT routed through the reply's inline-markdown pass, so no styling collision).
`src/tui.cyr`: `_spin_label` + `spin_label_set`/`_clear`; `spin_paint` shows `running <label>…`; `spin_begin`
resets the label per turn so it never leaks into hoosh-streaming ticks; no-op off the TUI. No new producer,
no spine surface. Diff review raised zero. 986 assertions (+2, `test_roundlog` ms/bytes round-trip). Pin
**6.4.21**. Live-verify (`--tier=rich`): a task that calls tools shows the telemetry sub-lines + the spinner
naming each tool. Next: `0.19.2` `/git` per-file diff.

**0.19.0** — **context-budget meter** (opens the 0.19.x session-visibility line) + a Cyrius **6.4.21**
refresh, 2026-07-08. hoosh keeps only the newest tail of the conversation whose framed bytes fit
`HOOSH_REQ_CAP/8` (**exactly 32768 = 32 KiB**); older turns are silently evicted from each request
(`_hoosh_history_start`). Now that pressure is VISIBLE: the status bar shows `ctx <n>K/32K` after `turns`
(the number RED once eviction begins), and `/state`'s `context :` row shows `<n>K / 32K budget` + `N oldest
evicted`. Pure producers in `src/hoosh.cyr` — `hoosh_ctx_budget()` (= `HOOSH_REQ_CAP/8`), `hoosh_ctx_bytes()`
(Σ `strlen(content)+16` over all messages), `hoosh_ctx_evicted()` (= `_hoosh_history_start`) — use the
**identical** sizing to `_hoosh_history_start`, so the meter IS the eviction decision, not an estimate
(history content is a C string, the same invariant the eviction + request serialization already assume).
Omit-until-present (ADR-0010): the segment/row is dropped when single-turn (`[hoosh].history=false`) or
empty. No new producer, no spine surface. Bundled the toolchain refresh (`cyrius.cyml` `6.4.20 → 6.4.21` +
`cyrius lib sync` — only `lib/tls_native_hs13.cyr` moved, a TLS-1.3 handshake update). All lanes behave. 984
assertions (+10, `test_ctx_meter` — the budget, byte accounting, and the eviction boundary via two ~20 KiB
messages). Pin **6.4.21** (the local `cycc` wrapper has since advanced to **6.4.22** — a residual drift, a
future refresh clears it). Live-verify (`--tier=rich`): hold a long conversation and watch `ctx` climb
toward `32K`, then go red as old turns evict. Next: `0.19.1` live agentic-turn telemetry.

**0.18.8** — **inline markdown in the reply feed** (closes the 0.18.x line), 2026-07-08. Beyond the fenced
code that 0.15.1 highlights, prose lines now get **headings / bold / inline-code / list markers** styled. A
new inline pass in `mdhl` (the prose branch of `_mdhl_line_done` now calls `_mdhl_inline_line`, was
`_mdhl_put_line`) styles each COMPLETE prose line: ATX heading (`#`..`######`+space) → whole line
`ROLE_ACCENT`; blockquote (`>`) → `ROLE_MUTED`; list marker (`-`/`*`/`+`+space or `N.`/`N)`+space) → the
bullet `ROLE_ACCENT`; inline code `` `…` `` → `ROLE_BLUE` (highest precedence, interior not re-scanned);
bold `**…**` → raw `\x1b[1m`. Each span WRAPS its bytes (open + verbatim + `ui_reset()`) — never drops or
reorders a byte, so **`strip_sgr(output) == the raw line`** (0.15.1 discipline, property-tested). Colors are
role MARKERS at OUT_RING (via `_feed_pack`), so **`/theme` recolors** inline markdown, and the reset-marker
close keeps `feed_clip_seg`'s 64B soft-wrap carry BOUNDED (inline spans can't overflow it). The scanner is
**linear** (a failed forward close-scan latches that delimiter off). **Display-only**: the raw reply in
`_hoosh_acc` → history/`--json`/`-o` is untouched; PT_PLAIN + ASCII are byte-identical. **Composes with
search**: `fsearch_render` gained a `bold_open` flag (set on a stored `\x1b[1m`, cleared by a reset,
re-asserted after a match-OFF) so a search match inside a `**bold**` span no longer un-bolds the tail —
headings/inline-code already composed via the role-marker `active_role` restore (the search-inside-bold gap
+ an O(n²) scan were pre-cut design-review catches; the diff review raised zero). Not yet styled (declared):
single-`*`/`_` italic, links, strikethrough, nesting, and inline constructs inside a heading / on a
>2048-byte continuation line. 974 assertions (+19, `test_mdhl_inline`). Pin **6.4.20**. Live-verify
(`--tier=rich`): a reply with a heading + bold + list + inline code renders styled; `/theme` recolors it;
Ctrl-F highlights a word inside a heading. **This completes the 0.18.x re-renderable-feed line** (keystone →
theme recolor → live card → search → occurrence-granular → confirm-prompt → glyph-width → inline markdown);
next is `0.19.x` (session visibility).

**0.18.7** — **glyph-width table** (closes the 0.11.3 undercount), 2026-07-08. Every glyph was counted as
ONE terminal column, so a CJK/emoji line was reckoned half its true width and overflowed the feed column.
New `feed_glyph_cols(src, i, gl)` (`src/feed.cyr`) decodes the UTF-8 codepoint and returns its display
width — **0** for combining/zero-width marks (combining ranges, ZW joiners/space, variation selectors, BOM),
**2** for East-Asian Wide/Fullwidth glyphs + emoji (Hangul, CJK Unified + Ext A/B–F, Kana, Yi, fullwidth
forms, 0x2600–0x27BF dingbats/symbols, 0x1F000–0x1FAFF planes), else **1**. All three feed col-counters —
`feed_visible_cols` (cached `_feed_vis` at seal), `feed_clip` (tree column), `feed_clip_seg` (feed painter)
— now add the glyph's width, so `feed_rows_for = ceil(display-cols / width)` stays consistent and a wide
line wraps into the right number of rows. `feed_clip` refuses a straddling wide glyph (no bleed into the
feed pane to its right) and latches strict left-to-right truncation on the first refusal (diff-review fold).
**Declared residuals** (honest limits): a wide glyph straddling a *soft-wrap* boundary clips 1 col at the
(rightmost) feed edge — the terminal clips it, no pane corruption, **no glyph lost or duplicated** (the
soft-wrap exactly-once invariant holds, verified); EAW-Ambiguous 0x2600–0x27BF treated wide; ZWJ emoji
sequences overcount; a few scattered BMP emoji (e.g. U+2B50 ⭐) still count 1. ASCII output is
**byte-identical** (width 1) — the floor is untouched. 955 assertions (+14, `test_glyph_width`). Pin
**6.4.20**. Live-verify on a real tty (`--tier=rich`): paste a CJK or emoji-heavy reply and confirm it wraps
at the right column instead of spilling. Next in the 0.18.x line: `0.18.8` inline markdown.

**0.18.6** — **confirm-prompt return** (live-test follow-up), 2026-07-08. When a t-ron gate confirm fires
during an agentic turn, `confirm` (src/gate.cyr) brackets to the live screen via `tui_confirm_begin`/`_end`
(so the `[y/N]` prompt + cooked echo are visible, not buried in the feed ring). But `tui_confirm_end` only
resumed capture + the spinner — it never repainted the composer, so the `…authorize …? [y/N] y` line stayed
stuck on the composer row until the whole response finished. Fix: `tui_confirm_end` now calls
`tui_repaint_body()` as its FIRST step — while out_mode is still OUT_FD1 (from `tui_confirm_begin`), so the
chrome paints to the SCREEN, not the ring — clearing the confirm prompt + echo and restoring the `{(o>`
composer immediately; then it resumes OUT_RING + the spinner. An independent code-trace verified the
out_mode balance (guaranteed OUT_FD1 at entry → no ring corruption), that `tui_repaint_body` is read-only
from the ring (safe mid-dispatch), that the confirm text is never sealed into the feed, and that search
(`_fsearch_active`) is guaranteed 0 during a turn. TUI-only; the REPL/piped confirm path never calls these
hooks (byte-identical floor). 941 assertions (unchanged — the confirm/TUI path is live-verified, not
unit-tested). Pin **6.4.20**.

**0.18.5** — **feed search: occurrence-granular** (live-test follow-up to 0.18.4), 2026-07-08. A search
that matched twice on one line reported `2/2` (two *lines*) while three spans highlighted — the count and
n/N were LINE-granular. Now match state is per-OCCURRENCE: `_fsearch_mline[k]`/`_fsearch_moff[k]` hold the
line **and** start offset of every non-overlapping hit, so the `i/n` count and n/N step every hit and the
render marks the **current** occurrence (by `cur_off`, its byte offset) reverse+underline while the rest stay
reverse (`fsearch_render` now takes `cur_off`, not a whole-line flag; `feed_repaint` passes `coff =
(li==fsearch_cur_line()) ? fsearch_cur_off() : -1`). `_fsearch_add_line` walks a line identically to the
render, so recorded offsets coincide with render match-starts (one occurrence current, never mis-marked).
The per-occurrence cap (`FSEARCH_MATCH_CAP` = 8192) is **announced** — a broad query over a full ring shows
`i/n+` via `fsearch_saturated`, never a faked total (diff-review catch, per the "announce, never fake"
principle). Feed-search-only; floor unchanged. 941 assertions (+5). Pin **6.4.20**.

**0.18.4** — **feed search** (Ctrl-F / `/find` over the scrollback), 2026-07-08. A new PURE engine
(`src/fsearch.cyr`) matches the query against the VISIBLE text of every feed-ring line — case-insensitive
ASCII, transparent to the 0.18.0 role markers + any interleaved escapes, glyph-aligned (a multi-byte UTF-8
query compares byte-exact, a declared limitation) — and a TUI MODAL highlights the matches inline and
scrolls the current one into view. **Net-floor-safe by construction**: the highlighter (`fsearch_render`)
injects reverse-video SGR into a per-line temp buffer that is handed to the **UNCHANGED** `feed_clip_seg`
(the injected escapes are just more zero-width escapes it already carries across a soft-wrap) — so the
delicate 0.11.3 soft-wrap primitive is untouched. Two-phase modal: **Ctrl-F** opens incremental search
(type → highlight + jump to the newest match), **Enter** commits to a nav phase where **n / N** (and ↓/↑,
Enter) jump newer/older; **Ctrl-C** closes. `/find <text>` jumps straight into nav; outside the TUI it
announces honestly (no re-renderable feed) and does nothing. The current match draws reverse+underline,
others reverse (via `ui_match_on`); scroll-to-match uses the new `feed_phys_before` (soft-wrap physical-row
distance). Match-OFF is a **reset marker + active-role restore** (design review: a bare `ESC[27m` off would
overflow `feed_clip_seg`'s 64B wrap carry on a many-match wide line; the reset collapses it to O(1) and is
theme-correct), and an interior reset inside a match re-asserts the reverse. The pre-cut **design review**
caught + folded an EOF busy-spin hang (`_tui_search_key` tears the loop down on `KEY_EOF`), the carry
overflow, and cursor mis-parking on full repaints (`tui_park_cursor` gates on the modal → covers SIGWINCH /
`/theme` / `/find`-entry); the as-built **diff review** raised zero findings. 936 assertions (+26,
`test_fsearch` — incl. an interior-reset re-assert, a wrap-straddle carry re-flush, a bounded-carry
many-match case, and the PT_PLAIN floor). Pin **6.4.20**. Live-verify on a real tty (`--tier=rich`): Ctrl-F,
type, watch matches highlight, n/N to jump. Next in the 0.18.x line: `0.18.5` glyph-width, `0.18.6` inline
markdown.

**0.18.3** — **live-upgrading fenced-code card** (the 0.15.1 deferred "Option C"), 2026-07-07. A streamed
```` ```lang ```` block is no longer withheld until its closing fence: the interior lines now emit **live**
(unhighlighted) as they arrive, then at the closing fence — or on an interrupt / truncated completion — the
live rows are **dropped and re-emitted syntax-highlighted**, an in-place upgrade. Unlocked by 0.18.0's
re-renderable feed. TUI-only (`out_mode()==OUT_RING`, via `_mdhl_live()`); the **line REPL** (OUT_FD1) keeps
withhold-until-close (a terminal it can't rewind) and **PT_PLAIN** stays verbatim, so the floor is
**net-result-preserving / byte-identical**. New `src/feed.cyr` primitives: `feed_drop_last(n)` (remove the
last `n` sealed rows, clamped, slots reused) + `feed_drop_pending()` (discard an un-sealed partial), both
counter-only + dead off OUT_RING. New `src/mdhl.cyr` `_mdhl_block_close()` (drop live rows + re-emit
highlighted), wired into `_mdhl_line_done`'s fence-close branch and `mdhl_finish`; `_mdhl_block_rows` tracks
sealed interior rows. **Over-clamp guard** (caught by the pre-cut diff-review): a block whose live interior
exceeds the ring (`> FEED_ROWS`, under `MDHL_BLOCK_CAP`) evicts the opener while streaming, so the upgrade
runs only when the drop is exact (`_mdhl_block_rows <= feed_count()`) — a bigger-than-ring block falls back
to its live verbatim rows. 910 assertions (+15, `test_mdhl_livecard`, incl. a no-trailing-newline
double-emit regression guard). Pin **6.4.20**. Live-verify on a real tty (`--tier=rich`): a streamed code
reply shows the code appear line-by-line, then snap to highlighted. Next in the 0.18.x line: `0.18.4` feed
search, `0.18.5` glyph-width, `0.18.6` inline markdown.

**0.18.2** — maintenance: re-sync vendored **bote-core → 3.0.1** + toolchain refresh to Cyrius **6.4.20**,
2026-07-07. Follows a full-stack MCP-tool investigation (a live-stack test found a handful of tools
returning no usable result). Root causes were **upstream, not in thoth**: bote's `bote_echo` and daimon's
built-in `libro_*` tools returned bare JSON, not the MCP `{"content":[{"type":"text","text":..}]}`
envelope, so thoth (a correct, STRICT MCP client) honestly reported "no text content could be parsed";
plus `scripts/stack.sh`'s generated t-ron policy didn't allow the `libro_*` tools (→ denied). Fixed
across the spine: **bote 3.0.1** (`bote_echo` → `content_text_response`), **daimon 1.3.5** (a new
`_mcp_wrap_builtin` wraps `libro_*` results at the `/v1/mcp/call` dispatch site, `isError` from the `ok`
field), and thoth's `scripts/stack.sh` policy now allows `libro_*` — all three verified end-to-end (the
previously-failing tools now render through thoth's `/call`). thoth needed **NO src change** (the user
chose to keep the client strict + fix conformance upstream). This cut realigns thoth with the released
spine: `src/vendor/bote-core.cyr` re-synced to 3.0.1 (only the embedded `_bote_server_version` 3.0.0→3.0.1
changed — the `[lib.core]` dispatcher is byte-identical, since bote's fix was server-side), and the pin
`6.4.19 → 6.4.20` (`cyrius lib sync`, zero floor-content change; drift cleared; realigns with bote 3.0.1
/ daimon 1.3.5, both on 6.4.20). All lanes behave. 895 assertions (unchanged — no source logic change).
Pin **6.4.20**. The remaining 0.18.x feature line (live card, search, glyph-width, inline markdown) stays
pushed back (see roadmap).

**0.18.1** — **`/theme` recolors scrollback** (the 0.18.0 keystone's first payoff) + a Cyrius **6.4.19**
refresh, 2026-07-07. Because the feed ring stores role MARKERS (0.18.0) not baked SGR, a theme switch
already recolors the whole window: `ui_set_theme` rebuilds the SGR table and the post-dispatch
`feed_repaint` (`/theme`) / `tui_relayout` (⌃T) RE-EXPANDS every stored marker with the NEW theme. This
closes the **0.10.0 limitation** ("existing feed lines keep baked colors; `/clear` for a clean window")
for all role-colored text + syntax highlighting — **no production code change beyond validating it + a doc
correction** (the recolor is a direct consequence of the keystone). **Residual (documented)**: diff-row
background TINTS (`ui_bg`) are stored verbatim, so they don't recolor on a switch — a bounded follow-up.
`cmd_theme`'s comment corrected. **6.4.19 refresh** is pin-only (`cyrius lib sync`, zero floor-content
change; drift cleared; all lanes behave). This cut has **no new production logic** — the recolor is
already-verified (0.18.0's diff review verified marker expansion) and now **test-proven**: a new assertion
paints one stored marker slot under dark then light and asserts the SGR **differs** while the stripped
text is identical, i.e. the same scrollback slot recolors. 895 assertions (+5, `test_feed_markers`). Pin
**6.4.19**. **Live-verify on a real tty (`--tier=rich`): run a colored turn, `/theme light`, watch
scrollback recolor.** Next in the 0.18.x line: `0.18.2` live-upgrading fenced-code card, `0.18.3` feed
search, `0.18.4` glyph-width, `0.18.5` inline markdown.

**0.18.0** — **the re-renderable feed** (role metadata in the ring, SGR applied at paint) + a Cyrius
**6.4.18** refresh, 2026-07-07. Opens the 0.18.x line. The feed ring stored PAINTED bytes (the theme's
concrete SGR baked into each slot) — the reason `/theme` couldn't recolor scrollback (0.10.0) and the
0.15.1 live fenced-code card was deferred. Now the ring stores logical text + compact **role MARKERS** and
the painter **expands a marker to the CURRENT theme's SGR at paint** — **byte-identical rendered output**
for the current theme (golden-tested on both paint paths). Architectural keystone; the payoff
(theme-recolor, live card, search, glyph-width) is the later 0.18.x items. **Design constraint that fixed
the approach**: many PAINT-PATH sites call `emit_raw(ui_sgr(role))` (spinner/tree/rule) while `OUT_RING`
is set, so `ui_sgr` MUST stay concrete — capture happens at **store time (reverse-map), not the emit
layer**. **Marker** = `ESC` + `0xB0..0xB7` (role) / `0xBF` (reset); to the escape scanner it is a 2-byte
escape → zero-width, whole-copied, never severed (**no scanner change**; `feed_visible_cols`/soft-wrap math
unchanged). NEW `ui_role_of_sgr` (`src/ui.cyr`): EXACT whole-string match of an SGR escape vs the 8 cached
role prefixes + reset (so `ui_reset_fg`/`ui_bg`/`ui_eol` stay verbatim → diff rows byte-identical);
`ui_sgr` unchanged. NEW `_feed_pack` (`src/feed.cyr`, seal-time): role/reset SGR → 2-byte marker, keeps
`_feed_safe_copy`'s truncation + severed-tail contracts, and **SANITIZES** a raw `ESC`+`0xB0..0xBF` in
untrusted output (drops the ESC) → the marker space is **unforgeable**. `feed_clip` + `feed_clip_seg`
(PAINT + soft-wrap SKIP/carry) EXPAND a marker to concrete SGR using the **expanded length** in the
capacity guard (carry stores the expanded SGR so color continues across a wrap). `PAINT_CAP` `2112 →
24576` (fits a marker-dense slot's expanded worst case; one-time alloc). **TUI-only → floor byte-identical**
(`_feed_pack` runs only at seal under OUT_RING/PT_RICH; markers never reach fd1; paint is TUI-only;
AGNOS/win/macos still build). The **6.4.18 refresh** is pin-only — `cyrius lib sync` re-vendored the
declared floor subset with ZERO content change (6.4.17/6.4.18 changed elsewhere; drift cleared).
**Two-pass adversarial review** (Workflow: understand → design → diff): the design pass caught a
load-bearing blocker (marker-expand branch required in feed_clip + BOTH feed_clip_seg phases), the
PAINT_CAP expansion-sizing, the exact-match requirement, and folded a collision sanitizer; the diff pass
folded one should-fix (add a `feed_clip_seg` byte-identical golden — the real paint path) and otherwise
**zero defects**. **Live render verifies on a real tty (`--tier=rich`); byte-identical is harness-proven.**
890 assertions (+15, `test_feed_markers`). Pin **6.4.18** (the local cycc wrapper has since drifted to
6.4.19 — a future maintenance bump). Next in the line: `0.18.1` live-upgrading fenced-code card, `0.18.2`
`/theme` recolors scrollback (now trivially enabled by the marker store), etc.

**0.17.4** — **turn interrupt** (Esc aborts a streaming turn without exiting the session), 2026-07-07.
**Closes the 0.17.x input-completeness line.** Esc during a streaming turn (plain or agentic) stops it
cleanly: the partial output stays in the feed with an honest `— interrupted` marker (never presented as
complete), history stays consistent, and control returns to the composer — before, only Ctrl-C (whole-
session teardown) could stop a runaway turn. NEW **`intr_*` module** (`src/tui.cyr`): a turn runs in COOKED
mode (`tui_run_line` drops to canonical so the t-ron `read_line` confirm works), which line-buffers input,
so each streaming read is bracketed by a non-canonical **`VMIN=0/VTIME=0` poll termios** — `intr_arm`
installs it (saving the cooked termios into a PRIVATE buffer, NOT via darshana's `tty_raw`/`tty_cooked`, so
their raw bookkeeping + the post-turn `tty_raw(0)` stay intact), `intr_poll` drains stdin per SSE frame
(any Esc → `_intr_flag`), `intr_disarm` restores cooked (for the following confirm), `intr_note` lands the
feed-only marker. **GATED on `out_mode()==OUT_RING`** (TUI capture path) + the ioctls are **`#ifdef
CYRIUS_TARGET_LINUX`** (darshana's `TCGETS`/`TCSETS` are Linux-only), so off Linux and off the TUI it
no-ops → **floor byte-identical** (verified: AGNOS/win/macos still build; win skips on the pre-existing
epoll gap, not the ioctls). **Abort wiring**: both SSE callbacks (`_hoosh_sse_cb`, `_agent_sse_cb`)
`intr_poll()` and `return 0` on Esc (sandhi stops the stream cleanly — but `[DONE]` also returns 0 and
`sandhi_stream_stopped` is 1 for BOTH, so a thoth-side flag is the ONLY discriminator). The stream wrappers
bracket `intr_arm`/`intr_disarm` and land the partial: `hoosh_send`'s existing "append if non-empty else
pop the user turn" branch already yields a consistent pair; `agent_turn` gains **kind 4 = interrupted**
(append the partial or pop; end the loop; KEEP the partial, unlike max-iters which clears it). **DESIGN-PASS
BLOCKER folded before code**: `agent_turn`'s dispatch was three bare `if`s; a non-returning `kind==4` arm
would fall through into `k==1`/`else` → double-append / double-pop history — fixed to a single
`if/elif/elif/elif/else` chain. **Documented limits** (honest): streaming-only (a blocking turn is one
synchronous POST, non-interruptible); per-frame granularity (a stalled stream is interruptible only at the
next frame or sandhi's read timeout; an Esc during tool-exec lands at the next frame); an aborted turn's
token/cost may be incomplete (omit-until-seen). **Two-pass adversarial review** (Workflow: understand →
design → diff): design pass caught the blocker + the stalled-stream limit; diff pass **ZERO findings**.
**Live interrupt behavior verifies on a real tty (`--tier=rich`), not the harness.** 875 assertions
(unchanged — terminal I/O + turn-loop integration, no meaningful new pure seam). Pin unchanged (**6.4.16**;
the local cycc wrapper has since drifted to 6.4.18 — a future maintenance pin bump, not bundled here).
**The 0.17.x input-completeness line is COMPLETE** (bracketed paste, word-wise editing, mouse, OSC 52 copy,
turn interrupt); next active line is `0.18.x` the re-renderable feed.

**0.17.3** — **OSC 52 clipboard copy** (`/copy` writes the last reply to the system clipboard),
2026-07-07. Continues the 0.17.x input-completeness line. `/copy` (`cmd_copy`, `src/commands.cyr`)
base64-encodes `hoosh_last_reply()` (the accumulator, bounded by `HOOSH_ACC_CAP` = 64 KiB → no truncation
needed) via `bayan_base64_encode` and writes an OSC 52 set-clipboard escape (`ESC ] 52 ; c ; <base64> BEL`,
BEL not ST) straight to the terminal — a byte write, **no fork/exec/dup2**, so it **works on AGNOS and over
SSH** (the AGNOS lane builds it, confirmed). The escape goes to fd1 via `emit_raw` + a raw `SYS_WRITE`
**write-all loop** (a single tty write can short-write the ~87 KB payload) which **bypasses the `OUT_RING`
feed sink** (an escape is terminal control, not feed text — the same path the kitty/mouse enable escapes
use); the ANNOUNCEMENT uses the normal sink so it lands in the feed / stdout. **Best-effort + honest**: OSC
52 is fire-and-forget (a terminal may ignore it / a tmux-screen wrapper may swallow it, and we can't read
back success) so the message never asserts it landed. Guards: empty reply → "nothing to copy yet"; non-tty
stdout (`ui_isatty(1)`) → "needs a terminal"; failed write → honest note. **REPL + TUI** (`CMD_COPY` wired
via `classify_input`/`_dispatch_d`, `/help`, + the TUI slash palette — `SLASH_N` 16→17 + the `/copy`
branch); one-shot doesn't route through `classify_input`, and the `ui_isatty(1)` gate means **piped/CI/
one-shot output is never polluted** with the escape (existing inputs unchanged). **NOT t-ron-gated** — it
only SETS the clipboard (never emits an OSC 52 query to READ it) with content the user already sees, the
same ungated display class as `/read`; no file/exec/network surface, no clipboard-exfil. **Two-pass
adversarial review** (Workflow): a DESIGN pass (2 lenses) folded a should-fix (both palette edits + the
`/c` count) and a nit (`ui_isatty(1)` not `tty_isatty` — they can disagree on AGNOS); a DIFF pass (2
lenses, each finding independently verified) returned **ZERO findings**. **Live clipboard behavior verifies
on a real tty (`--tier=rich` or the line REPL), not the harness.** 875 assertions (+3: `/copy` classify +
palette counts; the emit is live-tty verified). Pin unchanged (**6.4.16**; the local cycc wrapper has since
drifted to 6.4.17 — a future maintenance pin bump, not bundled here). 0.17.x remaining: `0.17.4` turn
interrupt (the line's one item that touches the turn/agent loop — its own design pass).

**0.17.2** — **SGR mouse** (wheel scrolls the feed, click focuses composer/tree, tree-row click
selects/expands), 2026-07-07. Continues the 0.17.x input-completeness line. The T2 TUI enables SGR mouse
reporting (`CSI ?1000h` + `CSI ?1006h`) on enter (disabled on every exit, paired with the kitty/bracketed-
paste push/pop — critical so the terminal isn't left reporting mouse after thoth quits) and decodes
`ESC[<Cb;Cx;Cy(M|m)`. **Decode** (`src/tui.cyr`): `tui_read_key` branches on the `ESC[<` private prefix to
`_tui_read_mouse` (reads `Cb;Cx;Cy`+final `M`/`m` until the terminator/EOF — no artificial cap, so an
over-long report can't desync stdin), which calls the PURE unit-tested `_tui_mouse_decode(cb, final)`: a
wheel (bit 64) → `KEY_SCROLL_UP`/`_DOWN` via buttons 0/1 (reusing the existing feed-scroll arm, so the wheel
scrolls the feed in ANY focus) with horizontal wheel (66/67) ignored; a LEFT PRESS (`cb&3==0`, not motion,
final `M`) → `KEY_MOUSE` (coords stashed in `_mouse_row`/`_mouse_col`); release (`m`)/middle/right/motion
ignored. The normal CSI path (arrows/`~`/kitty-u/paste) is untouched (`ESC[<` occurs for no other key).
**Click** (`_tui_mouse_click`): a click in the tree pane (shown; cols `[1,tw]` and the feed-band rows) maps
the screen row to the node via the SAME `_ftree_scroll_first` geometry the painter uses
(`li = first + (row - feed_top)`), `ftree_set_sel`s it, and toggles expand/collapse for a dir (`tui_relayout`)
/ moves the selection for a file; a click elsewhere focuses the composer. Dispatched as a `tui_loop` arm
BEFORE the `FOCUS_TREE` branch so a click sets focus regardless of current focus (and wheel scrolls in any
focus). **TUI-ONLY → floor byte-identical** by construction (every new symbol confined to `src/tui.cyr`;
verified). Trade-off documented: mouse mode intercepts native click-drag selection in the feed — Shift+drag
bypasses it in most terminals (a config toggle is a possible follow-up, out of scope). **Two-pass adversarial
review** (Workflow): a DESIGN pass (3 lenses) folded two decode nits (read-to-terminator not a byte-cap;
strict vertical-wheel gate); a DIFF pass (3 lenses, each finding independently verified) returned **ZERO
findings**. **Live mouse behavior verifies on a real tty (`--tier=rich`), not the harness.** 872 assertions
(+11, `test_tui`). Pin unchanged (**6.4.16**; the local cycc wrapper has since drifted to 6.4.17 — a future
maintenance pin bump, not bundled here). 0.17.x remaining: `0.17.3` OSC 52 clipboard copy, `0.17.4` turn interrupt.

**0.17.1** — **word-wise composer editing** (readline-basics parity), 2026-07-07. Continues the 0.17.x
input-completeness line. The T2 raw-mode composer gains **word motion** (Ctrl/Alt-Left/Right + Alt-b/Alt-f),
**Ctrl-W** (delete the word before the cursor), and **Ctrl-K** (kill from the cursor to end of the current
logical line; a second Ctrl-K at end-of-line deletes the newline → joins the next line, emacs/readline
semantics). All new logic is PURE + unit-tested in `src/tui.cyr`: `_led_is_wsep` (separator = space or
newline; punctuation is a word char — the WERASE/bash convention shared by motion AND Ctrl-W so they agree
on boundaries), `_led_word_left`/`_led_word_right` (word-boundary index over the flat multi-line buffer,
crossing embedded newlines; **`i > 0` FIRST in every leftward loop so `&&` short-circuits before the
`load8(_composer + i - 1)`** — no OOB read at column 0 / on empty), `_led_delword` + `_led_kill_eol` (the
same bounded `i + gap < _comp_len` shift idiom as backspace, re-NUL at the new length), wired into `led_feed`
alongside the existing motion keys (all `ACT_NONE` — word ops never submit). **Decode**: `KEY_WORD_LEFT`/
`_RIGHT`/`KEY_DELWORD`/`KEY_KILL_EOL`; `_tui_csi_final` routes a modified Left/Right (`CSI 1;<mod>C/D`,
`mod >= 3` = any Ctrl/Alt combo) to word motion while plain (`-1`) + Shift (`2`) stay ordinary arrows (no
regression); `tui_read_key` maps control bytes Ctrl-W (23) / Ctrl-K (11) + the ESC-prefix Alt-b/Alt-f; and
`_tui_kitty_u` decodes the kitty CSI-u forms (`119;5`/`107;5`/`98;3`/`102;3`) so the bindings hold under the
kitty keyboard protocol too. **No tui_loop change** — keys 23-26 fall through the elif chain to the final
`else` → `led_feed` → `tui_after_edit`, so a delete that removes a newline reflows the composer and word
motion re-windows/parks the cursor. **TUI-ONLY → floor byte-identical** by construction (every new symbol
lives only in `src/tui.cyr`; verified: word-edit symbols confined to that file). **Two-pass adversarial
review** (Workflow): a DESIGN pass (3 lenses) folded two should-fixes (`i > 0`-first short-circuit; add the
two reflow/join test cases) and prompted the `p2 >= 3` modifier broadening; a DIFF pass (3 lenses, each
finding independently verified) returned **ZERO findings**. **Live behavior verifies on a real tty
(`--tier=rich`), not the harness.** 861 assertions (+36, `test_tui`). Pin unchanged (**6.4.16**). Next in the
line: `0.17.2` mouse (SGR 1006). *(Note: the local cycc wrapper has since drifted to 6.4.17 — a future
maintenance pin bump, not bundled into this feature cut.)*

**0.17.0** — **bracketed paste** (multi-line paste lands in the composer, never submits at the first
newline), 2026-07-07. Opens the **0.17.x input-completeness line**. The T2 raw-mode composer mapped BOTH
LF (10) and CR (13) to `KEY_ENTER`, so pasting a stack trace / code block fired a turn on line 1 and
stranded the rest. thoth now enables the terminal's bracketed-paste mode (`CSI ?2004h`) on TUI enter
(disabled on every exit, paired with the kitty push/pop — the two early `return repl_loop()` paths run
BEFORE alt-screen enter, so paste mode is never set on them), decodes the `ESC[200~` … `ESC[201~`
brackets, and inserts the whole paste into the composer as literal text. **Three pieces** in `src/tui.cyr`:
(1) **decode** — `_tui_csi_final` returns the new `KEY_PASTE` for `ESC[200~` (already reduced to
`(126, 200, -1)` by the existing unified CSI parser, previously ignored; `ESC[201~` and the legacy
`5~`/`6~` page keys untouched); `tui_read_key` runs the slurp exactly when the CSI final yields KEY_PASTE.
(2) **`_tui_paste_slurp`** (I/O, live-tty verified) reads stdin a byte at a time into a lazily-alloc'd
`_paste_buf` until the `ESC[201~` end marker (or EOF); a byte-wise marker matcher flushes a broken partial
match back as literal content and re-anchors on `ESC` (the marker's only self-restart — END has an empty
self-border), the end marker consumed but NOT buffered; bounded through a SINGLE capped writer
(`_paste_commit`, `PASTE_CAP` = 4096 == COMPOSER_CAP) so over-cap content is dropped while the stream is
still consumed to the marker (no input desync). (3) **`led_paste`** (PURE, unit-tested) inserts the buffer
at the cursor by reusing the tested `led_feed` path one byte at a time; FILTER: LF/CR (and CRLF) collapse
to a single `\n`, a tab becomes one space, printable ASCII + high/UTF-8 bytes (≥128) kept, **ESC + every
other C0 control + DEL (127) DROPPED** — a paste can NEVER inject a terminal escape into the composer
render and no control byte enters the buffer (composer stays byte==column). Never submits (only
`KEY_NEWLINE`/`KEY_CHAR`, both `ACT_NONE`); a pasted leading `/` does NOT dispatch (`tui_palette_active` is
a buffer derivation, not a flag). The `KEY_PASTE` loop arm inserts + reflows (a >8-line paste clamps to
`COMPOSER_MAX_ROWS`, scrolls internally); composer-focus action (a paste while the tree is focused no-ops —
body already consumed, no desync). **TUI-ONLY → floor byte-identical** by construction (the composer /
CSI decode / enable-escapes only run inside `tui_loop`, gated on `tui_active()` = PT_RICH + isatty(0/1));
empirically verified: `--help` + piped `--version` emit ZERO `?2004`/ESC bytes, and every paste symbol
lives only in `src/tui.cyr`. **Two-pass adversarial review** (Workflow): a DESIGN pass (4 lenses, pre-code)
found no blockers and folded two should-fixes (flush routes through the capped writer or a near-miss at the
cap could write 4 bytes past `_paste_buf`; tab→space keeps the composer strictly printable so the
"no control byte enters" invariant is literally true); a DIFF pass (4 lenses, each finding independently
verified) returned **ZERO findings**. Documented cosmetic caveat: a tab-heavy paste renders tabs as single
spaces and wide/CJK bytes count as one column (same width class as soft-wrap 0.11.3); it does not affect
the bytes submitted. **Live paste verifies on a real tty (`--tier=rich`), not the harness.** 825 assertions
(+19, `test_tui`). Pin unchanged (**6.4.16**). Next in the line: `0.17.1` word-wise composer editing.

**0.16.1** — toolchain refresh to Cyrius **6.4.16**, 2026-07-07. Maintenance pin move `6.4.11 → 6.4.16`
(`cyrius.cyml` + `cyrius lib sync` — 70 floor modules; two changed content, the other 68 byte-identical).
**No thoth source change**; **806 assertions pass unchanged**; x86_64 Linux builds + ships as before, and
`build.sh all` behaves exactly as at 0.16.0 (linux ships, AGNOS builds git natively, aarch64 size-gapped
at 17.06/16 MiB, windows on the IOCP `SYS_EPOLL_CREATE1` gap, macOS native-runner skip). Clears the
pin-drift warning (the wrapper cycc had drifted to 6.4.16). The two content changes are both **additive**,
so no existing thoth path moves: (1) **bayan `1.0.4 → 1.1.0`** adds a **TOML array-VALUE getter**
(`bayan_toml_array_parse` / `bayan_toml_get_array` decompose a verbatim-captured `key = [a, b, c]` into
top-level element Strs — the scalar-array counterpart to `[[section]]` arrays-of-tables) plus a
multi-line-array parse fix (a literal `'`-quote or a `#` comment inside a bracketed value no longer
truncates it). This **lifts the exact constraint the 0.16.0 `shell` tool worked around** — the
`[shell.deny]`/`[shell.allow]` glob lists are `label = "glob"` sections *because* bayan had no
array-value getter; that workaround is now removable and is logged as a **scheduled config-surface
cleanup** (its own slice + review — deliberately NOT folded into this source-change-free refresh). (2)
**math** gains **aarch64 `f64_sin`/`f64_cos` polyfills** (Taylor range-reduction; x86 keeps native
`fsin`/`fcos`) — purely additive, thoth invokes no trig, x86/AGNOS codegen unchanged; it does not shrink
the aarch64 binary, so that lane stays size-gapped (an unrelated static-data cap). 806 assertions
(unchanged). Pin **6.4.16**.

**0.16.0** — **the model-invokable `shell` tool + protections**, and a toolchain refresh to Cyrius
**6.4.11**, 2026-07-06. The backing model can now propose a shell command during an agentic turn:
thoth runs it locally under a wall-clock timeout, captures merged stdout+stderr, and feeds a bounded
result back — mirroring the `memory_write` local-tool shape (advertised only when opt-in
`[shell].enabled` AND the target can capture, dispatched in the SERIAL executor, never forwarded to
daimon; reachable only in agentic turns = daimon wired, the memory_write precedent). **NEW `src/shell.cyr`**
`shell_run_tool({"command":…})`: parse → a LOCAL `[shell.deny]`/`[shell.allow]` glob filter checked
**BEFORE t-ron** (deny-wins; a non-empty allow-list is default-deny; so a deny-list holds even with no
`[tron].policy`) → the t-ron gate under the **DISTINCT reserved name `thoth_shell`** (separate from
`thoth_run` = the human `/run`, so a policy can allow the operator's shell while denying the model's;
the raw command is the JSON-escaped scanned payload via `_params_one`) → a bounded, timed capture;
NUL-terminate + scrub interior NULs→spaces, format an exit/timeout/truncation footer, and audit every
proposed+executed command (`log_begin("shell")`, exit+bytes, never the output). **NEW
`exec_shell_capture` in `src/exec.cyr`** copies `lib/regression.cyr`'s pattern (child stdout+stderr →
`/tmp/thoth_sh_<pid>_<ctr>` via `O_CREAT|O_EXCL|O_WRONLY` → `WNOHANG`-poll-with-deadline → `SIGKILL` +
blocking reap → `file_read_all` + unlink) — combining capture + timeout so a runaway command is killed
with partial output preserved and no pipe-fill deadlock; `shell_supported()` reports POSIX capability.
**`[shell]` config**: `enabled` (off), `timeout_ms` (30 s, clamp 10 min), `max_output` (64 KiB, clamp
1 MiB), and `[shell.deny]`/`[shell.allow]` glob tables as sections of `label = "glob"` pairs (bayan has
no TOML-array getter; `glob_match` is `*`/`?`-only, whole-command). **POSIX-only, degrade closed**: the
raw-syscall body is compiled out on AGNOS (no `/bin/sh -c`, no `WNOHANG`) and Windows (`#ifndef
CYRIUS_TARGET_AGNOS`/`_WIN`, mirroring `lib/process.cyr`) — the tool is NOT advertised there and
`/state` announces "unsupported on this target"; the AGNOS build stays clean (verified). **Byte-identical
floor when off** (the default): `agent_tools_add_shell` returns `tl` unchanged (zero writes), no `/state`
shell row, no request-body delta; a hallucinated/un-advertised `"shell"` call is matched unconditionally
in `_agent_round_has_local` (→ serial), and the dispatch elif re-checks `config_shell_enabled() &&
shell_supported()` → an honest not-enabled string, NEVER executed and NEVER forwarded to daimon. The
deny/allow globs are a **coarse pre-filter, explicitly NOT a sandbox** (a shell can `cd`/chain/decode
around a string glob) — stated honestly in code/`/state`/example; real containment is default-off + the
operator's trust decision + the t-ron policy + OS confinement. Residuals documented (not faked):
binary NULs scrubbed; the timeout kills the `/bin/sh` not a backgrounded grandchild; the temp file is in
world-writable `/tmp` (best-effort `O_EXCL`, no `O_NOFOLLOW`). **Toolchain refresh** `6.3.41 → 6.4.11`
(`cyrius lib sync`, 14 floor modules; clears drift+shadow warnings; the pre-feature 766 assertions pass
unchanged before the feature). Deferred: an `agent_enabled()` relax (shell without daimon), a Windows
timed capture, process-group kill. [ADR-0014](../adr/0014-model-shell-tool-local-posix-gated.md). 806
assertions (+40, `test_shell`; the real exec/timeout cases spawn `/bin/sh` and pass in-sandbox). Pin
**6.4.11**.

**0.15.1** — **markdown fenced code blocks in the reply are syntax-highlighted**, 2026-07-03. The
model's reply is markdown; where `/read` (0.8.4) and diff bodies (0.8.5) already colour source, a
` ```bash `/` ```python `/`~~~c` block now renders highlighted in the TUI feed — reusing the SAME
coverage-guarded `_hl_span` UNCHANGED. New **`src/mdhl.cyr`**: a line-assembling fence state machine
in front of all four reply-emit paths (hoosh/agent × blocking/streaming) that buffers each fenced
block until its closing fence, then highlights the WHOLE block in one `_hl_span` pass (multi-line
strings/comments colour correctly), emitting fence delimiters + prose verbatim. Handles ` ``` `/`~~~`,
indented (≤3)/longer-run/CRLF/unterminated/mixed fences; info-strings map to grammar names via a small
alias-first table (`bash`/`sh`→`shell`, `py`→`python`, `js`→`javascript`, `rs`→`rust`, `c++`→`cpp`, …),
every canonical name falls through, `_hl_span` self-heals unknown names to verbatim, `text`/`plain`/
`diff` stay uncoloured. Wired via a new `_hoosh_print_reply` (blocking) + `mdhl_feed`/`_reset`/`_finish`
(streaming); error bodies keep `_hoosh_print_str` (never highlighted). **STREAMING**: a fenced block is
WITHHELD until its close then appears highlighted at once (whole-block-to-one-tokenizer correctness;
spinner covers the gap); because a fence is a whole-line construct, TUI text renders LINE-BY-LINE not
char-by-char (removes per-char flicker, complements the 0.15.0 throttle — a behaviour change). The
fully-live "upgrade the block to a highlighted card in place" is deferred (must re-render sealed feed
rows). **Floor byte-identical**: at `PT_PLAIN` `mdhl_feed`/`mdhl_reply` are a strict `emit_n`
pass-through + `mdhl_finish` a no-op; `_hoosh_acc`/history/`--json`/`-o` read the RAW reply — proven by
a `strip_sgr(output) == input` coverage property test (never drops/reorders a byte). 766 assertions
(+52: `test_mdhl_tag_map`/`_fence`/`_render`/`_stream` — map, scanners, PT_PLAIN-0-escapes +
PT_ANSI-coloured-with-verbatim-delimiters + SGR-strip coverage, byte-split chunk invariance,
unterminated flush; colour live-verified on a real tty). [ADR-0013](../adr/0013-reply-code-highlighting-block-buffered.md).
Pin **6.3.41**.

**0.15.0** — **smoother streaming: coalesce feed repaints onto a frame budget**, 2026-07-03. Opens
the 0.15.x streaming-polish line (0.15.1 = markdown fenced-code highlighting on top). The TUI feed
was repainting on **every** SSE delta; at 80–150 tok/s that is 100+ full repaints/sec → the pending
line + spinner thrash and the terminal can't keep up (tearing / "splash"). `feed_stream_tick`
(`src/tui.cyr`) now decouples paint rate from token rate via a pure `_stream_should_paint(now, last)`:
repaint at most once per **`STREAM_FRAME_MS` (33 ms, ~30fps)**, dropping intra-budget ticks (the
chunk's bytes are already in the ring). **Throttling, not a typewriter delay** — the model is not
slowed; only the intermediate PAINT is capped. A backward monotonic step fails open (paints, never
stalls); `spin_begin` clears the paint clock so the first chunk of each turn paints instantly; the
spinner advances only on painted frames (human ~30fps instead of a blur). No content stranded — the
post-dispatch `feed_flush_pending`+`feed_repaint` (~line 1045) always lands the final state on every
exit path. **Floor byte-identical** (`feed_stream_tick` still no-ops off `OUT_RING` → line REPL /
piped / one-shot / CI never enter the throttle; `_hoosh_acc`/history/`--json`/`-o` untouched — paint
timing only). 714 assertions (+7, `test_stream_throttle` — the frame boundary, fail-open backward
step, first-tick instant paint; the paint itself is live-verified on a real tty). Pin **6.3.41**.

**0.14.1** — the agentic vertical now **completes end-to-end**; hoosh **2.4.12** resolves 0.14.0's
finding (1), 2026-07-03. No thoth source change — the fix is in the consumed spine (hoosh's Anthropic
request-builder now translates OpenAI `tool_calls`/`role:"tool"` messages into `tool_use`/`tool_result`
content blocks instead of copying them verbatim; the former sent Anthropic-invalid shapes and surfaced
as a misclassified `502`). **Re-verified live** (hoosh 2.4.12 + daimon + bote 3.0.0 + thoth): a one-shot
agentic turn runs thoth → hoosh Opus → tool-call → t-ron allow → daimon → bote 3.0.0 `fs_write`
(written) → result fed back → **hoosh returns the final summary** → thoth exits 0 (was: 502 on the
continuation turn → exit 1 with empty stdout despite the tool executing). **Requires hoosh ≥ 2.4.12**
for agentic loops on Anthropic-backed models. Findings (2) bayan inline-comment parse + (3) `bote_echo`
bare-`{}` sample tool remain (upstream quirks, non-blocking). 707 assertions; pin **6.3.41**; bote-core 3.0.0.

**0.14.0** — vendored **bote 2.7.7 → 3.0.0** (MCP-protocol refresh) + a full vertical integration test, 2026-07-03.
Refreshes the in-process MCP-protocol bundle (`src/vendor/bote-core.cyr`; `sync-bote.sh` tag → 3.0.0);
bote 3.0.0's breaking changes are server-side, so the `[lib.core]` dispatcher thoth vendors (for the
vendored t-ron's references) stays API-compatible — thoth builds clean, 707 tests. **Integration test
(thoth 0.14.0 + hoosh + daimon + bote 3.0.0), PROVEN end-to-end**: `/tools` lists daimon's registry;
`/call` round-trips a tool (t-ron allow → daimon → bote 3.0.0 → executed); an agentic turn runs the
full loop (thoth → hoosh Opus → tool-call → t-ron → daimon → bote 3.0.0 `fs_write` executed + result
parsed). **Three findings, none in thoth's spine/git code**: (1) the agentic loop can't COMPLETE —
hoosh returns HTTP 502 on the tool-continuation turn (assistant `tool_calls` + `tool` result);
simple/repeated calls succeed → a hoosh OpenAI→Anthropic tool-message translation bug, **filed on
hoosh's roadmap** with a minimal repro; (2) a **bayan** inline-comment config bug (`key = val # note`
read with the comment attached → thoth's `_cfg_*` mis-parse; why `stream = false #…` read as
streaming) — worked around in stack.sh, root cause bayan; (3) bote's sample `bote_echo` returns a bare
`{…}` not MCP content blocks (real fs tools are conformant). Also fixed stack.sh's generated
`thoth.cyml` to keep comments off value lines. 707 assertions; pin **6.3.41**; requires bote-core ≥ 3.0.0.

**0.13.2** — toolchain refresh to Cyrius **6.3.41** (globals cap raised) + a detached-HEAD test fix,
2026-07-03. Maintenance pin `6.3.38 → 6.3.41` (`cyrius.cyml` + `cyrius lib sync`, 70 floor modules);
clears the drift warning. 6.3.41 **raised the `max 1024 initialized globals` cap** (the ceiling that
forced sit's `[lib.read]` + sankoch's `[lib.zlib]` profiles) — those lean profiles are KEPT (worthwhile
on their own: smaller bundles, less dead code; the raised cap just removes the *force*, not the merit).
**Fixed the sole CI failure**: `test_git` assumed a present repo always has a named branch, but CI
checks out a detached HEAD (bare SHA) where `git_branch()` is the `"?"` sentinel — now asserts a real
branch only when attached, the sentinel when detached (production was always right; only the test was
wrong). No source-logic change; 707 assertions; all lanes behave (linux ships, AGNOS builds git
natively, aarch64 size-gapped, windows IOCP gap). Pin **6.3.41**.

**0.13.1** — refold the git producer onto **patched sit 1.3.1 + sankoch 2.4.9**, 2026-07-03. Drops
two of the three vendor workarounds 0.13.0 carried, no behavior change. **sankoch**: the full 2.2.5
pin → the **2.4.9 `zlib` profile** (`dist/sankoch-zlib.cyr`, sankoch's new `[lib.zlib]` — DEFLATE/zlib
only, **53 globals** vs the full 175), so thoth tracks CURRENT sankoch and stays under cyrius's
1024-global cap (was the reason for the old pin). **sit**: 1.3.0 → **1.3.1**, whose `sit_repo_open`
is now **chdir-free** (reads at process cwd; behavior-preserving — all consumers pass `"."`) — so
thoth's `SYS_CHDIR` neutralisation sed is gone and the read profile is **AGNOS-native** (`build/
thoth_agnos` builds with NO thoth-side patch; gate 1 intact, git works there). The `_stream_grow`
rename is also gone (the zlib profile drops `stream.cyr`). Only the `entry_hash`/`ann_new` renames
remain in `scripts/sync-sit.sh` (sit's fns vs thoth's libro/bote — an inherent integration collision).
aarch64 stays best-effort size-gapped (the 16 MiB cap is the binary's static data, not sankoch's
version). 707 assertions (unchanged — no source-logic change). Pin unchanged (6.3.38). Requires
sit ≥ 1.3.1 + sankoch ≥ 2.4.9.

**0.13.0** — the **git producer** (branch / status / diff by consuming sit), 2026-07-03. thoth
reports the working repo's branch + working-tree status in `/state`, the TUI status bar, and a new
`/git` command, reading real **git** and **.sit** repos through **sit 1.3.0**'s read-only VCS API
— no shell-out to system `git`. thoth owns **no** VCS logic (sit owns the domain). New **`SEAM_GIT`**
on the capability ladder (`src/seams.cyr`, #6; `SEAM_COUNT` → 7; native binding, FULL-at-repo /
ABSENT-otherwise) + **`src/git.cyr`** (`git_probe` reads via `sit_repo_open(".")`/`_branch`/`_status`,
copies the branch out of sit's arena, caches — probed at startup / per turn / on `/state`|`/git`, never
per paint; content-blind). Surfaced: `/state` git row (`branch — N changed` / honest absent line), a
status-bar segment (`⎇ branch +N`, omit-until-present per ADR-0010), and `/git` (per-file `M`/`A`/`D`
list via `sit_status_path`/`_kind`). **Vendored** `src/vendor/sit-read.cyr` + `src/vendor/sankoch.cyr`
(source-included via `scripts/sync-sit.sh`, NOT `[deps]`): **sankoch 2.2.5** (50 globals) not sit's 2.4.8
(175, which blows cyrius's 1024-global cap); `\b`-renames on sync for 3 harmful spine collisions
(`_stream_grow`/`entry_hash`→libro's audit getter/`ann_new`→bote); `sit_repo_open`'s `SYS_CHDIR`
neutralised (thoth passes `"."`) — **keeps the AGNOS build (gate 1) AND makes git work there** (sit reads
at cwd). **Cross-target:** linux ships; **AGNOS builds with working git**; **aarch64** now over its fixed
16 MiB output cap with the sit bundle → announced best-effort **size-gap** in `build.sh`; windows on its
IOCP gap. **Floor byte-identical** (git interactive-only; one-shot skips it; `/state` row = empty T0
roles, 0 escapes piped). Pre-cut adversarial review (4 lenses, each verified): **zero confirmed findings**.
707 assertions (+11, `test_git` + seam-count). Pin unchanged (6.3.38). Deferred: `/git` per-file diff
(`sit_diff_path`); a chdir-free sit open + decompress-only sankoch would drop the two vendor patches.
**Next active line**: the four v1.0 gates (AGNOS-dominated — gate 1 build cleared, gate 2 runtime is
nearest; see [[thoth-next-items-gate-map]]).

**0.12.3** — toolchain refresh to Cyrius **6.3.38** + the **AGNOS build lane lights up (v1.0
gate 1)**, 2026-07-03. Maintenance pin move `6.3.15 → 6.3.38` (`cyrius.cyml` + `cyrius lib sync` —
70 floor modules, 15 changed; `sigil`/`patra`/`sandhi`/`bayan`/`async`/`thread*` the notable
diffs). **No thoth source change**; 696 assertions pass unchanged; x86_64 Linux builds + ships as
before. Clears the drift + shadow-lib warnings and the benign `_sandhi_conn_open_v6_fully_timed_a`
arity warning (6.3.38 sandhi fixes the h2-promotion arg count). **The refresh is more than a
drift-clear** — it cleared **both** documented transient floor gaps: (1) **AGNOS now BUILDS**
(`build/thoth_agnos`, a valid statically-linked x86_64-AGNOS ELF, **zero undefined symbols**) — the
peer's missing `SIGHUP` signal-NUMBER constant (filed
`agnos 2026-06-23-cyrius-agnos-peer-missing-signal-number-constants`) is defined in the 6.3.38 peer,
so **the BUILD half of v1.0 gate 1 is cleared** (the RUNTIME half — a consumer green on real AGNOS —
is **gate 2**, external, unchanged: the ELF targets the AGNOS syscall ABI, un-runnable on a Linux
host); (2) the **Windows `SYS_GETRANDOM`** transient gap cleared (patra ≥1.12.4 bundled), so `--win`
now stops on the genuine ARCHITECTURAL `SYS_EPOLL_CREATE1` (IOCP) gap. **`scripts/build.sh`
maintenance:** `TRANSIENT_GAP` emptied (both entries cleared — kept as RESOLVED history in-comment)
with an empty-case guard so a trailing `|` can never make the known-gap regex swallow every failure;
`win`/`agnos` docstrings refreshed. Re-verified `build.sh all`: linux ships, win skips on the epoll
gap, **aarch64 + agnos both build**. The AGNOS *build* clear is verified (file type/size/clean
`OK`/zero undefined symbols); the AGNOS *runtime* is NOT claimed. 696 assertions (unchanged). Pin
**6.3.38**. **Next active line unchanged**: the externally-gated 0.13.0 git producer (sit); gate 2
(external AGNOS runtime) is now the nearest v1.0 gate that can advance.

**0.12.2** — `memory_write` tool (agentic write) + `AGENTS.md` pickup — closes the 0.12.x line,
2026-07-02. The model can now save durable facts to project memory during an agentic turn:
**`memory_write`** is advertised alongside daimon's tools (`agent_tools_add_memory`, `src/agent.cyr`)
when `[memory].enabled`; on call, thoth **intercepts it locally** — gated under `thoth_remember` (same
t-ron choke point as `/remember`), **never forwarded to daimon** — and a round containing it is forced
through the serial executor so the parallel daimon workers never see it (`_agent_round_has_local`).
Backed by the shared `memory_append` (`src/memory.cyr`; `/remember` refactored onto it). Verbatim only —
no summarize/tag/dedupe/link (mneme's engine). The read set gains an optional project-root **`AGENTS.md`**
(model-facing notes; `CLAUDE.md` stays the harness contract, not auto-injected); `memory_system_prompt` no
longer early-returns on a missing `.thoth/memory` dir. **Live-verified**: an agentic turn where Opus called
`memory_write` → `[t-ron] allow: remember to .thoth/memory/MEMORY.md` → the fact landed in `MEMORY.md`.
Advertised only with daimon wired (the agentic precondition — the path the mneme MCP tools will ride);
manual `/remember` covers the no-daimon case. 696 assertions (+7). Pin unchanged (6.3.15). **0.12.x
memory-seam line COMPLETE**; next active line is the externally-gated 0.13.0 git producer.

**0.12.1** — `/remember` (memory-seam write half), 2026-07-02. `/remember <fact>` appends a verbatim
bullet to `.thoth/memory/MEMORY.md`, t-ron-gated under the reserved name `thoth_remember` (same choke
point as `/write`; absent-t-ron → fail-closed confirm). Portable `file_append_locked` (creates the file;
the AGNOS append-gap is handled in `lib/io.cyr`); `memory_invalidate()` makes the fact live on the next
turn (verified live: `/remember` then `/dry` shows it). **Verbatim only** — no summarize/tag/dedupe/link
(that is mneme's engine, ADR-0012). thoth does NOT create `.thoth/memory/` (no portable mkdir —
`sys_mkdir`'s arg shape forks on AGNOS: `path,pathlen` vs `path,mode`); degrades CLOSED with guidance if
the dir is missing (candidate to file against the agnos peer). Works whether or not `[memory].enabled`
(saved either way; a note says it is not injected until enabled). 689 assertions (+1). Pin unchanged
(6.3.15). Next: `memory_write` MCP tool + `AGENTS.md` pickup (0.12.2).

**0.12.0** — memory seam + local `.thoth/memory` reader (the mneme fallback), 2026-07-02. Opens the
0.12.x line ([ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md)). Memory is **mneme's** domain
(the AGNOS knowledge base — semantic search / RAG; still Rust, not yet Cyrius-ported), so thoth builds
NO memory engine. It models memory as a **capability seam** (`SEAM_MEMORY`, `src/seams.cyr`) that binds
native → mneme when present and degrades to a dumb project-local flat-file reader when absent — the
`git → sit` omit-until-owner shape; `seam_cap_state` special-cased like t-ron (off → `absent`, enabled →
`degraded`, mneme → `full`), rendered in `/seams` + `/state`. New **`src/memory.cyr`**: `memory_system_prompt()`
reads `.thoth/memory/MEMORY.md` (index first) + `*.md` facts (dir order, whole-or-skip) to a **4 KB** cap,
verbatim, cached like the persona; **content-blind** (recency + budget only — NO search/rank/embed/link;
that is mneme's engine, the litmus guarded in-module + ADR). `memory_context()` pins the injectable contract
(`a cstr or 0`) the mneme branch marshals into. **Injected** as a second `{role:system}` message after the
persona, before history — a new `mem` param through the 4 request builders (`hoosh_build_request`/`_messages`/
`_dry`, `agent_build_request`), acquired gated on `seam_cap_state(SEAM_MEMORY) != CAP_ABSENT` at `hoosh_send`/
`agent_turn`/`/dry` (shown in the `/dry` preview). **Opt-in** `[memory].enabled` (default off — a checked-in
`.thoth/memory` is a prompt-injection surface, same trust as `CLAUDE.md`). `/state` memory row +
`thoth.cyml.example` block. **Byte-identical floor** (off/absent → `mem`=0 → builders omit; verified via `/dry`,
0 occurrences; prior request bodies unchanged). Notes match mneme's vault frontmatter → later ingestible by
mneme (fallback not throwaway). **The git producer moves to 0.13.0** (externally sit-gated; memory is drivable
now). 688 assertions (+13). Pin unchanged (6.3.15). Next: `/remember` (0.12.1) + `memory_write` tool (0.12.2).

**0.11.10** — `--tier` flag (replaces the `THOTH_TIER` env-var), 2026-06-26. The presentation tier
is now a first-class flag — `thoth --tier=simple|rich|auto` (also `--tier <mode>`) — with
capability-aware auto-detection, REPLACING `THOTH_TIER` (dropped; no `getenv("THOTH_TIER")` remains).
**`auto` is the default and now launches the rich TUI on a capable terminal** (stdin+stdout TTYs +
color-provable) — a deliberate BEHAVIOR CHANGE: bare `thoth` opens the TUI where it can (was the
line REPL); pipes/CI/dumb/`NO_COLOR` still degrade to plain, and one-shot is untouched. `simple` =
line mode (PT_ANSI when color is provable, else PT_PLAIN; never the TUI). `rich` = force the TUI when
usable, degrading to the line tier otherwise. **ui.cyr:** new `TIER_AUTO`/`_SIMPLE`/`_RICH` +
`_ui_tier_pref` + `ui_set_tier_pref`/`ui_tier_pref`/`ui_tier_pref_from_name`; the old NO_COLOR/isatty/
TERM checks factored into a pure `_ui_color_capable()`; `ui_detect_tier` rewritten around the pref
(PT_RICH requires a tty BOTH ways AND color-capability, since the TUI renders in color). **oneshot.cyr:**
`--tier=<v>` / `--tier <v>` parsed as a global MODIFIER (not a one-shot mode, not a run-forcer) into
`_oneshot_tier`/`_oneshot_tier_bad` (pure parser; main applies it); the space form will NOT swallow a
following flag (`--tier --version` still prints the version — guarded on the next token not starting
with `-`); `--help` gains a `--tier` line; bash/zsh completion complete `auto rich simple`. **main.cyr:**
applies `ui_set_tier_pref(oneshot_tier())` before `ui_detect_tier`, with a stderr note (fd2, honest in
one-shot) on an unknown value (falls back to auto). The live-verify command is now `./build/thoth
--tier=rich`. 675 assertions (+17: `test_oneshot` parse cases + `test_ui` name mapping). **TUI render +
the auto-rich default verify only on a real tty (`--tier=rich`)**, not the harness. Pin unchanged (6.2.43).
**0.11.9** — TUI polish: faint rules + multi-line composer + live status line, 2026-06-26. Three
T2-only fixes (the line REPL / piped / one-shot floor is byte-identical — `tui_read_key`, the
composer, and the greeting only run inside `tui_loop`; a one-line composer renders exactly as
before). **(1) Faint rules** (`tui_draw_rule`): a full-width `─` under the status bar (suppressed
when status hidden) and above the composer. **(2) Multi-line composer**: `KEY_NEWLINE` inserts
`\n`; the composer grows UPWARD (one logical line per physical row, no in-composer soft-wrap),
the feed shrinks, plain Enter submits the whole buffer. Newline decode has TWO paths — **Alt+Enter**
(universal, legacy `ESC CR`/`LF`) and **Shift+Enter** via the kitty keyboard protocol (pushed
`CSI > 1 u` after alt-screen enter, popped `CSI < u` on every exit). Verified against the kitty
spec: disambiguate keeps text keys, Tab, Backspace, plain Enter, unmodified arrows, Home/End/PgUp/
PgDn, and the **Shift-arrow feed-scroll keys (`CSI 1;2A/B`)** legacy — only Esc + Ctrl/Alt-combos
move to CSI-u, so a unified CSI parser + `_tui_csi_final`/`_tui_kitty_u` decode `CSI 13;<mod>u`→
newline and the Ctrl-combos (`120;5`→exit, `103;5`→status, `98;5`→tree, `116;5`→theme, `117;5`→kill,
`97/101;5`→Home/End) back to their keys (or they'd break under kitty). Geometry is rewritten PURE
over `(rows, lines, show)` params (mirrors `tui_tree_w`/`tui_feed_width`): `tui_feed_top`→3 when
status shown; height = `clamp(led_lines(), 1, COMPOSER_MAX_ROWS)` always leaving `MIN_FEED` feed
rows; a cursor-anchored vertical window (`_comp_vscroll_first`) + per-line horizontal scroll, with
`tui_draw_composer`/`tui_park_cursor` sharing `_comp_row_hstart` so they can't drift. A height-delta
redraw gate (`tui_after_edit` → `tui_repaint_body`, no `tty_clear` = no flash) reflows the feed when
a newline grows/shrinks the composer — wired into the input, submit, and recall paths. Up/Down
navigate composer lines (`led_up`/`led_down`) and fall through to input-history recall only at the
top/bottom EDGE. **(3) Live status greeting**: the hardcoded `READY` line now reflects a live reachability
PROBE — `Status: READY` only when the gateway actually answers, else `Status: hoosh unreachable —
<url> (is the gateway up?)` (URL set, nothing responds) or `Status: hoosh absent — set [hoosh].url`
(none). Driven by `hoosh_reachable()` (`src/hoosh.cyr`): a SILENT GET to the models endpoint — any
HTTP status = reachable (even 404/401 = up), only a transport failure (refused/timeout/DNS) = down;
reflects what a turn would find (refused localhost = instant; a black-hole remote uses the same
blocking connect a turn would — bounded-connect is a later refinement). NOT `seam_cap_state` (that
is config-presence, not liveness — the first cut wrongly showed `ready` with a URL set but the
gateway down; the user caught it live). `READY` is uppercase, as before.
**Cross-session fix**: multi-line entries no longer shatter the line-oriented `[history].file` —
`src/inhist.cyr` escapes `\`→`\\` and newline→`\n` on write and decodes on read (backward-compatible:
a stray `\X` in a pre-0.11.9 file is preserved verbatim). TWO ASCII-vs-int regressions from the
parse-to-int CSI refactor, both caught + fixed pre-cut: (a) `_tui_csi_final`'s `~` branch compared
`p1` against ASCII `53`/`54` (must be `5`/`6`) — caught by the new PageUp/Dn tests; (b) the Shift-
arrow branches compared `p2` against ASCII `50` (must be `2`) — would have killed Shift+↑/↓ feed
scroll on every terminal, MISSED by the initial tests (which fed the raw byte `50` the live parser
never produces) and CAUGHT by the adversarial diff-review (5 dimensions, all converged on it); the
masking tests were corrected to feed the parsed int. 658 assertions (+59: `test_tui` geometry/
multi-line/decode + `test_inhist_persist` round-trip). **TUI render verifies only on a real tty
(`--tier=rich`)**, not the harness. Pin unchanged (6.2.43).
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
(`--tier=rich`), not the harness. Pin unchanged (6.2.43).
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
only on a real tty (`--tier=rich`)**, not the harness. The REPL/piped/CI floor is
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
a real tty (`--tier=rich`)**, not the harness. 362 assertions (+21, `test_ftree`).
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
**TUI render verifies only on a real tty (`--tier=rich`)**, not the harness. 341
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
(`--tier=rich`)**, not the harness. 337 assertions (+42, `test_feed`/`test_feed_ring`/
`test_capture`). Pin unchanged (6.2.40). Known → 0.9.2: instant SIGWINCH + working
spinner + incremental streaming paint; → 0.9.3: the togglable left-column file-tree pane.
**0.9.0** — the T2 rich-TUI front-end (M7), 2026-06-24. An interactive alt-screen TUI
(new `src/tui.cyr` + vendored `src/vendor/darshana.cyr`): a pinned, Ctrl-G-togglable
status bar, a scrolling feed (the composer clears on Enter; the response streams
below), a raw-mode composer with line editing + horizontal scroll, a slash-command
palette, and keybinding hints; exit via Ctrl-X / Ctrl-C / /quit (all restore the
terminal). Active only at PT_RICH on a real tty (`--tier=rich`); the line REPL
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
`NO_COLOR`/`--tier`, degrade-closed) + a semantic color-role API (`ui_sgr`/
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
bundle (avatara 2.8.0) supplies the Thoth/Librarian persona in-process — sourced
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

- **Cyrius pin**: `6.4.62` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc`. The pin advanced steadily across the 0.11.x–0.33.x arc via
  `cyrius lib sync` floor refreshes (no thoth source change) — most recently
  6.4.29 → 6.4.46 → 6.4.49 (0.27.0 and the 0.30.x GUI work) → 6.4.57 (0.32.0
  atomic writes) → 6.4.58 (0.32.1) → **6.4.62** (0.33.2). Earlier history:
  **0.10.1** took 6.2.40 → 6.2.43. The 0.7.0 line had run on 6.2.40. Earlier:
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

## Surface at a glance

> The per-file source map lives in the getting-started guide's [source layout](../guides/getting-started.md); what
> shipped in each release is the **version log above** + [CHANGELOG](../../CHANGELOG.md). This is a current summary
> by subsystem, not a per-module changelog — that per-module duplication had frozen at ~0.11.x and was removed in the
> 0.33.7 doc sweep.

- **Driver core** — `main` / `repl` / `commands` (the command hub: `/help`, `/state`, `/seams`, `/model(s)`,
  `/read`/`/write`/`/run`, `/tools`/`/call`, `/audit`, `/dry`, `/theme`, `/persona(s)`/`/role`, `/git`,
  `/remember`/`/notes`, the `/conversations`/`/new`/`/switch`/`/rename`/`/delete`/`/search` chat-management set,
  `/save`, `/reload`, and `[alias]` macros) / `config` (the `.thoth/` home) / `seams` (the capability registry,
  two-axis ladder) / `gate` (the t-ron choke point).
- **Session + conversation** — `session` (session state, per-message model, and the **keyed multi-conversation
  store** — the `conv_*` API + `THOTH-SESSION-2` persistence carrying each reply's model / cited sources / tool
  calls), `roundlog` / `editlog` / `memlog` (the tool-round / edit-diff / memory-grounding rings), `inhist`
  (composer history recall).
- **Spine clients** — `hoosh` (inference, streaming, `/models`), `daimon` (MCP list/call), `agent` (the model-driven
  agentic loop), `memory` (consume **mneme** via daimon — recall/citations/grounding/`/notes` — degrading to the
  local `.thoth/memory` reader).
- **Model tools** — `project` (jailed `read_file`/`list_dir`, default-on), `edit` (jailed `edit`/`create_file`,
  `thoth_edit`-gated), `shell` (`thoth_shell`-gated), `mention` (`@file` expansion), `git` (consumes sit).
- **Presentation ladder** — `ui` + `surface` (the shared, tier-agnostic status **view-model**) drive three
  renderers: line-mode, the **T2 TUI** (`tui` / `feed` / `ftree` / `mdhl` / `diff` / `intr`), and the sovereign
  **T3 desktop GUI** (`src/gui/*`: the `gdraw` IR + `graster` rasterizer + the `gstatus`/`gtree`/`gtool`/`gfeed`/
  `gmem`/`gconv` view-builders + `gwindow`/`gpresent`/`ginput`).
- **Front doors** — the interactive REPL/TUI/GUI plus the one-shot `oneshot` argv path (`thoth 'task'`, `--json`,
  `-o`, `--completion`, `--tier`).

## Tests

`cyrius test` runs the split suites — one binary each, a thin driver over topical `tests/cases/*.cyr`:
`tests/thoth_core.tcyr`, `tests/thoth_gui.tcyr`, `tests/thoth_render.tcyr`. **1675 assertions across the suites as of
0.33.7 (0 failures)** — covering the driver core + command classification, the seam registry, session state + the
multi-conversation store + the persisted message schema (model / citations / tool calls, round-tripped through the
`THOTH-SESSION-2` format), hoosh/daimon request-build + response-extract, t-ron verdicts through the **real vendored
engine** (allow/deny globs, deny-by-default), persona + role, the memory seam (recall/citations/grounding), cross-
conversation `/search`, and the T3 GUI view-builders (draw-command inspection + golden-PPM render). Filesystem-reading
fixtures use **git-tracked** files so CI matches local.

## Next

See [`roadmap.md`](roadmap.md) for the sequencing. **M0–M7 and the entire post-M7 feature arc have shipped
(0.11.x → 0.33.7):** the terminal-citizen front door, the rich TUI, the sovereign **T3 desktop GUI** (`thoth gui`)
with tool-call + colored diff cards and a conversation sidebar, the model **write tools** (`edit`/`create_file`/
`shell` — thoth reads *and writes* code), the **memory arc** (consume mneme: `/remember`, semantic recall,
citations, grounding, `/notes`), and the **chat-management arc** (named multi-conversation store, persistence, the
richer message schema, `/search`). Per-version detail is in the log above + [CHANGELOG](../../CHANGELOG.md).

**The path to v1.0 is dominated by AGNOS lighting up, not by feature work in thoth.** Four gates (see
[`roadmap.md`](roadmap.md) → *Path to v1.0*): (1) the AGNOS lane — **build ✓** (a valid static x86_64-AGNOS ELF,
zero thoth change), **runtime** pends an AGNOS host (= gate 2); (2) ≥1 downstream consumer green on AGNOS
(external); (3) a security review (not scheduled); (4) the SemVer-vs-CalVer 1.0 decision (deferred,
[ADR-0004](../adr/0004-semver-pre-release.md)). x86_64 Linux ships; aarch64 builds; macOS builds+runs (audit path
gated upstream); Windows staged on architectural floor gaps. Full-stack live e2e against the real spine
(hoosh/daimon) is a host-side step — the build sandbox blocks a compiled binary's TCP.
