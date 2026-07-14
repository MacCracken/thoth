# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.35.3] - 2026-07-13

**Persistent per-turn reasoning — a landed turn keeps its thinking fold, not just the in-flight one.**

### Added
- **The GUI reasoning fold (0.35.2) now survives the reply landing.** Before, the fold read the live `_reason_acc`,
  which `_hoosh_acc_reset` wipes at the top of every round — so the thinking fold vanished the moment the answer
  landed (and never appeared on already-scrolled-back turns). Now each answered turn's reasoning is persisted in a
  new **`reasonlog`** ring (`src/reasonlog.cyr`) keyed by the turn tag — the same per-turn-ring pattern as `roundlog`
  (tool cards) and `memlog` (memory strip). `reasonlog_record(turn, text, len)` captures the final round's
  chain-of-thought at each of the three reply-finalize sites (normal, Esc-interrupted, non-agentic), right alongside
  `roundlog_attach_calls_to_last`; `reasonlog_find(turn)` is the newest-wins ring lookup the feed reads on repaint.
- **`greason_build_turn(cmds, x, cy, avail, turn)`** renders a landed turn's fold from `reasonlog`, above that turn's
  tool cards (the model reasons first), keyed by `session_history_turn(i)` — mirroring `gtool_build_turn` /
  `gmem_build_turn` exactly, so an earlier turn's fold stays put above ITS reply as later turns land. The live
  mid-turn fold and the landed fold share one renderer (`_gfeed_reason_at`), so the in-flight → landed handoff is
  seamless and mutually exclusive (no double-render), and **Ctrl+R** still collapses all folds together.
- The ring is bounded (`REASONLOG_CAP = 8`; older turns age out silently) and lazily allocated **only when a model
  actually streams reasoning** — never touched on Opus 4.8 (reasoning stays internal → `len 0` → no record, no
  alloc). Per-slot cap matches the live accumulator (`RSN_TEXT_CAP = 65536`), so a landed fold shows exactly what the
  live fold did — no truncation on landing. Session-scoped like `memlog`/`editlog` (a resumed conversation's messages
  reload as turn 0 → no fold, consistent with tool cards).
- Tests: the `reasonlog` ring (record/find, accessors, untagged/empty/null-text no-ops, newest-wins, aging-out at
  `REASONLOG_CAP`, reset) and the GUI per-turn fold (`test_gui_reason_perturn`: per-turn filtering, measure/draw
  parity, the fold persisting above its reply after later turns land, collapse shrinking it). Suite green
  (1444 core + 107 gui + 3). **Adversarially reviewed** across memory-safety, capture-correctness, and render-parity
  — all clean (worst-case write lands the NUL on the slot's last byte; gap refactor byte-identical to 0.35.2; no
  double-render window).

**NEXT (0.35.x)**: `.4` surface reasoning effort/length in `/state`; consider persisting reasoning into the
conversation store so it survives resume (today it is session-scoped like the memory strip).

## [0.35.2] - 2026-07-13

**Reasoning-effort control + a live thinking fold — thoth can dial the model's reasoning effort and render a model's chain-of-thought as a collapsible GUI fold.**

### Added
- **`[hoosh].reasoning = off | low | medium | high` — a per-config reasoning-effort control.** When set, both request
  builders (`hoosh_build_request`, `agent_build_request`) emit a top-level `"reasoning_effort":"<level>"` field (after
  `max_tokens`, before `stream`); hoosh 2.5.0 translates it to the provider's native effort control (for the
  Anthropic backend, adaptive thinking + `output_config.effort`). Off (the default) emits nothing — the request shape
  is byte-identical to pre-0.35.2, so every existing request-shaping assertion still holds. Parsed by
  `_reasoning_level_from` (only `low`/`medium`/`high` map to 1/2/3; `off`/unknown/absent → 0); surfaced via
  `config_hoosh_reasoning` (0-3) and `config_hoosh_reasoning_effort` (the effort cstring, or 0 when off). This is the
  control that **works today on Opus 4.8**, which raises/lowers effort but keeps the reasoning itself internal.
- **A live "thinking" reasoning fold in the desktop GUI.** When a model exposes its chain-of-thought, hoosh
  translates the provider's native thinking stream into `reasoning_content` SSE deltas; both of thoth's SSE paths now
  parse those (before the content early-return, since reasoning frames carry no content) into a new `_reason_acc`
  accumulator (mirrors `_hoosh_acc`; `hoosh_last_reason`/`_len` accessors). `_gfeed_flow`'s mid-turn block renders it
  as a distinct muted **thinking** block ABOVE the tool cards and partial answer (the model reasons first), growing
  live as the 0.35.0 pump repaints. The fold is **collapsible** — **Ctrl+R** toggles it (`greason_toggle`; the
  preference persists across turns). The reasoning text is transient — reset per turn/round with the reply
  (`_reason_acc_reset` folded into `_hoosh_acc_reset`). **Inert on Opus 4.8**, which keeps reasoning internal
  (`_reason_acc` stays empty → the fold never appears); it lights up automatically on a model that streams reasoning.
- Tests: level mapping (off/low/medium/high/unknown), the effort cstring per level, the request builder emitting
  `reasoning_effort` in the right position when set and omitting it when off, and the `_reason_acc` accumulator
  (append/reset/accessors + reset-via-`_hoosh_acc_reset`). Full suite green (1431 assertions).

**NEXT (0.35.x)**: `.3` persist per-message reasoning so a landed turn keeps its fold (today the fold is live-only);
richer effort surfacing in `/state`.

## [0.35.1] - 2026-07-13

**Live tool-call cards — the GUI shows each tool call as it runs during the round, not only after the turn.**

### Added
- **The desktop GUI now renders the current turn's tool-call cards LIVE during the round.** The bordered cards (name
  · ok/err/deny · ms/bytes · args) were previously drawn only post-turn, above the landed reply. Now, while a turn
  is in flight, `_gfeed_flow`'s `gturn_active` block renders `gtool_build` (the current turn's roundlog cards) above
  the streaming partial — and since each call is recorded in the roundlog as it completes and the 0.35.0 pump
  repaints between calls, **a card grows a row as each tool returns**. `gtool_build == gtool_build_turn(session_turns())`
  — the exact cards the per-message loop draws once the reply lands, so the mid-turn → post-turn handoff is seamless
  (no double-render; the two are mutually exclusive). Zero producer change (the roundlog already recorded live);
  measure/draw parity holds (`gtool_build` is parity-clean and the roundlog is unchanged between the two passes).
  Headless-tested (`test_gui_toolcards_live`: the current turn's card renders during the active turn, and none when
  the turn ran no tools, with parity). The live animation is compositor-gated (verify on Wayland). **NEXT (0.35.x)**:
  `.2` a thinking/reasoning fold rendering `thinking_delta`.

## [0.35.0] - 2026-07-13

**GUI mid-turn pump — the desktop GUI now paints the streaming reply LIVE as it arrives (opens the 0.35.x arc).**

### Added
- **The sovereign Wayland GUI streams the reply live.** A GUI turn runs synchronously (`cmd_task` under `OUT_NULL`),
  blocking the present loop — so until now the window froze on a static "thoth is working…" frame for the whole
  turn, then jumped to the finished reply. Now the model's output appears **word by word as it streams**. The
  mechanism generalizes the 0.34.3 stop-poll: the `_gstop_poll` hook — called on the interrupt seam
  (`intr_check_hook_set`) at each SSE frame / round / tool-call boundary (both streaming paths) — became the **pump**
  (`src/gui/gpresent.cyr`): each call it (a) drains the Wayland fd for the stop key (Esc still aborts), then
  (b) **throttled** (~30fps, reusing the TUI's tested `_stream_should_paint`) and **scanout-race-gated**
  (`gwl_win_ready`) repaints the window. The feed (`src/gui/gfeed.cyr`) renders the growing partial — read straight
  from `_hoosh_acc` (`hoosh_last_reply()`, populated on both SSE paths even under `OUT_NULL`) — as a provisional
  agent bubble (same layout as a landed reply, so the partial→final handoff is seamless), falling back to the
  "working" mark before any content this round (and between tool rounds, when the accumulator resets).
- **Zero producer change**: the pump rides the existing per-frame interrupt-seam checkpoint, so `agent.cyr` /
  `hoosh.cyr` are untouched; the partial render is a pure `gfeed` view over `_hoosh_acc`. Headless-tested
  (`test_gui`: the live partial renders as the agent bubble / the working-mark fallback / measure-draw parity holds
  with the growing partial). The live mid-turn animation is compositor-gated (verify on Wayland). Residual: each
  throttled repaint rebuilds the frame's command list on the no-rewind bump heap (bounded by the throttle for a
  turn; a reused command-buffer pool is the future optimization for very long streams). **Opens the 0.35.x GUI +
  agentic-streaming arc**; next: `.1` live tool-call cards during the round, `.2` a thinking/reasoning fold.

## [0.34.4] - 2026-07-13

**Per-message remember + feedback: `/bookmark` a reply into mneme, `/thumbs` on its recalled notes. Closes the 0.34.x arc.**

### Added
- **`/bookmark`** — save the **last assistant reply** into mneme as a note (the per-message "remember"). Routes
  through the same `memory_append` path as `/remember` (`mneme_create_note` when the memory seam is bound, else the
  local `.thoth/memory` file), under the same `thoth_remember` gate; the reply's first line becomes the note title.
  New `session_last_assistant_content()` (`src/session.cyr`). Degrades honestly (nothing to bookmark / dir absent /
  denied).
- **`/thumbs up` / `/thumbs down`** — feedback on the **last reply's recalled mneme notes**. `up` records that the
  recalled notes were useful via **`mneme_search_feedback`** (through daimon — improves mneme's future ranking);
  `down` is honest that mneme has no negative-feedback tool. To do this, `citations_capture` (`src/memory.cyr`) now
  also parses the recall's **`search_id`** and the first hit's **note id** from mneme's search result (alongside the
  existing title/path), into live state consumed by a new `memory_feedback(search_id, note_id)` marshaller. It rates
  the MOST RECENT recall (live, not per-message); the state is cleared on any no-recall turn, so `/thumbs up` says
  "no recalled mneme notes to rate" when the last reply cited none. Not thoth-gated (a positive read-signal; daimon
  applies its own per-tool policy).

### Fixed
- **`_params_one` (the t-ron gate-params marshaller) is now length-bounded** — an adversarial review of `/bookmark`
  caught it: the built-in gate marshaller escaped its value with an **unbounded** escaper into a fixed 32 KiB
  buffer, safe only because every prior caller passed an input-line-/path-bounded value. `/bookmark` was the first
  to feed it a whole assistant reply (up to 64 KiB), so a long (or escape-dense — code) reply overran the buffer
  → heap corruption, unconditionally before the gate ran. It now uses the cap-bounded escaper (reserving room for
  the closing `"}`), truncating in-buffer instead of overflowing — protecting all callers. Regression-tested (a
  40 KiB value stays under the cap and keeps a valid closer).
- Unit-tested (`test_classify` + `test_rewind` last-reply helper + `test_memory` — the search_id/note-id parse, the
  no-result no-stale guard) and **live-verified** end to end against the full stack: `/remember` a fact →
  a turn recalls it (grounded, cited) → `/bookmark` the reply (mneme vault grew) → `/thumbs up` (mneme returned
  "Feedback recorded"); plus the honest degrades. **This closes the 0.34.x arc** (message actions → stop/interrupt
  TUI+GUI → the empty-schema fix → per-message remember/feedback).

## [0.34.3] - 2026-07-13

**GUI stop affordance — Esc aborts an in-flight turn in the desktop GUI (completes the 0.34.x stop/interrupt work).**

### Added
- **Pressing Esc in the sovereign Wayland GUI now cancels a running turn.** A GUI turn runs synchronously
  (`cmd_task` under `OUT_NULL`), blocking the present loop, so keys pressed during it queue unread. A new stop-poll
  hook (`_gstop_poll`, `src/gui/gpresent.cyr`) — registered as the **0.34.1 front-end-agnostic interrupt seam's**
  poll (`intr_check_hook_set`) and called by `agent_turn`'s `intr_check()` at each stream frame / round / tool-call
  boundary — **non-blockingly** `poll(2)`s the Wayland fd and raises the interrupt flag on the stop key (Esc), so the
  turn aborts between rounds / mid-stream. This is the minimal stop-poll subset of the full mid-turn pump scheduled
  for 0.35.0 (it services input only, no repaint). The two SSE per-frame interrupt polls
  (`_agent_sse_cb`, `hoosh_send`) now route through `intr_check()` so the hook fires during streaming — **the TUI is
  byte-identical** (no hook registered there, so `intr_check` falls to the built-in `intr_poll` stdin drain).
- **An Esc-interrupted GUI turn shows a neutral "- stopped -" notice**, distinct from the red "the turn did not
  complete — is hoosh reachable?" failure notice (a partial that streamed before Esc still becomes the reply, so no
  notice). New `gturn_stop`/`gturn_stopped` state; the empty-history greeting guard excludes it.
- Unit-tested (`test_gui`: the stopped-notice state + its gfeed render + measure/draw parity + the greeting guard;
  the interrupt seam is covered by `test_interrupt`). The live Esc-in-a-window abort is compositor-gated (verify on
  Wayland). **Needs hoosh ≥ 2.4.13** (an interrupted stream would otherwise crash the gateway — see hoosh's SIGPIPE
  fix). **This completes the 0.34.x stop/interrupt work** (`.1` TUI + the seam, `.3` GUI).

## [0.34.2] - 2026-07-13

**Fix: an empty tool `inputSchema` (mneme_*) silently emptied every agentic turn against the full registry.**

### Fixed
- **The agentic loop returned "response had neither tool calls nor content" (streaming) / HTTP 502 (block mode)
  whenever daimon's registry included a tool with an empty `inputSchema`** — which the **`mneme_*`** tools all
  advertise as `{}`. `agent_format_tools` (`src/agent.cyr`) passed that `{}` through verbatim as the OpenAI
  `function.parameters`; Anthropic **requires** every tool's `input_schema` to be `{"type":"object",…}`, so a bare
  `{}` is invalid and — forwarded by hoosh — makes Anthropic reject the **whole** request, which surfaced as an
  empty completion under streaming and a 502 under `stream=false`. So a single mis-advertised tool poisoned the
  entire turn (all 19 registry tools), making the agentic loop unusable against the standard local stack.
  **thoth now falls back to the permissive `{"type":"object"}` whenever a tool's `inputSchema` is absent, empty, or
  lacks a top-level `"type"`** — it never emits an Anthropic-invalid schema regardless of what daimon advertises
  (defense-in-depth; thoth owns the OpenAI request format). Verified **live** end-to-end against the full 22-tool
  registry: `stream=true` → a clean reply (was empty), `stream=false` → a clean reply (was 502). Regression-tested
  (`test_agent`: an empty/typeless `inputSchema` now formats as `{"type":"object"}`, never a bare `{}`).
- **Upstream (the root fix):** **mneme 1.1.1** — mneme's daimon self-registration omitted the tool `inputSchema`
  entirely (sent only name/description/callback_url), so daimon stored `{}`. Fixed at the source: mneme now
  serializes and sends each tool's schema (typed string args + `required`), so daimon advertises real `mneme_*`
  schemas and the model gets typed args. thoth's tolerance above stays as defense-in-depth. (Also surfaced a daimon
  registration-parser quirk — it 400s if `callback_url` follows a nested object; noted for daimon.)

## [0.34.1] - 2026-07-13

**Stop/interrupt through the whole agentic loop — Esc cancels mid-round (tool execution / between rounds), not just streaming.**

### Changed
- **The Esc-abort substrate (`src/intr.cyr`) is now wired through the entire agentic tool-calling loop**, so pressing
  **Esc** in the rich TUI cancels a turn during **tool execution** and **between rounds** — including the
  non-streaming (`stream=false`) block path — not only mid-stream as before (0.17.4). `agent_turn` now arms the
  Esc-poll around each round's tool phase, `_agent_run_calls_serial` polls between tool calls (so a multi-tool round
  stops before running the rest), and a final drain + `intr_pending()` check after the tools stops the loop before
  the next model request. The streaming abort (kind 4) and the new tool-phase abort share one honest landing,
  `_agent_finish_interrupted` — it keeps a streamed partial (appended as the reply) or pops the unanswered user turn,
  so a cancelled turn always leaves history a clean sequence of completed exchanges.
- The t-ron **confirm** reads a line in cooked mode; while the tool phase has the Esc-poll armed, the TUI confirm
  hooks now `intr_suspend()`/`intr_resume()` around it so the y/N read still works (idempotent; a no-op when intr
  wasn't armed, e.g. a `/write` confirm outside a turn).

### Added
- **A front-end-agnostic interrupt seam** so the same agentic-loop checkpoints serve both front-ends: `intr_check()`
  (polls a registered hook or the built-in stdin drain), `intr_check_hook_set()`, `intr_signal()` (raise the flag
  directly — the mechanism a **GUI stop key** plugs into next, 0.34.2), plus `intr_armed()` and the
  `intr_suspend`/`intr_resume` pair. Unit-tested (the seam: signal/check/pending/hook/suspend-resume; and the
  interrupt landing `_agent_finish_interrupted` — keep-partial vs pop) and **adversarially reviewed — 0 defects**
  across arm/disarm balance, the confirm suspend/resume (serial *and* parallel executor), the once-per-turn flag
  lifecycle, the final-drain ordering, history integrity, and the off-TUI floor. **TUI-only and OUT_RING-gated** —
  the REPL/piped/one-shot floor never touches the terminal and stays byte-identical. The mid-turn Esc delivery
  reuses the exact `intr_arm`/`intr_poll`/`intr_disarm` mechanism of the shipped 0.17.4 streaming interrupt (final
  end-to-end confirmation is a human Esc on a real terminal — a headless pty cannot inject a mid-turn keystroke, the
  same limitation the pre-existing streaming interrupt has).
- **Note (accepted edge):** while the tool phase is armed, a *type-ahead* answer to a t-ron confirm (typed before
  the prompt paints) is drained with the other mid-turn keystrokes and must be retyped at the prompt — consistent
  with intr's "mid-turn keystrokes don't leak into the composer" rule, and arguably safer (no blind pre-approval of
  a gated action). The normal wait-then-answer flow is unaffected.

## [0.34.0] - 2026-07-13

**Message actions — `/retry` (regenerate) + `/edit` (edit-last): rewind the last turn and re-run. Opens the 0.34.x arc.**

### Added
- **`/retry`** (alias **`/regenerate`**) — re-run your last message for a fresh reply. It rewinds the last turn
  (drops the prior reply and its user echo) and re-runs the **exact stored prompt** — which is already
  `@mention`-expanded, so it is deliberately **not** put through `mention_expand` again (that would double-inject
  the attached file blocks). On-brand for thoth's mid-session model switching: `/model` then `/retry` re-answers the
  same prompt with a different backing model.
- **`/edit <new text>`** — replace your last message with new text and re-run the turn. It rewinds the last turn,
  then runs the new text through the normal task path, so fresh `@mentions` in the edit expand as usual.
- Both are **history-safe, and non-destructive on failure**. Each refuses (with an honest note) **without
  rewinding** when there is nothing to act on (empty conversation) or when the hoosh seam is absent. And crucially,
  the rewind is **snapshotted** (the removed messages *and* the conversation title): after the re-run,
  `session_rewind_settle()` **commits** the rewind only if a fresh assistant reply actually landed for the turn;
  otherwise — a transport/HTTP error, an empty completion, or a stateless non-recording turn — it **restores** the
  prior exchange byte-for-byte, so a failed `/retry` never loses the previous reply *or* the user's prompt. New pure
  session helpers back this (`src/session.cyr`): `session_last_user_index`, `session_rewind_to_last_user` (returns
  the last user message's stable, never-freed content for the verbatim re-run), `session_history_last_is_reply_for`
  (length-independent, so it stays correct at the `SESS_HIST_MAX` eviction cap), `session_rewind_restore`, and
  `session_rewind_settle`. `cmd_task`'s turn core was factored into a shared `_task_dispatch(prompt)`
  (byte-identical to the previous inline flow) so `/retry` can re-run the stored prompt without re-echoing or
  re-expanding.
- **Scope**: TUI / line-REPL commands (like `/new`, `/switch`, `/search`) — the GUI composer runs `cmd_task`
  directly and does not route slash-commands through `dispatch` yet, so GUI affordances for these ride the 0.34.x
  GUI work (a follow-up captured in the roadmap). Unit-tested (`test_rewind` — the rewind/restore/commit paths + a
  title-restore-on-rollback case + the classification asserts; `cyrius test` green: 1389 core assertions), **adversarially
  reviewed** (a multi-lens find→verify pass caught two real history-loss hazards — a stateless-mode loss and a
  transport-failure loss — which the snapshot/restore design above fixes; the re-review confirmed the mechanism
  sound), and **live-verified** end-to-end against a real hoosh: a turn → `/retry` reproduces the reply → `/edit`
  replaces it, the conversation staying two messages throughout (no doubling); and a `/retry` against a **killed
  hoosh** (transport failure) **restores** the resumed exchange instead of losing it.

## [0.33.7] - 2026-07-13

**Cross-conversation `/search` — find text across every conversation. Closes the 0.33.x chat-management arc.**

### Added
- **`/search <text>`** (`src/commands.cyr`) — a case-insensitive substring search over every message of every
  conversation in the store, listing matches grouped by conversation (the `*` active marker + 1-based number +
  title, then each matching message's role + a context snippet with the match highlighted), with a footer count and
  a `/switch <n>` hint. Distinct from `/find` (the TUI in-buffer feed search) — `/search` spans the whole persisted
  store and works in any mode. Snippets flatten control bytes and cap context, and the result list caps at 60
  matches. Unit-tested (the case-insensitive finder + classification) and live-verified across a multi-conversation
  store (found/case-insensitive/no-match). **This closes the 0.33.x arc**: multi-conversation store → commands →
  persistence → richer message schema (model/citations/tool calls) → GUI sidebar → cross-conversation search.

## [0.33.6] - 2026-07-13

**GUI conversation sidebar — a left pane to see and switch conversations in the desktop window.**

### Added
- **A conversation sidebar in the desktop GUI** (`src/gui/gconv.cyr`) — a left pane over the `conv_*` store listing
  each conversation (title + a "N msg" subline), the active one marked with an accent bar and accent title. It is
  **keyboard-driven**: **Ctrl+K** toggles it (hidden by default, since the store is one conversation until `/new`);
  **Tab** now cycles focus composer → file-tree → conversations (skipping any hidden/empty pane); when the sidebar is
  focused, **↑/↓** move the selection and **Enter** switches to it (and snaps the feed to that conversation's newest
  message). Revealing preselects the active conversation. Mirrors the file-tree pane's structure, palette, and
  scroll math, so it inherits the amber theme and `/theme` toggle. The `gframe_build` body band now lays out an
  accumulating left band (conversation pane, then file-tree pane, then feed); with the sidebar hidden the layout is
  byte-identical to before. Headless-tested (width, scroll, render — titles + active marker, keyboard nav, full-frame
  layout) and confirmed by a rendered golden frame.

## [0.33.5] - 2026-07-13

**Per-message tool calls — a resumed conversation keeps its tool cards. Completes the richer persisted message schema.**

### Added
- **Each reply now carries the tool calls it produced** (`src/session.cyr`) — name, arg summary, gate kind
  (allow/deny), and ok/error — snapshotted from the roundlog onto the message and persisted so they survive a
  restart. The live capture (`roundlog_attach_calls_to_last`, `src/roundlog.cyr`) matches the turn's rounds to the
  just-appended reply; idempotent (clear + re-add), so the multiple assistant-append paths can't double-count. New
  accessors `session_history_tool_count(i)` / `session_history_tool_{name,args,kind,ok}(i, j)`.
- **Persisted as trailing `TOOL\t<len>\n<kind>\t<ok>\t<name>\t<args>\n` frames** in the `THOTH-SESSION-2` format —
  the same unified frame as `CONV`/`CITE`/records, dispatched by token, written right after the reply (and its CITE
  frames) so they re-attach to the correct message on load. name/args are stored pre-flattened of tabs/newlines, so
  the tab-delimited payload always splits unambiguously; a malformed frame is a safe no-op. `/save` now lists each
  reply's `_tools:_` (with `(denied)`/`(error)` markers). Unit-tested (round-trip beside the model + citations,
  idempotent re-attach) and live-verified both ways with the real binary. **With this the richer persisted message
  schema is complete: a resumed conversation carries role + text + model + cited sources + tool calls.**

## [0.33.4] - 2026-07-13

**Per-message citations — a resumed conversation keeps the sources each reply recalled.**

### Added
- **Each reply now carries the recalled-source titles it cited** (`src/session.cyr`), persisted so they survive a
  restart. The message struct gains a lazily-alloc'd citation set; the live capture (`citations_attach_to_last`,
  `src/memory.cyr`) snapshots the turn's recalled titles onto the just-appended reply — idempotent (clear + re-add),
  so the multiple assistant-append paths can't double-count. Only the title is stored (the path is captured but
  never surfaced). New accessors `session_history_citation_count(i)` / `session_history_citation_title(i, j)`.
- **Persisted as trailing `CITE\t<title_len>\n<title>\n` frames** in the `THOTH-SESSION-2` format — the same unified
  frame as `CONV`/records, dispatched by token, written right after the reply they belong to so they re-attach to
  the correct message on load. Titles are flattened (tab/newline → space) so a frame is always unambiguous, and an
  orphan `CITE` before any record is a safe no-op (never spawns a spurious conversation). `/save` now lists each
  reply's `_recalled sources:_`. Unit-tested (round-trip beside the model field, idempotent re-attach, the
  orphan-CITE guard) and live-verified both ways with the real binary.

## [0.33.3] - 2026-07-13

**Per-message model attribution — a resumed conversation remembers which model wrote each reply.**

### Added
- **Each assistant reply now carries the model that produced it** (`src/session.cyr`). The message struct grows a
  per-message model field, auto-captured from the active session model when a reply is appended, and — crucially —
  stored as its **own stable copy**, not an alias of the shared session model buffer (which a mid-session `/model`
  switch overwrites, and would otherwise retroactively rewrite every earlier reply's attribution). New accessor
  `session_history_model(i)`. On-brand for thoth's signature move: switch models mid-session and a resumed
  conversation still shows who said what.
- **The model is persisted** in the `THOTH-SESSION-2` format. A record extends cleanly to an optional field —
  `<role>\t<len>\t<model>\n<content>\n` when a model is present, the previous `<role>\t<len>\n<content>\n` when not —
  so it stays backward-readable (a modelless record parses exactly as before) and the model is written directly to
  the file, never through the fixed 64-byte header buffer. `/save` now annotates each reply's header with its model
  (`## assistant (claude-opus-4-8)`). Unit-tested (capture, stability across a switch, round-trip, the no-model case)
  and live-verified both ways with the real binary (a model-tagged resume surfaces through `/save`; a live save
  re-emits the model field).

## [0.33.2] - 2026-07-12

**Multi-conversation persistence — every conversation survives a restart, not just the active one.**

### Changed
- **`[session].file` now persists the whole store** (`src/session.cyr`). A new **`THOTH-SESSION-2`** on-disk format
  frames every conversation: a magic line carrying the active index, then per conversation a `CONV\t<title_len>\n
  <title>\n` header followed by that conversation's message records (the same `<role>\t<len>\n<content>\n` frame as
  before). On resume, the full store — titles, per-conversation messages, and the active conversation — is rebuilt;
  previously only the active conversation persisted (as `THOTH-SESSION-1`). **Old `THOTH-SESSION-1` files still load**
  (into the default conversation) — the reader dispatches on the magic line, so an existing session resumes unchanged.
- The parser is hardened against a corrupt/hostile file the same way the v1 reader is — every length is bounds-checked
  before any pointer arithmetic (a non-numeric, negative-overflowed, or over-large length stops the parse; a payload
  that does not fit is refused), so a bad file degrades to "load what parsed" and never an out-of-bounds read.
  Titles are copied out of the reused parse buffer (capped at 128 bytes). The resumed-count greeting now reports the
  total across all conversations.

### Fixed
- **Auto-title round-trip fidelity** (adversarial-review catch). A newline-leading first user message derived a blank
  `""` title, which persisted as a zero-length `CONV` header — indistinguishable from *untitled* on reload, so the
  conversation re-derived its title from a different surviving message. `_conv_autotitle` now returns *untitled*
  (`0`) for an empty first line (deferring the title to a later message) instead of committing a blank label, so a
  non-empty title always survives the round-trip exactly and a blank title never exists to be lost.

### Added
- Store helpers `conv_load_begin`/`conv_load_add` (rebuild the store from a file) and `session_total_messages`.
  Unit-tested with a real multi-conversation file round-trip (two conversations, an explicit title, an auto-title,
  message isolation, active-index restore, v1 back-compat) and live-verified end-to-end (resume restores both
  conversations with the `*` on the saved-active one; a live save rewrites a valid v2 file that re-resumes exactly,
  including an emptied conversation). Toolchain pin `6.4.58`→`6.4.62`.

## [0.33.1] - 2026-07-12

**Conversation commands — list, create, switch, rename, delete named conversations.**

### Added
- **`/conversations`** (alias `/convos`) — list conversations with a `*` active marker, title, and message count.
- **`/new [title]`** — start a new conversation (optionally titled) and make it active.
- **`/switch <n>`** — switch to conversation `n` (1-based, as listed).
- **`/rename <title>`** — rename the current conversation.
- **`/delete <n>`** — delete conversation `n` (never the last; the active index is fixed up).
- **Auto-title** — an untitled conversation takes its title from its first user message (first line, ≤48 chars).
  All over the 0.33.0 `conv_*` store (in-memory; multi-conversation *persistence* is 0.33.2 — only the active
  conversation persists today). New `conv_delete` (with active-index fixup) + `conv_dup_title`. Unit-tested
  (auto-title, delete + fixup, refuse-last, command classification) and live-verified end-to-end (no model needed).

**Multi-conversation store — the structural foundation for named, switchable conversations (opens the 0.33.x arc).**

### Changed
- **Conversation store** (`src/session.cyr`). The single linear message thread is now the ACTIVE conversation of a
  keyed store: `_conv_store` holds conversation structs (id, title, created/updated timestamps, own message vec),
  `_conv_active` indexes the active one. Every history op (`session_history_len`/`_role`/`_content`/`_turn`/
  `_append`/`_pop_last`/`_clear`) routes through `_sess_hist_vec()` → the active conversation, so every consumer
  (agent, hoosh, `[session].file` persistence, the GUI feed) is unchanged and one conversation persists exactly as
  before. New `conv_*` API — `conv_count`/`conv_active`/`conv_new`/`conv_switch`/`conv_id`/`conv_title`/
  `conv_created`/`conv_updated`/`conv_set_title`/`conv_touch` — ready for the switching commands. `_conv_at` clamps
  its index so no accessor can hit `vec_get`'s abort-on-OOB (a crash-safe floor beneath the 0.33.1 commands). The
  store is unit-tested (message isolation across conversations, switch round-trip, reset). Switching **commands**
  (`/conversations`, `/new`, `/switch`, `/rename`, `/delete`, auto-title), a GUI **sidebar**, cross-conversation
  **search**, and multi-conversation **persistence** land next in 0.33.x; a resumed conversation still loses its
  ephemeral tool-card/citation rings (not yet persisted) — a richer persisted message schema rides that work.

## [0.32.6] - 2026-07-12

**Notebook mode — search your mneme knowledge base directly (`/notes`) — closing the 0.32.x memory arc.**

### Added
- **`/notes <query>`** — search the mneme vault on demand, the counterpart to per-turn recall (memory as a
  browsable destination, not just injected into a turn). A read via daimon's `mneme_search`
  (`memory_notebook_search`, `src/memory.cyr`, browse limit 10); needs the memory seam bound (daimon hosts
  `mneme_*`), else it degrades with an honest note. Displays mneme's formatted result verbatim — thoth consumes the
  domain, it does not re-rank (ADR-0012). Live-verified end-to-end (no model turn needed): a query surfaces the
  matching notes; a different phrasing semantically matches a different note. This completes the memory arc — write
  (`/remember`), recall-in-loop (semantic injection + citations + grounding + GUI strip), and now browse (`/notes`).

**GUI memory surfacing — the recalled sources + grounding verdict now show in the desktop GUI feed.**

### Added
- **GUI memory strip.** The line/TUI recalled-sources + grounding lines are `ui_emit` and thus lost under the GUI
  turn's `OUT_NULL`, so this renders the same info in the feed from persisted state. A new **`memlog`** ring
  (`src/memlog.cyr`) records each answered turn's recalled source titles + grounding verdict (written from
  `grounding_emit`, which runs in every turn path); a new **`gmem`** feed element (`src/gui/gmem.cyr`) draws a
  two-row strip above each turn's reply — the recalled sources (`recalled: [1] Title  [2] Title`) and the colored
  grounding verdict (green/amber/red) — matched by the message's turn tag, exactly how the tool-call cards
  interleave (`gtool`). Bounded ring (last 16 turns); cleared by `/reset`. The ring is unit-tested
  (record/find/accessors/edge cases); `gmem` is a fixed-height element reusing the proven card helpers.

**Grounding indicator — after a recall, is the reply actually grounded in the sources?**

### Added
- **Grounding indicator** (`src/memory.cyr`). When a turn recalled memory, thoth scans its OWN reply for `[N]`
  citations and compares them to the recalled source count — an honest, checkable signal (thoth parses its reply,
  never mneme's domain). A colored line follows the reply (line/TUI; GUI rides the feed work): **green** `grounded
  (X of M source(s) cited)` when valid citations are present; **amber** `unverified (M source(s) recalled, none
  cited)` when sources were available but uncited; **red** `ungrounded (cited a source beyond the M recalled)` when
  a citation points past the recalled sources (likely fabricated). Only a **tight `[N]` band** counts — `[1..M]`
  valid, `[M+1..M+3]` a likely fabrication, everything else (e.g. `arr[15]` in code) ignored — to avoid false
  alarms. Wired at both turn-completion sites (`hoosh_send` + `agent_turn`); silent when no recall happened. The
  verdict logic is unit-tested (all four states + the code-index false-positive case); the rendered line was
  verified against canned replies (green/amber/red all correct).

**Citations — the sources behind a recall are captured, cited, and shown.**

### Added
- **Citations for mneme recall** (`src/memory.cyr`). The recalled context is injected into the MODEL's turn and
  never shown to the user, so citations close the loop: (1) the injected recall now instructs the model to **cite a
  used source inline as `[N]`** (mneme already numbers the hits); (2) thoth captures each recalled note's **title +
  path** — a light, DEFENSIVE parse of mneme's numbered result (`citations_capture`; if the format doesn't match,
  nothing is captured and recall still works); (3) a **"recalled N note(s) from mneme: [1] Title [2] Title"** line
  is shown when recall fires (line/TUI). Presentation only — retrieval/ranking stays mneme's (ADR-0012). GUI
  surfacing rides the feed work (the GUI turn runs under `OUT_NULL`). Live-verified end-to-end against a real mneme.

### Fixed
- A citations-parser crash caught during bring-up: thoth's `strstr` returns an **index** (`-1` when not found), not
  a pointer/0 — the first draft treated the return as a pointer and SIGSEGV'd on a real result (and, being a crash,
  slipped past the unit test as a non-`FAIL`). The parser now uses correct index arithmetic; the tests now exercise
  it (they genuinely run rather than crashing).

## [0.32.2] - 2026-07-12

**Semantic recall via mneme — a turn's memory context is now a live `mneme_search` keyed on the turn, when the seam is bound.**

### Added
- **Recall via mneme.** `memory_context(query)` (`src/memory.cyr`): when `[memory].enabled` and the memory seam
  is bound (daimon hosts `mneme_*`), recall is a per-turn `mneme_search(query, limit=5)` via `daimon_invoke`, whose
  hits are injected verbatim as the memory system message — the semantic upgrade over the static local reader.
  thoth stays a CONSUMER: it sends the turn's text as the query and injects mneme's result text opaquely (no
  ranking/parsing). On any failure (transport, tool error, empty result) it falls back to the local
  `.thoth/memory` reader. The turn query is threaded through the live sites (`agent_turn`/`hoosh_send` pass the
  prompt); **`/dry` passes `0`** so it stays network-free (it previews the local memory; the live turn resolves
  mneme recall at send). Live-verified end-to-end against a real mneme (a seeded note surfaced in the turn's
  request body, keyed on a matching query).

**GUI pane toggles — hide the file-tree and status chrome so the conversation feed can take the whole window.**

### Added
- **GUI pane toggles.** Two control chords hide/show the desktop GUI's chrome: **Ctrl+B** toggles the file-tree
  pane, **Ctrl+S** the status strip. The conversation feed reclaims the freed space (`gframe_build` reads the
  visibility state for layout); focus never sticks on a hidden pane (hiding the focused tree returns focus to the
  composer, and Tab won't select a hidden tree); an unbound `Ctrl+<letter>` is swallowed, never typed into the
  composer. Keybindings are **provisional** — the cross-platform modifier chord may change — so the mapping lives
  in one place (`gkey`, `src/gui/ginput.cyr`). Headless-tested (state machine + focus handling + chord routing).

### Changed
- **Toolchain pin `6.4.57` → `6.4.58`** (latest; the 6.4.58 batch also finished out the Windows atomic-write
  path). Vendored `lib/` refreshed via `cyrius lib sync`.

## [0.32.0] - 2026-07-12

**The mneme memory seam — thoth consumes mneme (the AGNOS memory/RAG domain, now Cyrius-ported) through
daimon's MCP registry, never forking retrieval (ADR-0012) — plus crash-safe atomic file writes.**

### Added
- **mneme memory seam.** `SEAM_MEMORY` now binds **REMOTE** when daimon's registry advertises mneme's tools
  (a cached `mneme_*` probe, `src/daimon.cyr`: `daimon_mem_bound`/`daimon_mem_scan`/`daimon_mem_probe` — a PURE
  cache read for `seam_status`, primed for free off the existing agent tool-fetch, so `/dry` stays network-free).
  `/remember` and the `memory_write` tool route the fact to **`mneme_create_note`** via `daimon_invoke` when bound,
  and fall back to the local `.thoth/memory` flat file when not — a producer swap behind the existing
  `memory_append` choke point. `/state`'s memory row reflects the binding (`mneme` vs `local … (mneme not hosted by
  daimon)`). Live-verified both ways against a real daimon (degrade + bound via daimon's external tool registration).
  Recall-via-mneme (query-keyed semantic injection) is the next cut; recall stays the local reader here.

### Changed
- **Crash-safe atomic edit/create writes** (closes the ADR-0017 non-atomic residual, via **cyrius 6.4.57**).
  `edit`'s `_edit_do` swaps `file_write_all` → **`file_write_atomic`** (unique temp → loop-write → fsync → atomic
  rename; the original file is left intact on ANY failure — no more O_TRUNC truncation on a short write).
  `create_file`'s `_write_do` swaps the `file_exists`+`O_EXCL` open → **`file_create_exclusive`** (portable
  no-clobber; the per-target handling now lives in the stdlib).
- **Toolchain pin `6.4.51` → `6.4.57`**; vendored `lib/` refreshed via `cyrius lib sync` (pulls the stdlib
  atomic-write primitives + the 6.4.52–57 f32/allocator fixes).

## [0.31.5] - 2026-07-12

**A non-2xx daimon HTTP response is now recorded as a failed tool call** (the 0.30.18 loose end). The agentic
loop's tool executors read the tool result but **ignored the HTTP status** — so a non-2xx response (server error,
unknown tool, bad request) whose body happened to carry MCP text without an `isError` field was recorded as a
*successful* tool result (green `ok` on the card). Now both executors treat a non-2xx as a failure: `rl_ok=0`,
and the model sees daimon's error text if present, else a synthetic `(tool call failed: daimon returned HTTP
<status>)`. Hardened **symmetrically** across the serial (`daimon_invoke`) and parallel (`daimon_fetch_into` →
phase-3) paths.

### Fixed
- `daimon_invoke` (`src/daimon.cyr`) now checks `sandhi_http_status`; non-2xx → `_daimon_last_is_error=1` +
  daimon's error text or `_daimon_http_err(status)`. `daimon_fetch_into` gained a `status`-out param (stashed at
  the worker `ctx+56`, `PAR_CTX_SZ` 56→64); the parallel phase-3 reads it and mirrors the serial handling. Matches
  what `daimon_call` (`/call`) already did. Review residuals folded in: the synthetic-message buffer is `alloc(80)`
  (was a zero-headroom 64), and an *empty* error-body text falls through to the synthetic HTTP message.

### Verified
- 1502 assertions (`test_daimon` +2: `_daimon_http_err` formats the status). **Live** end-to-end: an unknown tool
  returns HTTP 400 → `daimon_invoke` now yields `is_error=1` + `(tool call failed: daimon returned HTTP 400)` →
  the loop records `rl_ok=0` (was a vague "no result" with an ambiguous status). Adversarially reviewed. Pin
  **6.4.51** (wrapper 6.4.56).

## [0.31.4] - 2026-07-12

**Cleaner `edit`/`create_file` arg on the diff card.** Now that the colored diff renders below an `edit`/
`create_file` call, the raw JSON args line (`{"path":"…","old_string":"…","new_string":"…"}`) above it was
redundant noise. The card now shows just the **clean path** in the blue "paths" colour for any call that has an
`editlog` entry (i.e. an edit/create) — `edit ok 12ms/40B src/x.cyr`, not the JSON. Other tools (`shell`, MCP)
keep their raw args (faint). Reuses the `editlog_find` lookup the diff already does (`editlog_path`), so no JSON
parsing at paint. Draw-only — the card height (and the feed measure/draw parity) is unchanged.

### Changed
- `src/gui/gtool.cyr` — `_gtool_card` hoists the per-call `editlog_find`; when matched it draws `editlog_path` in
  `ROLE_BLUE` instead of `roundlog_call_args`. `test_gui_toolcards_diff` +2 (the clean path is drawn blue; the raw
  JSON args are not).

### Verified
- 1500 assertions + main builds + PPM eyeballed (`edit ok 12ms/40B src/x.cyr` over `- OLD`/`+ NEW`). Pin
  **6.4.51** (wrapper 6.4.55).

### Notes
- Filed the atomic-write need as a cyrius issue (`docs/development/issues/2026-07-12-thoth-portable-atomic-file-write.md`
  in the cyrius repo): a portable `file_rename`/`file_write_atomic` + AGNOS `O_EXCL`, so `edit`/`create_file` (and
  `/write`) can be crash-safe. Remaining thoth follow-up: the `daimon_invoke` HTTP-status hardening (from 0.30.18).

## [0.31.3] - 2026-07-12

**`create_file` — the model can make NEW files.** The create half of the write capability, completing the edit
tool: **`create_file(path, content)`** ([ADR-0017](docs/adr/0017-model-edit-tool-jailed-gated-opt-in.md)) writes a
brand-new file. **CREATE-ONLY** — it **refuses if the file already exists** (no blind-clobber; modifying an
existing file stays `edit`'s surgical, diff-producing job). Same envelope as `edit`: opt-in `[edit].enabled`,
jailed cwd-only (`_project_jail_ok`), gated under the same `thoth_edit` verb, local + forced-serial. It feeds
`editlog` with `old=""`, so a new file renders on its tool-card as **all-green additions** for free.

### Added
- `src/edit.cyr` — `create_file_tool` + `_write_do` (create-to-disk) + `_write_summary`, sharing the `_edit_*`
  buffers/state + `editlog` recording with `edit`. `agent.cyr` advertises `create_file` (opt-in), forces it
  serial, and dispatches it. `edit`'s file-not-found message now points at `create_file`.

### Fixed (from the review, before first ship)
- The no-clobber guard used `file_exists` — but that's an `O_RDONLY` *readability* probe, so a
  writable-but-**unreadable** existing file (mode `0200`, e.g. a secret key) read as absent and would have been
  truncated by `file_write_all`'s `O_TRUNC`, violating the create-only contract. The create now opens with
  `O_WRONLY|O_CREAT|O_EXCL` — the kernel refuses if the path exists regardless of read permission (and refuses to
  follow a trailing symlink). The `file_exists` pre-check is kept for the friendly message and as the AGNOS guard
  (AGNOS has no exclusive-create bit, so `O_EXCL` degrades there).

### Verified
- 1498 assertions (`test_edit` +16: create-to-disk via `_write_do`, refuse-if-exists no-clobber, empty-file,
  parse + jail refusals, and a **write-only-file no-clobber regression** — `sys_chmod 0200` then confirm the file
  is refused + untouched). **Live** end-to-end: gated `create_file` → `+2 -0` all-add editlog → file on disk →
  a second create on the same path refused. Adversarially reviewed (safety/wiring → SHIP after the fix). Pin
  **6.4.51** (wrapper 6.4.55).

### Notes
- Create-only by design (no wholesale overwrite of existing files — that would be a clobber surface). Shares
  `edit`'s residuals (non-atomic write; symlink-inside-project followed for an *existing* external target).
  Remaining follow-ups: cleaner edit-arg display on the card; the `daimon_invoke` HTTP-status hardening; atomic
  writes (needs a stdlib `xrename`).

## [0.31.2] - 2026-07-12

**Colored diff cards in the GUI feed — the payoff of the whole tool-card + edit-tool arc.** When the model
`edit`s a file, its tool-call card now shows the change: the stored `editlog` diff renders below the `edit`
call's line — **deleted lines RED (`- …`), added lines GREEN (`+ …`)** — sourced from thoth's own edits. The
render half: `_gtool_card` (`src/gui/gtool.cyr`) looks up `editlog_find(turn, round, call)` for each call and, on
a match, draws the stored del/add lines (clipped to the card width; a faint `… more changed lines` /
`(diff too large to show)` note when truncated). Read-only over `editlog`'s accessors — no LCS recompute at paint.
The diff rows are folded into the card-height computation through a single `_gtool_call_diff_rows` helper used by
BOTH the measure and draw passes, so the feed's measure/draw parity (and its bottom-anchor) is preserved.

### Added
- `src/gui/gtool.cyr` — `_gtool_call_diff_rows` + `_gtool_draw_diff`; `_gtool_card` grows per-edit. `editlog.cyr`
  added to the LEAN `thoth_gui.tcyr`. `test_gui_toolcards_diff` (+5): measure/draw parity with the taller card,
  del=red / add=green line rendering, the diff grows the card height. A `/tmp/thoth_gui_diffcard.ppm` artifact.

### Verified
- 1482 assertions + main builds + PPM eyeballed (`edit ok … {"path":"src/x.cyr"}` with `- OLD` red / `+ NEW`
  green below it). Adversarially reviewed (parity/attribution). Pin **6.4.51** (wrapper 6.4.55).

### Notes
- Completes the colored-diffs arc (0.30.16 cards → 0.30.17 args → 0.30.18 isError → 0.30.19 per-turn → 0.31.0
  edit tool → 0.31.1 editlog → **0.31.2 diff card**). Remaining edit-tool follow-ups: create-new-file support; a
  cleaner edit-arg display on the call line; the `daimon_invoke` HTTP-status hardening.

## [0.31.1] - 2026-07-12

**`editlog` — record each `edit`'s diff, for the colored diff card (0.31.2).** The producer half of the
colored-diffs arc: `src/editlog.cyr` is a session ring of the model `edit` tool's recent changes, keyed by
`(turn, round, call)` to align with `roundlog`. On each applied edit it computes the line diff **once** (sit's
escape-free `compute_file_diff`) and stores the **changed lines** (del/add) — so the GUI card (0.31.2) can render
by walking stored lines and **never recompute the LCS on a repaint** (which would grow the bump heap every
frame). Bounded: last 16 edits, ≤48 changed lines each (≤200 B/line, control→space, trailing newline stripped),
all adds/dels counted even past the store cap; an edit over the LCS cap records path + counts with no hunk.

### Added
- `src/editlog.cyr` — `editlog_record` + `editlog_find`/`_path`/`_adds`/`_dels`/`_nlines`/`_truncated`/`_line_kind`/
  `_line_text` + `editlog_reset` (wired into `/reset`). `roundlog_cur_round()` (so the edit dispatch keys its
  entry without threading `round_no`). `edit.cyr` stashes the last edit's path + old/new (`edit_last_path`/`_old`/
  `_old_len`/`_new`/`_new_len`) for the dispatch to hand to `editlog_record` right after a successful edit.

### Verified
- 1477 assertions (`test_editlog` +27: single-line change / pure-delete / no-op / truncation-past-cap /
  ring-eviction / find-by-key, del+add kinds + newline-stripped text). **Live** integration: ran a real gated
  `edit` then recorded it — `editlog_find` returns the entry with `+1 -1` and the exact `-` / `+` lines
  (indentation preserved). Adversarially reviewed. Pin **6.4.51** (wrapper 6.4.55).

## [0.31.0] - 2026-07-12

**thoth can now WRITE code — a first-class model-invokable `edit` tool ([ADR-0017](docs/adr/0017-model-edit-tool-jailed-gated-opt-in.md)).**
The symmetric completion of the read tools (ADR-0015): the model could read the project but only change it by
shelling out to `sed`/`cat` (clumsy, unobservable). Now **`edit(path, old_string, new_string)`** does a surgical
replacement of the **unique** occurrence of `old_string` and applies it to disk. It is the foundation of the
"colored diffs in the feed" arc (0.31.1 records the diff; 0.31.2 renders it).

Safety — it degrades **closed** at every layer (writing model-controlled input is consequential):
- **Surgical + unique-match**: 0 matches → not-found, >1 → not-unique — **refused, never applied** (the model
  must give enough context to name one site; it cannot blind-clobber). Empty `old_string` refused; empty
  `new_string` = a deletion. Pure core `_edit_apply`, exhaustively unit-tested.
- **Opt-in** `[edit].enabled` (default **off**, like `[shell].enabled`) — advertised only when enabled;
  advertise-gate ⇔ dispatch-gate in lockstep (a hallucinated `edit` while off returns an honest not-enabled
  string, never forwarded to daimon).
- **Jailed** cwd-only via `_project_jail_ok` (relative only; no absolute/`~`/`..`) — deliberately **not**
  `_project_read_ok`, so a write can never follow the user's read-only `/allow` grants.
- **Gated** under a **distinct `thoth_edit`** t-ron verb (kept separate from `/write`'s `thoth_write` so a
  policy can allow the operator's `/write` yet deny model edits); an absent policy falls to the fail-closed
  confirm. Local + forced-serial (never the parallel/daimon path).

### Added
- `src/edit.cyr` — `edit_tool` + the pure `_edit_apply` core + `_edit_do` (apply-to-disk) + `edit_last_allowed`/
  `edit_last_ok`. `[edit].enabled` config (`config_edit_enabled`). `thoth_edit` reserved gate verb.
  [ADR-0017](docs/adr/0017-model-edit-tool-jailed-gated-opt-in.md).

### Verified
- 1450 assertions (`test_edit` +28: surgical match/unique/not-found/delete/bounds/no-OOB, real-file
  read-modify-write via `_edit_do`, parse + jail refusals, and a long-path summary-buffer regression). **Live**
  end-to-end: drove the full gated path against a real t-ron allow-policy — parse → jail → t-ron VK_ALLOW →
  surgical apply → `file_write_all` → file changed on disk (`+1 -1 lines`). Adversarially reviewed
  (safety/core/wiring → SHIP after two fixes, below). Pin **6.4.51** (wrapper 6.4.55).

### Fixed (from the review, before first ship)
- `_edit_puti` handed `fmt_int_buf` a mid-buffer destination with only 12 B of headroom, but `fmt_int_buf` writes
  a **fixed 24 B scratch window** — a ~1000 B relative path could overflow the summary buffer by up to 11 B. Now
  formats into a dedicated stack scratch, appended with the per-byte-bounded copy.
- The disk write now requires the **full** byte count (`wr != newlen` → honest failure, roundlog `err`) instead
  of only rejecting `wr < 0`, so a short write (disk-full) is never reported as a successful edit.

### Notes
- Edits **existing** files only (create is a deliberate follow-up). Residuals (honest, ADR-0017): the write is
  **non-atomic** — `O_TRUNC` empties the file before writing, so a short write leaves it truncated (a crash-safe
  temp-file+`rename` needs a portable `xrename` the stdlib lacks; a follow-up that would also harden `/write`); a
  symlink *inside* the project pointing outside is followed (no portable `O_NOFOLLOW`). The jail is a boundary,
  not a sandbox.

## [0.30.19] - 2026-07-12

**Tool-call cards now render PER-TURN — an earlier turn keeps its cards when you ask a follow-up.** 0.30.16–.18
carded only the CURRENT turn, so a turn's tool cards vanished the moment you sent the next message. Now each
turn's cards sit above ITS OWN reply, throughout the scrollback. Mechanism: each `session_history` message is
tagged with its turn (`session_turns()` at append time — the struct grew 16→24 B, `session_history_turn(i)`
accessor); the feed (`gfeed._gfeed_flow`) renders `gtool_build_turn(..., session_history_turn(i))` above EVERY
assistant message (was restricted to the last one). The turn tag is **in-memory only** — the `[session].file`
format is byte-unchanged (`_sess_write_file` serializes via the accessors), and a resumed message gets turn 0 (no
cards — honest, since its rounds belong to a prior session). Older turns whose rounds aged out of the 16-round
roundlog ring show no cards (also honest). Measure/draw parity preserved (per-assistant card height is stable
across both `_gfeed_flow` passes). No producer/spine change.

### Changed
- `session_history_append` tags each message with `session_turns()`; NEW `session_history_turn(i)`. `gtool.cyr`:
  NEW `gtool_build_turn(cmds,x,y,w,turn)` (+ a `turn<=0` early-out for resumed rows); `gtool_build` delegates with
  `session_turns()` (failed-turn notice). `gfeed._gfeed_flow` interleaves per assistant by turn tag.

### Fixed
- The GUI "didn't complete" detector (`gpresent`) used a net-history-growth check (`len <= _n0`) that FALSE-FIRED
  at the `SESS_HIST_MAX` (40) cap — once history is full, eviction pins the length, so every *successful* turn read
  as failed, surfacing a bogus red notice AND (with per-turn cards) a duplicate current-turn card. Replaced with
  `gturn_reply_landed()` (in `ginput.cyr`): true iff the last row is an assistant tagged the current turn —
  length-independent, so correct at the cap. Pre-existing (since 0.30.4) but amplified to a double-render by the
  per-turn loop, so fixed here.

### Added
- `test_gui_toolcards_perturn` (+6) and `test_gturn_reply_landed` (+4): per-message turn tags, per-turn roundlog
  filtering, an EARLIER turn's cards interleaved above its reply when a later (tool-less) turn is newest, and the
  cap-safe turn-success detection. A `/tmp/thoth_gui_cards_perturn.ppm` visual artifact. Pin **6.4.51** (wrapper
  drifted to 6.4.55; benign).

## [0.30.18] - 2026-07-12

**Tool-call status now honors the MCP `isError` flag — a failed tool no longer shows `ok`.** `daimon_invoke`
extracted a tool result's text but **discarded** its `isError` flag, so `roundlog`'s `ok` (→ the GUI card colour +
the `/audit`/telemetry lines) meant only "did the body parse," not "did the tool succeed." A tool that returned
`isError:true` **with** valid text (e.g. `web_search` with no backend, or a bad-args tool) was carded green `ok`.
Now: `daimon_invoke` captures `daimon_extract_is_error(body)` into a last-call slot (`daimon_invoke_is_error()`),
and the parallel executor reads `isError` off the raw body it already re-parses in phase 3 (main-thread — bayan
stays off the workers); a new pure `_agent_tool_ok(text_ok, is_error)` records success only when text parsed AND
`isError` is not set. `isError:false`/absent is unchanged (no regression for daimons that omit it). The error
text still reaches the model — only the recorded success FLAG changed. Thoth-side consumption fix, **no spine
change** (`daimon_extract_is_error` already existed; it just wasn't consulted on the invoke path).

### Fixed
- `daimon_invoke` now surfaces `isError` (was dropped); serial + parallel loop paths record the true tool-success
  verdict via `_agent_tool_ok`. `daimon_invoke_is_error()` last-call getter (serial-only → race-free).

### Verified
- 1412 assertions (`test_daimon` +5: the `_agent_tool_ok` truth table incl. the fixed `isError:true` + valid-text
  case) + main builds. **Live**: drove the real `daimon_invoke` against a running daimon — `web_search` (no
  SearXNG) and `libro_retention` (bad args) both return `isError:true` with text; `daimon_invoke_is_error()==1`
  and the recorded ok flips to `0` (err). Adversarially reviewed (wiring/concurrency/semantics → SHIP). Pin
  **6.4.51** (wrapper drifted to 6.4.55; benign).

### Notes
- Pre-existing + orthogonal (not changed here): `daimon_invoke` does not check HTTP status (unlike `daimon_call`),
  so a non-2xx body lacking `isError` can still record `ok` — a separate hardening item.

## [0.30.17] - 2026-07-12

**Tool-call cards + `/audit` now show each call's ARGUMENTS.** A bare `shell` on the card became `shell {"command":"git status"}` — you can see WHAT each tool did, not just that it ran. The `roundlog` producer
(`src/roundlog.cyr`) now snapshots a per-call arg summary alongside the name/verdict/telemetry it already kept:
a new `RL_ARG_CAP`-bounded (128 B), **sanitized** (control bytes → space, so a multi-line JSON arg can't break a
one-line card/row) copy of the raw `arguments`, captured at BOTH loop record sites (`agent.cyr` serial `ar` +
parallel `_par_args` slot). New `roundlog_call_args` accessor. Consumers: the GUI card (`src/gui/gtool.cyr`)
draws the args faint after the telemetry, **clipped** (`max_cp`) to the card's remaining width so a long arg
never bleeds past the border (draw-only — card height stays one line per call, so the feed measure/draw parity
is untouched); `roundlog_report()` (`/audit`) prints the args after the tool name. Thoth-side, **no spine
change** — the args were already in-process at the record site, just unpersisted.

### Changed
- `roundlog_add_call` gains an `args` param (all call sites + tests updated); `_rl_call_sz` grows by `RL_ARG_CAP`
  (name/kind/ok/ms/bytes offsets unchanged). `_rl_copy_args` sanitizes + truncates.

### Added
- `roundlog_call_args` accessor; args rendered on the GUI card + in `/audit`. Tests: `test_roundlog` +3 (args
  copied / control-byte sanitized / null→empty), `test_gui_toolcards` +1 (args drawn on the card). Pin
  **6.4.51** (wrapper drifted to 6.4.55; benign).

## [0.30.16] - 2026-07-11

**T3 GUI — tool-call cards in the feed.** The GUI now SHOWS which tools thoth ran to produce an answer, as
bordered cards in the conversation feed. In the GUI the live `tool-call:`/`result:` lines the TUI prints are
suppressed (the present loop wraps the turn in `OUT_NULL`), so tool activity was previously invisible on the
desktop; these cards fill that gap. NEW `src/gui/gtool.cyr` — a PURE, headless-testable view-builder that reads
the EXISTING `roundlog` producer (`src/roundlog.cyr`, the session ring `/audit` already renders) and emits
draw-IR cards: per round a bordered box with a left accent bar, a `tool round N` header, and one line per call
— the tool **name** (accent) + a status word (**ok** green / **err**·**deny**·**noname** red, via the shared
`_ui_rgb` palette) + `<ms>ms/<bytes>B` telemetry (faint). `gfeed`'s `_gfeed_flow` interleaves the block just
above the CURRENT turn's assistant reply (and above the failure notice for a failed turn). Like the feed,
`gtool_build` runs measure-only under `cmds==0` and returns the exact drawn height, so the bottom-anchor
pre-measure stays correct. This is a RENDERING cut over data thoth already holds — **no producer, session, or
spine change**.

### Added
- `src/gui/gtool.cyr` — `gtool_build`/`gtool_has_current` + `_gtool_card`/`_gtool_status_word`/`_gtool_status_color`.
- `roundlog.cyr` + `gtool.cyr` added to the LEAN `thoth_gui.tcyr`. `test_gui_toolcards` (+9): parity, per-round
  borders, status colors, current-turn filtering, feed interleave; a `/tmp/thoth_gui_cards.ppm` visual artifact.

### Notes
- **Scope**: current-turn cards only (rounds where `turn_no == session_turns()`), so placement needs no
  per-message turn tag; older turns show no cards (roundlog itself retains only the last 16 rounds). Per-turn
  interleave, tool **args** on the card, and colored **diffs** are follow-ups — the latter two need data
  `roundlog` does not keep (args/result text are in-process at the record site but unpersisted), and thoth
  exposes no file-edit tool, so a diff has no first-class source today. Pin **6.4.51**.

## [0.30.15] - 2026-07-11

**T3 GUI — composer history recall (Up/Down).** The GUI composer now recalls previous submissions with the
arrow keys, over the SAME `inhist` ring the TUI/REPL use (`src/inhist.cyr`) — so it shares the ring (and its
optional `[history].file`). Mirrors `_tui_recall_key`: **Up** stashes the live draft on the first step then
walks OLDER, **Down** walks NEWER and restores the draft past the newest. NEW in `src/gui/ginput.cyr`:
`gcomp_set(ptr,len)` (replace the composer content) + `ghist_up`/`ghist_down`/`ghist_record` + a draft stash;
`gkey` maps composer-focused Up(103)/Down(108) to recall (tree-focused Up/Down still navigate the tree) and
`ghist_record`s each submission (`inhist_push` + `inhist_nav_reset`). `gui_run` calls `inhist_init()`. Added
`src/inhist.cyr` to the LEAN `thoth_gui.tcyr`. 1391 assertions (+10 `test_gui_history`: submit records, Up/Down
walk newest↔oldest, Down past newest restores the (empty) draft, a typed draft is stashed + restored around
recall, and a tree-focused Up still moves the tree). PURE + unit-tested; the present loop is main-only.

### Added
- `gcomp_set` + `ghist_up`/`ghist_down`/`ghist_record` (+ draft stash) in `src/gui/ginput.cyr`; `gui_run`
  `inhist_init()`. `test_gui_history` (+10).

### Notes
- In-session recall only this cut; wiring the GUI's `inhist` to `[history].file` (cross-session persistence,
  like the REPL/TUI) is a small follow-up. Pin **6.4.51**.

## [0.30.14] - 2026-07-11

**T3 GUI — conversation-feed scrollback.** The feed bottom-anchors to the newest message (0.30.3), so after a
long chat older messages clip off the top. Now **PgUp/PgDn** page through them and **End** jumps back to the
latest. NEW `gscroll_*` state (`src/gui/ginput.cyr`, before `gfeed.cyr` in the include order so `gkey` drives it
and `gfeed_build` reads it): `_gscroll` = px scrolled UP from the bottom (0 = newest visible); `gscroll_page`
pages by ~the feed height; `gfeed_build` sets the view height + clamps the offset to the overflow each frame and
shifts the flow up by it. `gkey` maps PageUp(104)/PageDown(109)/End(107); a submitted turn **resets** the scroll
so the reply is always seen, and the empty greeting resets it too. When scrolled off the bottom, a faint
`-- more below (End) --` hint renders at the feed's bottom edge. 1381 assertions (+8 `test_gui_scroll` in the
LEAN `thoth_gui.tcyr`: scrolling up shifts the flow down, the offset clamps at the top, PgUp/End wiring, and the
submit-resets-scroll behaviour) + a golden PPM of the scrolled state — visually confirmed. PURE + unit-tested;
the present-loop dirty-repaint on a scroll key is main-only.

### Added
- `gscroll`/`gscroll_reset`/`gscroll_by`/`gscroll_page`/`gscroll_view_h_set`/`gscroll_clamp`
  (`src/gui/ginput.cyr`); `gkey` handles PageUp/PageDown/End and resets on submit; `gfeed_build` applies the
  offset + draws the "more below" hint. `test_gui_scroll` (+8). Pin **6.4.51**.

## [0.30.13] - 2026-07-11

**T3 GUI — tree Enter on a file drops an `@mention` into the composer.** Completes the file-tree keyboard nav
(0.30.10): pressing **Enter** on a file in the focused tree now inserts `@<repo-relative-path> ` into the
composer and hands focus back — so you navigate to a file and reference it in your message, riding the 0.21.0
`@mention` machinery (`cmd_task` expands `@path` to that file's content). NEW `gtree_mention(li)`
(`src/gui/ginput.cyr`): builds the path exactly as the git-badge lookup does (absolute `ftree_path` minus the
`ftree_cwd()` prefix) and appends `@` + relpath + a space through the composer buffer. Enter on a DIRECTORY still
toggles expand/collapse (unchanged). 1373 assertions (+4 `test_gui_nav` in the LEAN `thoth_gui.tcyr`: a file's
Enter yields `@src/main.cyr ` + composer focus; a dir's Enter still collapses and inserts nothing). PURE +
unit-tested; the mention expansion itself is already covered (`test_mention`) and live-verified.

### Added
- `gtree_mention(li)` (`src/gui/ginput.cyr`); `gtree_key`'s Enter branch handles files (mention) vs dirs
  (toggle). Pin **6.4.51**.

## [0.30.12] - 2026-07-11

**T3 GUI — fix the 0.30.11 owl-eye throb (glitchy surface + invisible pulse).** Live testing surfaced two bugs
in the throb, both fixed:

- **Surface glitch (the serious one)** — the top of the window flickered with bg-coloured overdraw. Root cause:
  the present shell uses a SINGLE `wl_shm` buffer with `buf_busy`/`frame_done` throttle flags, but the 0.30.11
  throb loop presented **unconditionally every tick** — drawing into the buffer while the compositor was still
  scanning out the previous frame (a buffer-reuse race). The sparse event-driven repaints rarely hit it;
  continuous throb hit it constantly. FIX: NEW `gwl_win_ready()` (`src/gui/gwindow.cyr`) = `frame_done == 1 &&
  buf_busy == 0`; the present loop (`src/gui/gpresent.cyr`) now gates EVERY present on it — a redraw is marked
  `_gui_pending` and flushed only once the compositor has released the buffer + acked the frame callback (those
  events arrive on the wl fd and are consumed by `gwl_win_poll_events`). `poll(2)` is only read when readable.
- **Invisible pulse** — the eye read as a colourless blink, not a colour throb. Root cause: the pulse blended
  toward the BACKGROUND, so the dim phase was ~invisible. FIX (`src/gui/gfeed.cyr` `geye_color`): the triangle
  wave now glows the base colour toward WHITE (peak ~50%), so the eye stays visibly amber (or red, when hoosh is
  down) at every phase — a throb, not a blink. Smoother 12-step wave (was 8); ~120 ms throb tick.

1369 assertions (+1 `test_gui_eye`: the peak glow is never the background colour). The throb colour is
PURE/unit-tested; the frame-throttled present loop is main-only (compositor-gated — verify live).

### Added
- `gwl_win_ready(win)` (`src/gui/gwindow.cyr`) — safe-to-present gate (buffer released + frame acked).

### Changed
- `src/gui/gpresent.cyr` — the present loop gates every redraw on `gwl_win_ready` (`_gui_pending` flag), fixing
  the scanout race; the turn's working-frame present is likewise gated.
- `src/gui/gfeed.cyr` — `geye_color` glows toward white (always visible); `GEYE_STEPS` 8 → 12. Pin **6.4.51**.

## [0.30.11] - 2026-07-11

**T3 GUI — the signature `{(o>` owl prompt + a throbbing owl-eye status indicator.** Two GUI-composer touches:

- **Restored the `{(o>` owl prompt** (`src/gui/gfeed.cyr`): the composer prompt and every user turn in the feed
  now use `{(o>` — the brand glyph the TUI + REPL use — replacing the plain `>` the GUI had carried since
  0.30.1. Text offsets widened to clear the 4-glyph prompt.
- **The owl's eye (`o`) throbs as a live status indicator** ("the head as indicator"): its BASE colour reflects
  hoosh health (red when the gateway is DOWN via `hoosh_health()`, else the amber accent), and it pulses (a
  triangle brightness wave) so the window feels alive at rest. The eye is drawn as its OWN draw-command
  (`_geye_cell`, recorded by `gframe_build`); the present loop now polls with a ~300ms throb tick, advances a
  colour phase, and rewrites **only** that one cell's colour before re-rasterising. **Leak-free animation**: the
  frame command list is CACHED (`_gui_cmds`, rebuilt only when the view changes — keystroke/resize/turn), so the
  idle throb costs zero per-frame allocation (only real interactions rebuild, exactly as before). `poll(2)`
  services compositor events only when the wl fd is readable; on the timeout it just throbs.

1368 assertions (+8 `test_gui_eye` in the LEAN `thoth_gui.tcyr`: the pulse is distinct across phase + symmetric,
`gframe_build` records the eye cell as a mutable `o` TEXT command, and the base colour tracks hoosh up/down) +
the frame golden PPMs render the split `{(o>` unchanged. The throb colour math + eye-cell recording are PURE +
unit-tested; the timed present loop is main-only (compositor-gated — verify the animation live on Wayland).

### Added
- `src/gui/gfeed.cyr` — the throb: `geye_color`/`geye_color_now`/`geye_phase_advance`/`geye_cell` + `_geye_blend`
  (packed-XRGB channel blend) + `_geye_base` (hoosh-health colour). The composer prompt splits `{(o>` into
  `{(` + `o`(eye) + `>` so the eye has its own recolourable cell.
- `test_gui_eye` (+8) in `tests/cases/gui.cyr`.

### Changed
- `src/gui/gpresent.cyr` — the present loop caches the frame command list (`_gui_cmds` + `_gui_dirty`) and polls
  with a 300ms throb tick, recolouring the eye each frame; events set `_gui_dirty`. Pin **6.4.51**.

## [0.30.10] - 2026-07-11

**T3 GUI — file-tree keyboard navigation.** The GUI's file-tree pane (0.30.5) was a static view; now it's
interactive, with focus like the TUI. NEW in `src/gui/ginput.cyr`: a focus state (`gfocus`/`gfocus_set`,
COMPOSER/TREE), `gtree_key` (evdev ↑103/↓108 move · →106 expand · ←105 collapse · Enter toggles the selected
dir, over the `ftree_*` model), and `gkey` — the focus-aware top-level key dispatch that replaces `gcomp_key`
as the present loop's entry: **Tab** toggles composer↔tree (only to a populated tree), **Esc** quits from any
focus, a printable key while tree-focused returns to the composer and types it, else composer keys go to
`gcomp_key`. `gpresent.cyr` feeds keys through `gkey`. Focus is visible: the tree's selected row gets a bright
full-row highlight + accent bar when the tree is focused (dim bar otherwise), and the composer's `>` prompt +
caret show bright only when the composer is focused. 1360 assertions (+17 `test_gui_nav` in the LEAN
`thoth_gui.tcyr`: Tab toggle, arrow move/clamp, Enter/→/← expand-collapse, printable→composer, Esc quit,
Enter→submit, empty-tree guard) + a golden PPM of the tree-focused frame (bright selection, dimmed composer) —
visually confirmed. The nav logic is PURE + unit-tested; the present-loop wiring is main-only (compositor-gated,
verify live on a Wayland compositor).

### Added
- `src/gui/ginput.cyr` — `gfocus`/`gfocus_set` + `gtree_key` + `gkey` (focus-aware dispatch).
- Focus-aware rendering: `src/gui/gtree.cyr` (`_gtree_selbg` + focused selection highlight), `src/gui/gfeed.cyr`
  (`gframe_build` shows the composer caret/bright prompt only when composer-focused; hint mentions Tab).
- `test_gui_nav` (+17) in `tests/cases/gui.cyr`, wired into `tests/thoth_gui.tcyr`.

### Changed
- `src/gui/gpresent.cyr` `_gpresent_drain_keys` dispatches through `gkey` (was `gcomp_key`).

### Notes
- Enter on a FILE is a no-op this cut (dirs toggle); a file → `@path`-into-composer is a natural follow-up. Pin
  **6.4.51**.

## [0.30.9] - 2026-07-11

**Curated per-domain test binaries** (enabled by the 0.30.8 decoupling). The single `tests/thoth.tcyr` (one
binary of the whole codebase) is replaced by independent, curated `tests/*.tcyr`, each including ONLY its
domain's transitive `src` deps — so a domain can be run fast in isolation (`cyrius test tests/thoth_gui.tcyr`):

- **`tests/thoth_gui.tcyr`** — LEAN (103): the T3 draw pipeline + view-builders + surface. Includes
  `surface → hoosh → gate → t-ron` + `intr` + the GUI modules; **NO `tui`/`mdhl`/`feed`/`commands`/`vyakarana`**.
- **`tests/thoth_render.tcyr`** — LEAN (107): diff/highlight/mdhl. Includes `vyakarana` + `diff`/`mdhl` +
  `feed`/`fsearch`/`git`; no `tui`/`commands`/`agent`/`gui`.
- **`tests/thoth_core.tcyr`** — FULL (1133): the commands/tui-coupled integration tests (core + agent + tui).
  These stay full-include because the hub (`tui → dispatch`, `agent → spin_label`, `shell → _params_one`)
  couples them to the whole codebase.

Test helpers were sorted to match: shared byte-buffer utilities → NEW `tests/cases/testutil.cyr` (dep-free);
domain-specific helpers moved into their case file; `test_memory` (uses `classify_input`) moved to `core`.
**1343 assertions** across the 3 binaries (was 1341 in one; +2 = `test_surface`'s config-conditional asserts
now run in isolation — more coverage, not a regression). `cyrius test` runs all three.

### Changed
- `tests/thoth.tcyr` (driver) + `tests/cases/helpers.cyr` removed; replaced by `tests/thoth_{gui,render,core}.tcyr`
  + `tests/cases/testutil.cyr`. `src/test.cyr` header updated to point new tests at the right binary.

### Notes
- Only `gui` and `render` are cleanly lean; `agent` is *nearly* lean but for two residual layering violations
  the decoupling didn't cover (`agent → spin_label_*` in tui, `shell → _params_one` in commands) — decoupling
  those (and the `commands`/`tui` hub) would let the integration bucket split further; a future arc. No `src`
  change this cut. Pin **6.4.51**.

## [0.30.8] - 2026-07-11

**Decouple the lower layers from the TUI (dependency inversion).** thoth grew out of one file and had never
been layered; three lower modules reached UP into presentation, which coupled *every* GUI/TUI test to the whole
codebase (cyrius refuses to emit with reachable-undefined). This refactor breaks all four couplings so
`util`/`gate`/`hoosh` no longer name the TUI:

- **`intr_*` extracted to `src/intr.cyr`** (substrate). The turn-interrupt handling (Esc aborts a stream) is
  signal/termios substrate, not presentation — MOVED verbatim out of `tui.cyr`, included after `ui`, before
  `hoosh`/`agent`/`tui`. `hoosh`/`agent` now poll it *downward*; no call-site changes.
- **`util → feed` becomes a registered ring sink.** `util`'s `OUT_RING` branch routed straight into
  `feed_write`; now it calls `_ring_emit` → a `_ring_sink` fnptr the renderer registers with `&feed_write` once
  at startup. `util` (substrate) no longer names the feed.
- **`gate → tui_confirm` becomes confirm-bracket hooks.** The auth confirm's live-screen bracket is pure
  presentation; `gate` calls registered `_confirm_begin_fn/_end_fn` (the TUI registers `&tui_confirm_begin/end`),
  unregistered → skipped.
- **`hoosh → mdhl/feed_stream` becomes a reply-render sink.** The streaming/blocking reply render routed through
  `mdhl_*` + `feed_stream_tick` directly; now through a `reply_sink_*` the driver registers for all tiers
  (`&mdhl_reply/_reset/_feed/_finish` + `&feed_stream_tick`), with a **raw-emit fallback** so a turn's reply is
  never dropped if unregistered.

Cyrius fnptrs (`&fn` + `fncall0/fncall2`; `fnptr` was already in `[deps].stdlib`). **Verified**: 1341 unit
assertions (unchanged); build green; **live** — a real hoosh turn renders correctly for `stream=false` and
`stream=true` (plain + fenced), the rich-TUI feed renders a reply, and the gate confirm prompt renders live in
the rich TUI with the tool running on `y`; **floor byte-identical** (piped one-shot unchanged). Reviewed via a
4-lens find→verify workflow — **0 findings**. **Payoff proven**: a curated lean GUI test (`surface → hoosh →
gate → t-ron` + `intr` + the GUI modules, *no* `tui`/`mdhl`/`feed`/`commands`/`vyakarana`/…) now compiles +
passes (103 assertions) — the coupling that forced the one-binary test split (0.30.7) is gone.

### Added
- **`src/intr.cyr`** — turn-interrupt substrate (extracted from `tui.cyr`).
- Registered sinks: `out_ring_sink_set` (`util`), `confirm_hooks_set` (`gate`), `reply_sink_set` (`hoosh`);
  wired once in `main()` (and `out_ring_sink_set` in the test driver).

### Changed
- `src/util.cyr` (`emit`/`emit_n`/`oprintln`/`ofmt_int` route `OUT_RING` through `_ring_emit`), `src/gate.cyr`
  (confirm bracket via hooks), `src/hoosh.cyr` (reply render/stream via the sink), `src/tui.cyr` (intr block
  removed; `tui_confirm_*` still defined + now registered), `src/main.cyr` (3 registrations).

### Notes
- The one-binary test structure (0.30.7) is retained for now — this refactor merely makes curated per-domain
  test files *possible*. Pin **6.4.51** (wrapper auto-drifted to 6.4.52; benign).

## [0.30.7] - 2026-07-11

**Test suite split into topical case files.** `tests/thoth.tcyr` had grown to ~4,095 lines in one file. It is
now a thin DRIVER (the src-module include block + `include "tests/cases/*.cyr"` + `main()`), with the ~72 test
functions moved into topical files under **`tests/cases/`**: `core.cyr` (1,403 — session/config/hoosh/persona/
cost/history/oneshot/logging), `tui.cyr` (1,184 — composer/feed/soft-wrap/search/tab-complete/spinner/tree/
picker/theme), `agent.cyr` (572 — the agentic tool spine), `render.cyr` (361 — diff/highlight/mdhl), `gui.cyr`
(347 — the T3 draw pipeline + surface), and `helpers.cyr` (the 9 shared test helpers, included first). **A PURE
MECHANICAL refactor** — `main()` is verbatim (same 72 calls in the same order), every definition is still
present via the includes, so it stays ONE compiled binary and is behavior-identical: **1341 assertions, 0
failed** (unchanged). Kept as one binary (not independent per-domain `.tcyr`) deliberately: `hoosh`/`gate`
reach into the TUI (`surface → hoosh → gate → tui`), so a per-file split can't drop those modules — splitting
the SOURCE gives readable files without fighting that coupling.

### Changed
- **`tests/thoth.tcyr`** is now the driver (~141 lines); test bodies live in `tests/cases/{helpers,core,render,
  tui,agent,gui}.cyr`. Largest file is 1,403 lines (was 4,095).
- `src/test.cyr` header updated to point new tests at `tests/cases/*.cyr` + `main()`.

### Notes
- Curated *lean* per-domain test binaries were investigated and rejected: cyrius refuses to emit with
  reachable-undefined functions, and `surface → hoosh → gate → tui_confirm_*` / `hoosh → intr_*/mdhl_*/
  memory_context` couple every GUI/TUI test to the whole codebase. A lean split would need a product refactor
  (extract `intr_*`/`tui_confirm_*` from `tui.cyr`; decouple hoosh's display calls) — its own future arc.
- Pin **6.4.51** (wrapper auto-drifted to 6.4.52; benign).

## [0.30.6] - 2026-07-11

**Toolchain refresh (cyrius 6.4.49 → 6.4.51) + the full file-tree tests the output cap had forced lean.**
cyrius **6.4.51** resolves thoth's filed output-cap issue: the emitted-binary `output_buf` grew from a fixed
**16 MiB to 1 GiB on Linux** (macOS/Windows follow in .52). thoth's test program `tests/thoth.tcyr` is one
translation unit that includes the whole driver + every vendored spine dep + the full assertion suite, so it
had hit the 16 MiB cap at 0.30.5 (overflowing by ~3,832 bytes when the file-tree pane + tests landed) — which
forced the `gtree` test to be kept lean. With the cap raised, this cut **restores the full coverage**: the
directory/file/header color scan, the empty/bare/root `_gtree_basename` cases, the full `_gtree_scroll_first`
clamp, a golden PPM of the tree pane, and a real-repo render smoke exercising the git-badge path
(`_gtree_gitkind`) on live files. No product-code change — `src/gui/gtree.cyr` is unchanged from its 0.30.5
review. 1341 assertions (+9). Floor verified byte-identical on the new toolchain (piped one-shot, `/seams`,
`--version`).

### Changed
- **Toolchain: cyrius 6.4.49 → 6.4.51** (`cyrius lib sync` moved 7 stdlib files — the `alloc*` variants,
  `sakshi`, `sandhi`, `syscalls`). Vendored dists unchanged (already current: avatara 2.8.0 / sit 1.3.4 /
  sankoch 2.5.1 / libro 2.7.10 / bote 3.1.1 / t-ron 2.1.7 / vyakarana 2.2.3 / darshana 0.9.0).
- `test_gui` — the `gtree` tests restored to full fidelity (the command-scan color checks + the golden PPM +
  a real-repo render smoke), reversing the 0.30.5 lean stopgap.

### Notes
- The 16 MiB → 1 GiB raise is **Linux-only** in 6.4.51 (thoth's build/test target); macOS/Windows keep the
  fixed 16 MiB region until cyrius 6.4.52's large-alloc path. Resolves
  `~/Repos/cyrius/docs/development/issues/2026-07-11-output-buf-16mib-cap-blocks-large-test-binaries.md`.
- With the cap no longer binding, a separate lean GUI test binary is **no longer needed** — the GUI test
  suite can grow in the shared binary again.

## [0.30.5] - 2026-07-11

**T3 GUI — the file-tree pane.** The desktop window gains the mockup's (Thoth.dc.html) left column: a file-tree
pane over ftree.cyr's flattened tree model — the SAME model the TUI pane reads. NEW **`src/gui/gtree.cyr`**, a
view-builder like `gstatus`/`gfeed`: it reads producers (`ftree_*` + `git_status_of`) and lowers the tree into
draw-commands — a project-name header, then one row per visible node with a depth indent, a `v`/`>` expand
marker, the name (directory = `ROLE_BLUE`, file = `ROLE_MUTED`, exactly as `tui_draw_tree` paints them), and a
git badge (`M`/`A`/`D`, files only, via the 0.22.4 `ftree_path` → strip-cwd → `git_status_of` path). The pane is
**responsive**: `gframe_build` reserves a 230px left column and shrinks the feed when the window is wide enough
(`gtree_w`), and hides the tree entirely on a narrow window (< 640px), giving the feed the whole body exactly as
before — so the status strip and composer still span full width. `gui_run` calls `ftree_load()` + `git_probe()`
at startup so the pane is populated and its badges (and the status strip's git field) have data. STATIC render
this cut (keyboard nav — focus / ↑↓ / expand-collapse — is the follow-up, mirroring feed render 0.30.1 → feed
interactive 0.30.2). 1331 assertions (+8). Reviewed via a 3-lens find→verify workflow.

### Added
- **`src/gui/gtree.cyr`** — `gtree_build` (the pane), `gtree_w` (responsive width), `_gtree_row`,
  `_gtree_gitkind` (mirrors `_tui_tree_row_gitkind`), `_gtree_basename`, `_gtree_scroll_first`, `_gtree_bg`.
- **`test_gui`** +8 — `gtree_w` thresholds, `_gtree_basename`, `_gtree_scroll_first` clamp, a synthetic-tree
  render, and a directory row's `ROLE_BLUE` color. The frame golden PPMs now include the populated tree pane
  (with a live `M` badge on the modified `main.cyr`).

### Changed
- `gframe_build` (`src/gui/gfeed.cyr`) lays out the body as `[tree pane | feed]` (tree hidden on a narrow
  window; the feed is byte-identical to before when the tree is hidden).
- `gui_run` (`src/gui/gpresent.cyr`) loads the file tree + probes git at startup.
- Include order: `src/gui/gtree.cyr` before `gfeed.cyr` (`gframe_build` calls `gtree_build`).

### Notes
- The test binary is at the **16 MiB output cap** (the same cap that keeps `gwindow`/`gpresent` main-only), so
  the gtree test is kept lean; `gtree_build`'s full render is also exercised in the frame golden PPMs. A
  dedicated GUI test binary (a separate lean `.tcyr` with only the GUI's transitive deps) is the next infra step
  before further GUI tests.

## [0.30.4] - 2026-07-11

**T3 GUI — turn feedback: a working indicator, and an honest notice when a turn doesn't complete.** The GUI ran
a turn SYNCHRONOUSLY (`cmd_task` under `OUT_NULL`) with no on-screen feedback — the window froze on the old
frame for the turn's duration, then the reply appeared. Now, on Enter, the present loop paints ONE "working"
frame BEFORE the blocking turn: the just-submitted message is echoed as a provisional bubble and a "thoth is
working…" indicator shows, both folded into the bottom-anchored feed so they stay visible. It is NOT an
animated spinner — the turn blocks the event loop and this substrate has no threads, so it is a single honest
pending frame, not a promise of animation. AND — because the window renders only `session_history` and a failed
turn pops the user message (unreachable hoosh, transport/HTTP error, empty completion), the message would
otherwise vanish silently; so a turn that appends no assistant reply now raises a transient RED "the turn did
not complete — is hoosh reachable? try /reprobe" notice in the feed instead of swallowing the message. The
notice is a transient flag, NOT a `session_history` entry, so it never pollutes the model's context; a new
submit clears it. 1323 assertions (+13). Reviewed via a 3-lens find→verify workflow — which is what surfaced
the silent-failure gap (CONFIRMED); addressed here.

### Added
- **`gturn_*` pending-turn state** (`src/gui/ginput.cyr`): `gturn_begin(text)` (COPIES the submission — the
  composer is reset before the turn runs), `gturn_end`, `gturn_active`, `gturn_text`, plus `gturn_fail` /
  `gturn_failed` for the transient failure notice.
- **Working state in the feed** (`src/gui/gfeed.cyr` `_gfeed_flow`): when a turn is active, a provisional user
  bubble (the echoed submission) + a "thoth is working…" indicator, measured into the bottom-anchored flow so
  they stay visible; when the last turn failed, a red "didn't complete" notice.
- **`test_gui`** +13 — the pending state (active/text/copy), measure-draw parity WITH the pending block,
  greeting-vs-working routing, the failure flag + notice render + its parity + a new-submit clear, and working /
  failed golden PPMs.

### Changed
- `src/gui/gpresent.cyr` Enter handler: `gturn_begin` + `gcomp_reset` + a pre-turn working-frame paint, then
  the turn, then a net-history check (`len <= n0` or last role ≠ assistant → `gturn_fail`) and `gturn_end`.
- `gfeed_build` shows the greeting only when idle (no history AND no active turn AND no failure notice).

## [0.30.3] - 2026-07-11

**T3 GUI — the feed follows the conversation (bottom-anchored auto-scroll).** The GUI feed drew top-down from
the region top and clipped anything past the bottom, so after ~3–4 turns the NEWEST reply scrolled off-screen
and was invisible. Now the feed measures its total height and, when it overflows the region, anchors the flow
to the BOTTOM — the newest message sits flush above the composer and older messages clip off the top (the
mockup's auto-scroll-to-bottom behavior). A short conversation still top-anchors (natural reading order).
`gfeed_build` runs a MEASURE-only pass (`_gfeed_flow` with `cmds == 0`) using the exact same wrap/layout code
as the draw pass, so the measured height is byte-for-byte the drawn height and the anchor is precise; the
existing CLIP hides the older messages that scroll above the region top. 1310 assertions (+12), incl. a
rastered golden PPM of an overflowing feed (newest exchange flush to the bottom, oldest clipped mid-line) —
visually confirmed. Adversarially reviewed (3-lens find→verify workflow): no parity break, no OOB (a negative
bottom-anchored `y` is clamped by the rasterizer), floor byte-identical (GUI-only). The review caught one
genuine pre-existing render nit in the wrap path — fixed below.

### Added
- **`_gfeed_flow(cmds, xbase, cy0, avail, n)`** (`src/gui/gfeed.cyr`) — lays out all n conversation messages
  down a column; `cmds == 0` measures without drawing (shared wrap code → exact measure/draw parity).
- **`gfeed_anchor_y(total, y, h)`** — the flow start-y: top-anchor when it fits, bottom-anchor (`y + h - total`,
  may be above the region top so the clip hides older messages) when it overflows.
- **`test_gui`** +12 — measure/draw height parity, the anchor decision (fit vs overflow), a command-scan
  proving the newest line is visible while the oldest clips above the top, a leading-space wrap guard, and an
  overflowing-feed golden PPM.

### Changed
- `gfeed_build` now measures the flow then draws it bottom-anchored (was: a single top-down draw pass).

### Fixed
- **Wrap path (pre-existing):** a message whose content STARTS with a space and wraps hit the space-break
  branch with `last_sp_cols == 0`, passing `max_cp = 0` to `gr_fb_text` — which means UNCAPPED, so the whole
  string was drawn on the first line (garbled overdraw). The empty leading-space segment is now skipped
  (`_gfeed_para`), with a regression test asserting the wrap path never emits an uncapped slice.

### Notes
- Documented negligible edge (left as-is): for a measured total within ~4px of the region height, the flow
  bottom-anchors and shaves ≤4px off the OLDEST (scrolling-away) line rather than top-anchoring — cosmetic,
  and consistent with flush-bottom auto-scroll.

## [0.30.2] - 2026-07-11

**T3 GUI — interactive: type in the window, Enter runs a turn.** The GUI becomes usable, not just a view. NEW
**`src/gui/ginput.cyr`**: `ginput_ascii(code,shift)` maps an evdev keycode + shift to a printable ASCII char
(US QWERTY, ported from jalwa's/puka's keymap), plus a **composer text buffer** (`gcomp_append`/`_backspace`/
`_reset`/`_len`/`_cstr`) and `gcomp_key(code,shift)` (Esc→quit / Enter→submit / Backspace / printable→append).
The present loop (`gpresent.cyr`) now feeds each window key through `gcomp_key`; the composer line renders the
typed text + a caret; on **Enter** it runs the turn (`cmd_task(gcomp_cstr())` under `OUT_NULL` so the turn's
progress doesn't leak to the launch terminal — the user + reply append to `session_history`, and the feed
repaints with them), then clears the composer; **Esc** quits. `gpresent.cyr` moved after `commands.cyr` in the
include order so `gui_run` can call `cmd_task`. So the loop is: type → Enter → turn → the reply renders in the
feed. The keymap + composer buffer are PURE + unit-tested; the actual turn is network- + compositor-gated
(verified on the user's machine). 1298 assertions (+12). A repaint blocks for the turn's duration (no spinner
yet) — acceptable, matches the TUI.

### Added
- **`src/gui/ginput.cyr`** — `ginput_ascii` (evdev→ASCII, US QWERTY) + the composer buffer (`gcomp_*`) +
  `gcomp_key` (the key→action dispatch). Pure; in `main.cyr` + the test binary.
- The composer line in `gframe_build` renders the live `gcomp_cstr()` + a caret (or a hint when empty).
- **`test_gui`** +12 — the keymap (letters/shift/digits/symbols/space/non-printable) + the composer buffer
  (append/backspace/cstr/key dispatch); a golden PPM of the interactive state (a conversation + a typed
  composer).

### Changed
- `gpresent.cyr` include moved after `commands.cyr` (so `gui_run` resolves `cmd_task`); its key handler now
  dispatches through `gcomp_key` and submits a turn on Enter.

## [0.30.1] - 2026-07-11

**T3 GUI — the conversation feed + composer layout.** The window becomes an *app*: the body now renders the
conversation (the mockup's main region) instead of placeholder text. NEW **`src/gui/gfeed.cyr`**: `gfeed_build`
reads the SAME `session_history_*` the TUI feed + `/save` read and lowers each message to draw-commands — a
user message gets a `>` accent marker + its text, an agent message is plain body text, each **word-wrapped**
to the available pixel width (`_gfeed_para` — codepoint-accurate, breaks at spaces, hard-breaks an over-long
word, draws each wrapped line as a `(start,cols)` slice via `gd_push_text`'s cap, no per-line copy). Empty
conversation → an honest greeting empty-state (never a faked exchange). Also `gframe_build` (moved here from
`gpresent.cyr` so it is headless-testable): the three-region layout — status strip (top) · feed (middle,
clipped) · composer line (bottom, a `>` prompt + hint). The status view-model now drives the strip AND the
feed reads the history producer — the GUI shows a real conversation. Rendered to a golden PPM (a 2-message
exchange wraps + lays out correctly). 1286 assertions (+5: word-wrap multi-line / single-line / null + a
full-frame render). Live `thoth gui` shows the greeting until input is wired (next cut).

### Added
- **`src/gui/gfeed.cyr`** — `gfeed_build(cmds,x,y,w,h)` (the conversation feed, clipped to its region) +
  `_gfeed_para` (codepoint-accurate word-wrap) + `_gfeed_greeting` (empty-state) + `gframe_build(w,h)` (the
  status/feed/composer window layout). In `main.cyr` and the test binary.
- **`test_gui`** +5 — word-wrap (multi-line / one-line / null) + a full 2-message frame render → PPM.

### Changed
- `gpresent.cyr`'s frame builder moved into `gfeed.cyr` (a view-builder, now headless-testable); the present
  loop just rasters `gframe_build` + presents it.

## [0.30.0] - 2026-07-11

**T3 GUI — Phase 2: a runnable `thoth gui` Wayland window.** The desktop tier becomes real: the GUI is now in
the SHIPPING binary, with a sovereign Wayland present shell and a `thoth gui` subcommand. Also refreshes the
toolchain **cyrius 6.4.46 → 6.4.49** (the latest; +71 stdlib files), which lifts the code-buffer headroom so
the GUI wires into `main.cyr` cleanly. New: **`src/gui/gwindow.cyr`** — a self-contained Wayland client
(wl_registry/compositor/shm + xdg-shell + a memfd/mmap XRGB8888 wl_shm buffer + evdev keyboard, over the raw
wire, no libwayland), ported verbatim from jalwa's `wayland.cyr` (itself a puka fork), renamed to thoth's
`gwl_*` namespace; thoth owns its copy (port the floor — the window substrate is FLOOR, destined to extract to
aethersafha). **`src/gui/gpresent.cyr`** — the present loop: open a window → build+raster a frame (the 0.28.0
status strip + a body, via the tested draw pipeline) → present → repaint on events (resize/key/close). A
`thoth gui` subcommand (`ONESHOT_GUI`) routes to it; it **degrades honestly** with no compositor (a stderr
note + nonzero exit, never a hang or fake window). **LIVE-CONFIRMED** on a real Wayland compositor (the
window opens with the status strip + body preview rendering); the headless sandbox exercises only the honest
degrade path + a byte-faithful client rename + the tested frame pipeline. Revises ADR-0009 (**T3 =
thoth-as-its-own-Wayland-app**, not thoth-in-puka). 1281 assertions (GUI present shell is main-only, not
unit-tested).

### Added
- **`src/gui/gwindow.cyr`** — sovereign Wayland window seam (`gwl_win_open`/`_present_begin`/`_present_commit`/
  `_poll_events`/`_next_key`/`_resize_apply`/`_close`), vendored+renamed from jalwa's `wayland.cyr`.
- **`src/gui/gpresent.cyr`** — `gui_run()` (the event loop) + `gframe_build(w,h)` (the window frame: status
  strip + rule + body greeting over the draw pipeline) + `_gpresent_frame`/`_drain_keys`/`_poll_fd`.
- **`thoth gui`** subcommand (`ONESHOT_GUI`, `src/oneshot.cyr` + `src/main.cyr`) — opens the T3 window.
- The GUI draw pipeline (`gdraw`/`graster`/`gstatus` + vendored kashi) is now in `main.cyr` (the shipping
  binary), not just the test binary.

### Changed
- **Toolchain: cyrius 6.4.46 → 6.4.49** (`cyrius lib sync`, +71 stdlib files); the pin now matches the wrapper
  (drift warning gone). The code-buffer headroom this brings is what lets the GUI live in `main`.

### Notes
- The Wayland present shell (`gwindow`/`gpresent`) is compiled into `main` only, NOT the test binary (the test
  binary would exceed the 16 MiB output cap, and the present shell is compositor-gated / smoke-only anyway).
  The headless draw pipeline stays unit-tested. Repaints are event-driven, so the per-frame command leak is
  bounded (documented in `gstatus.cyr`); thoth's `alloc` has no mark/rewind for a true per-frame arena.

## [0.29.0] - 2026-07-11

**T3 GUI — Phase 1: the headless draw pipeline.** Starts the desktop tier (the payoff the Stage-B view
surface was setting up), following jalwa's proven, phased, headless-testable pattern. Three NEW pure modules
under `src/gui/`: a **draw-command IR** (`gdraw.cyr` — RECT/TEXT/BORDER/CLIP as packed cells on a vec), a
**CPU rasterizer** (`graster.cyr` — executes the command list into an XRGB8888 wl_shm-layout buffer via the
kashi VGA 8×16 font; ported from jalwa's raster + puka's fb), and a **status-strip view-builder**
(`gstatus.cyr`) that lowers the 0.28.0 `status_snapshot()` FACTS into draw-commands. The status view-model now
has THREE renderers — line rows (`/state`), the TUI strip (`tui_draw_status`), and this GUI strip — over ONE
facts model, no new producer. Colors come straight from `ui.cyr`'s `_ui_rgb(role)` (already the packed XRGB
the rasterizer wants), so the GUI shares the TUI's amber/light palette + `/theme` for free; the health dot the
TUI draws as a `●` glyph the GUI draws as a filled rect (the facts→richer-mark payoff). ENTIRELY headless +
unit-tested (a golden-pixel test rasters the strip and dumps a PPM); no compositor, no window — the present
shell (a puka-forked Wayland client) is a later cut. Designed + reviewed with multi-agent workflows (a survey
+ 3 competing designs chose the view-model; a 3-lens review of this pipeline caught + fixed a
byte-vs-codepoint pen-advance drift on non-ASCII branch/persona names, plus a null-guard, a strip clip, and a
documented frame-arena requirement). 1281 assertions.

### Added
- **`src/gui/gdraw.cyr`** — the draw-command IR: `gd_push_rect`/`_border`/`_text`/`_clip`/`_unclip` build a
  `vec` of packed 8-slot cells `[kind,x,y,w,h,color,text,aux]`; accessors `gd_kind`/`_x`/…/`_aux`.
- **`src/gui/graster.cyr`** — the CPU rasterizer: `gr_fb_new`/`_clear`/`_fill_rect`/`_border`/`_glyph`/`_text`
  + a one-level clip + the `gr_raster` executor, into an XRGB8888 buffer. UTF-8→CP437-folded text over kashi;
  `gr_text_cols` gives the codepoint-accurate rendered width so a view-builder's layout pen matches.
- **`src/gui/gstatus.cyr`** — `gstatus_build(cmds,x,y,w,h)`: the status strip, mirroring `tui_draw_status`'s
  fields + omit gates, colored via `_ui_rgb(role)`, with the health dot as a filled rect.
- **`test_gui`** (23 assertions) — draw builders, `fill_rect`/`border`/glyph pixel checks, codepoint width,
  and a full status-strip render (+ a `/tmp` PPM dump).
- Vendored **kashi 1.0.2** (`src/vendor/kashi.cyr` — a freestanding VGA 8×16 font core).

### Notes
- The GUI modules are compiled + tested in the TEST binary only; they are NOT yet in `main.cyr` (no `gui`
  subcommand / present shell yet), so the SHIPPING binary is unchanged. They wire into `main` with the
  present-shell cut, after the code-buffer lift. A repaint loop must bracket each frame with `alloc_reset()`
  (a frame arena) — documented in `gstatus.cyr`.

## [0.28.0] - 2026-07-10

**The status view-model (Stage B opens).** Introduces `src/surface.cyr` — a tier-agnostic view-model that
reads the ~10 status producers ONCE, applies the omit/presence gates in one place, and normalizes them into
FACTS (enums + ints + cstr pointers, never bytes/color/layout). Both the rich-TUI status bar
(`tui_draw_status`) and the `/state` report (`cmd_state`) now render from this ONE model instead of each
re-reading the producers and re-implementing the gates — the enabling abstraction ADR-0009 declared but never
built. A PURE REFACTOR: every tier's output is byte-identical (proven by a piped `/state` byte-diff + a PTY
status-bar capture, both identical modulo the volatile git dirty count; edge branches — null model,
health-absent, git-absent, T0 surface — separately verified). The payoff is drift-safety (the presence gates
that had silently diverged between the bar and `/state` are single-sourced + tested once) and GUI-readiness:
because the model holds facts not bytes, a future T3 Wayland status widget is a third renderer over the same
accessors — no draw-IR committed now (its shape is learned when the GUI is built, per jalwa). Designed +
adversarially reviewed via multi-agent workflows (3 competing designs judged; a 3-lens review returned one
nit — an accessor guard asymmetry — fixed before the cut). 1258 assertions; live + byte-verified.

### Added
- **`src/surface.cyr`** — the status view-model. `status_snapshot()` reads the producers into a packed i64
  cell array (SF_* fields × SFC_* cells); accessors `status_present`/`status_state`/`status_ival`/
  `status_ival2`/`status_sval` return the normalized facts (each guards `_sf_rows==0` → crash-safe before the
  first snapshot). Fields: brand, persona, model, health, turns, ctx, tokens, cost, git, surface, theme.
- **`hoosh_ctx_kib()` / `hoosh_ctx_budget_kib()`** (`src/hoosh.cyr`) — the context KiB rounding formula,
  previously re-implemented inline in both the bar and `/state`, now single-sourced with its byte producers.
- **`test_surface`** (18 assertions) — the snapshot mirrors the producers, single-sources the omit gates, and
  locks the ctx KiB formula.

### Changed
- **`tui_draw_status`** (`src/tui.cyr`) and **`cmd_state`** (`src/commands.cyr`) render their overlapping
  status fields from `status_snapshot()` instead of reading the producers directly. `cmd_state` now
  `git_probe()`s before the snapshot (moved up from the git row; behavior-preserving). Output byte-identical
  at every tier; the ~13 `/state`-only config rows are untouched.

## [0.27.0] - 2026-07-10

**Toolchain refresh + tier-consistency parity fixes.** Updates the Cyrius toolchain (6.4.29 → 6.4.46, +71
stdlib files) and the vendored dist bundles (bote 3.0.1 → 3.1.1, darshana 0.8.2 → 0.9.0, libro 2.7.9 →
2.7.10, sankoch 2.4.9 → 2.5.1, sit 1.3.1 → 1.3.4), then closes three cases where a feature lived only in the
rich TUI despite being pure data/logic — the first slice of the simple↔rich consistency line (rich = the
rich TUI experience; simple = line-mode back-and-forth; everything that is *not* a rich-TUI blocker should
work at both). 1240 assertions; live-verified in line mode across a real cross-session round-trip.

### Added
- **`/reprobe` (alias `/ping`)** — re-check hoosh reachability on demand from any tier: the line-mode +
  shared equivalent of the TUI's Ctrl-R. A silent GET updates the cached health state, then the outcome is
  reported honestly (reachable / unreachable — `<url>` / absent). `src/commands.cyr` (`cmd_reprobe`), wrapping
  the existing `hoosh_health_probe()`.
- **`hoosh health` row in `/state`** — surfaces the cached reachability (reachable / unreachable / unknown)
  that was previously visible only as the TUI status-bar dot; shown when a gateway is configured.
- **`/history`** — list the input-history ring (submitted lines) in both the REPL and the TUI. Read-only
  listing; the TUI additionally recalls entries with Up/Down (a raw-mode affordance that stays rich-only).

### Changed
- **`/save` works in line mode** — with no TUI feed ring, `/save <file>` now writes the tier-neutral
  conversation history (user/assistant turns) as a markdown transcript instead of the old "captured in the
  TUI feed, not line mode" note. Closes the 0.24.1 line-mode gap. `src/commands.cyr` (`cmd_save` +
  `_save_history`).
- **`[history].file` persistence works in line mode** — the REPL now records each submitted input into the
  inhist ring and mirrors it to `[history].file` when configured (previously the ring was inited only inside
  `tui_loop`, so line-mode inputs never persisted). `src/main.cyr` (shared init + load announce),
  `src/repl.cyr` (record + persist + a one-time write-failure note). Persistence stays OFF by default, so the
  plain floor is byte-identical.
- **Toolchain / dependencies**: `cyrius.cyml` pin 6.4.29 → 6.4.46 (`cyrius lib sync`, 71 stdlib files).
  Vendored dist bundles re-synced — bote-core 3.1.1, darshana 0.9.0, libro 2.7.10, sankoch-zlib 2.5.1,
  sit-read 1.3.4 (avatara 2.8.0 / t-ron 2.1.7 / vyakarana 2.2.3 unchanged). Re-synced via
  `scripts/sync-{bote,libro,sit}.sh`; darshana is manually vendored (a `sync-darshana.sh` is a follow-up).

## [0.26.0] - 2026-07-09

**`.thoth/` home directory + honest readiness.** Config + project memory now live under a discoverable
`.thoth/` home (like `.git/`): `.thoth/config.cyml` (the config) and `.thoth/memory/`. thoth finds it by
walking UP from the CWD, then `~/.thoth/`, so launching in a subdirectory — or a different repo — finds the
right config instead of silently falling back to the localhost default. And the TUI greeting no longer claims
READY off that default when no config was found. Fixes the reported bug: "launched thoth in a different repo,
couldn't find the hoosh server, yet it pronounced itself READY." 1231 assertions; live-verified across
upward / legacy / absent config, the rich-TUI greeting, and upward memory.

### Added
- **Config + memory home discovery** (`src/config.cyr`): `_thoth_root_resolve` walks up from the CWD for the
  nearest ancestor `.thoth/` (up to 40 levels), then `~/.thoth/`. `config_path()` reads `<root>/config.cyml`,
  falling back to a legacy `./thoth.cyml` when no `.thoth/` home exists. `config_source()` / `config_root()`
  expose the resolution. Memory (`src/memory.cyr`) derives `memory_dir()` / `memory_index_path()` from the
  SAME root, so config + memory stay consistent regardless of launch directory. See ADR-0016.

### Changed
- **Config lives at `.thoth/config.cyml`** (was `./thoth.cyml`, still read as a fallback). The example moved
  to `.thoth/config.cyml.example`; `.gitignore` ignores the real `.thoth/config.cyml` and keeps the example +
  `.thoth/memory/` tracked. All user-facing config hints (`/state`, model picker, one-shot, status bar) now
  name `.thoth/config.cyml`.
- **Honest readiness** (`src/tui.cyr`): the greeting says **READY** only when a *configured* `[hoosh].url`
  actually answers. No config found → "no config — no <path> found (add one, or ~/.thoth/config.cyml)"; a
  config with no url → "hoosh absent"; a dead configured url → "hoosh unreachable — <url>". If the
  unconfigured default happens to answer it is noted "[default … is reachable]", never as READY.

### Fixed
- Launching thoth outside its own directory no longer silently probes the localhost default and reports READY
  as if configured — the config is discovered (or its absence is stated plainly), so READY reflects the real
  gateway.

## [0.25.1] - 2026-07-09

**Composer soft-wrap.** A long prompt now word-wraps at the screen edge and the input area grows to fit,
instead of scrolling a single long line horizontally. 1230 assertions; live-verified (an 80-char line in a
40-column terminal wrapped across 3 rows).

### Changed
- The composer is now **physical-row aware** (`src/tui.cyr`): a logical line of L bytes wraps across
  `L/avail + 1` rows (`avail` = content width). New pure helpers `_comp_avail` / `_comp_total_rows` /
  `_comp_cursor_prow` / `_comp_prow_to_offset`; the composer height, vertical scroll, draw, and cursor
  parking all work in physical (wrapped) rows, and the feed band / rules are fed `_comp_total_rows()` so they
  track the grown composer. Replaces the old one-row-per-logical-line + `_comp_row_hstart` horizontal scroll.
- **`↑`/`↓` now move by visual (wrapped) row** within the composer, falling through to input-history recall
  only at the true top/bottom physical edge (was per-logical-line).
- Limit (documented, unchanged from before): wrapping is byte-based, so a multibyte glyph straddling a wrap
  boundary may render as a replacement char — same class as the feed's glyph-width-1 limit.

## [0.25.0] - 2026-07-09

**Role modality — the third persona axis.** A persona already switches archetype (`/persona`) and can take
its shadow/blend; now you can also lean into a **role** — a facet of the archetype's personality — and
override it to anything you like. The role is *derived from a personality aspect*: avatara maps each
archetype's trait vector to a set of aspects (the Seeker, the Maker, the Measurer, the Mediator…), the
strongest is the default role, and `/role` selects among them or sets a custom label. This is the long-planned
persona axis, built end to end across avatara **2.8.0** (the new aspect API) and thoth. avatara: 82 assertions;
thoth: 1216. Live-verified (Thoth's dominant aspect resolves to "the Measurer"; `/role Keeper of Symbols` sets
a custom role).

### Added
- **`/role`** (`cmd_role` in `src/commands.cyr`): no arg lists the active archetype's aspects (each an
  avatara-derived role), marking the live one and the dominant default. `/role <aspect>` leans into that
  aspect (its role follows). `/role <any label>` sets a **custom** role — make anyone "the Librarian",
  "Deep Thinker", "Personal Scribe", "Keeper of Symbols". `/role reset` returns to the default.
- **`persona_role` now derives from an aspect** (`src/session.cyr`): precedence is user override → selected
  aspect's role → the archetype default (still "the Librarian" for the signature Thoth; the dominant
  trait-derived aspect for any switched archetype — sourced from avatara, never thoth-authored per-archetype
  prose). New `persona_role_select_aspect` / `persona_role_override_set` / `persona_role_reset` / `persona_aspect`.
- **The active role is woven into the system prompt** ("In this session you take the role of …"), so switching
  a role actually steers the turn — not just a relabel. Rebuilt in place on any role change.
- **avatara 2.8.0 `src/aspect.cyr`** (consumed via the refreshed `src/vendor/avatara.cyr`): trait-derived role
  aspects — `aspect_count/name/role/trait_offset/index_by_name`, `profile_aspect_weight`,
  `profile_dominant_aspect`. Universal across all 374 archetypes, no per-archetype authoring.

### Notes
- The aspect set is a deliberately small, universal base (derived from the personality vector); it can grow
  or gain per-archetype overrides later without breaking the index-stable avatara API. Role modality is no
  longer deferred — it was wrongly parked as "avatara-blocked"; avatara supports it cleanly.
- Reviewed adversarially (avatara aspects / thoth persona / cmd+reload lenses). One low display-honesty
  blemish fixed: the `/role` listing marked an aspect `*` as "live" for the default Thoth even though the
  active role was the special-cased "the Librarian"; the marker now flags the aspect whose role is actually
  active (or none), so it can never contradict the `active:` line.

## [0.24.4] - 2026-07-09

**`/reload` — re-read `thoth.cyml` mid-session.** Applies config changes without a restart, and is honest
about the split: fields the runtime reads per-use apply immediately; fields bound once at startup are left
alone (a restart changes those). Closes the `0.24.x` arc. 1201 assertions; live-verified (a `[alias]` added
to the file mid-session became usable right after `/reload`).

### Added
- **`/reload`** (`cmd_reload` in `src/commands.cyr`): re-parses `thoth.cyml` (`config_load`) and drops the
  agent tool-advertisement cache (`agent_tools_cache_reset`) so a changed `[shell].enabled` / `[hoosh].tools`
  (or a now-reachable daimon) re-advertises next turn. Prints an honest summary:
  - **Now active** (read per-use): `[alias]`, `[shell]` rules, `[ui]`, `[pricing]`, `[hoosh]` flags
    (model default / stream / history / tools / parallel), `[memory].enabled`.
  - **Additive**: `[project]` `read_roots` (new roots granted; existing grants can't be revoked mid-session).
  - **Restart to change** (bound once at startup): `[hoosh].url` / `[daimon].url` (the seams + first-use-cached
    endpoints), `[tron].policy`, `[log]`, `[persona].name`, `[history].file`, `[session].file`.
- An absent `thoth.cyml` reports "nothing to reload" and leaves state untouched (no partial reset).

### Fixed
- `/reload` no longer fakes success on an unreadable/unparseable file: `config_load` now exposes
  `config_parse_ok()`, and `cmd_reload` reports "reload failed — config unchanged" (and notes an unset
  `[hoosh].url`) instead of a green "reloaded" + hot-fields report. Review-caught (honesty lens).
- `/reload` now drops the cached `Bearer` auth header (`hoosh_auth_cache_reset`), so a rotated `[hoosh].token`
  actually takes effect next request instead of silently sending the stale token (401s behind a success
  message). The report lists `[hoosh]` `token`/`model` as hot accordingly. Review-caught.

## [0.24.3] - 2026-07-09

**Turn-completion niceties** (`[ui]`). Two small opt-in, interactive-only touches that finish the
terminal-citizen line (the OSC-0 title shipped in 0.22.3): a terminal **BEL** when a model turn finishes (tab
away, get pinged) and a faint **`(N.Ns)` elapsed** line after each reply. Both default off; one-shot output
stays byte-identical. 1198 assertions; live-verified (a REPL turn emitted the `0x07` bell + `(2.0s)`).

### Added
- **`[ui].bell`** — emit a terminal BEL (`0x07`) on turn completion, written directly to fd1 (bypasses the
  feed sink, like the OSC-52 / kitty escapes), so it works over SSH and never corrupts the TUI frame.
- **`[ui].elapsed`** — a faint `(N.Ns)` line after each reply (`clock_now_ms` around the turn; clamped at 0),
  sink-aware so it lands in the feed (TUI) or stdout (REPL). A `/state` `ui` row when either is on.

### Notes
- Both are **interactive-only** (`cmd_task` gates on `one_shot_active()`), so `thoth 'task'` / piped / `--json`
  output is unchanged; and **default off**, so a config without `[ui]` is byte-identical to before. Documented
  in `thoth.cyml.example`.

## [0.24.2] - 2026-07-09

**Conversation resume.** Opt-in `[session].file` persists the conversation history (your prompts + the
model's replies) across restarts — relaunch thoth and it picks up where you left off. Distinct from
`[history].file` (composer keystrokes) and the mneme memory seam (durable facts). Interactive-only (one-shot
never persists). 1189 assertions; live-verified across a real restart (process 1 learned a codeword → process
2 resumed and recalled it), with the file created `0600`. A 4-lens adversarial review (parser / role-pointer /
hooks / secrets) confirmed the persistence sound and caught two low findings (both fixed).

### Added
- **`[session].file`** (`sess_persist_*` in `src/session.cyr`): loads any prior conversation into the history
  at startup (the greeting announces "resumed N messages …") and rewrites the file after each completed
  exchange. Framed, **length-prefixed** format (`THOTH-SESSION-1` + `<role>\t<clen>\n<content>` records) so
  arbitrary multi-line content needs no escaping. A `resume` row in `/state` when active.
- **`/reset` clears the file too**, so a reset conversation isn't undone by the next restart's resume.

### Security
- Same opt-in, degrade-closed posture as `[history].file` (0.11.2): OFF by default; a fresh file is created
  `0600`; a set-but-unwritable path is announced and the session stays in-memory; a mid-session write failure
  disables persistence and is announced once — never faked. **This writes the conversation in plaintext** (more
  sensitive than keystrokes); the residuals (a pre-existing looser file is not re-tightened, AGNOS drops the
  create mode, no `O_NOFOLLOW`) are documented in `thoth.cyml.example` + the module, never a mode we can't enforce.
- The loader is hardened against a hostile/corrupt file: the magic line is verified, and a `clen` that is
  non-numeric, i64-overflowed, or larger than the buffer is rejected before any pointer arithmetic (no OOB).

### Fixed
- The greeting's resume count is capped at the messages actually kept (`session_history_len()` after the
  `SESS_HIST_MAX` eviction), so a >40-record file reports "resumed 40", not the raw parse count (review-caught).
- The format doc is precise that content is a NUL-terminated cstring (an interior NUL terminates it, as it must
  — a raw `0x00` can't be re-sent inside a JSON string); newlines/tabs/all other bytes round-trip exactly.

## [0.24.1] - 2026-07-09

**`/save <file>` — transcript export.** Writes the TUI feed scrollback to a file as a plain-text/markdown
transcript, ANSI-stripped to readable text. Rides the feed ring + the same portable `lib/io.cyr` file I/O
(create + truncate `0644`) as the one-shot `-o` tee. 1164 assertions; live-verified over a PTY (`/help` →
`/save` → a clean marker-free markdown file).

### Added
- **`/save <file>`** (`cmd_save` in `src/commands.cyr`): dump the feed scrollback to `<file>` (a `# thoth
  transcript` header + each line). The user's OWN export to a path they name — **not** t-ron-gated (like `-o`;
  the model can never invoke a slash command). Degrades honestly: no arg → usage; empty ring (line mode never
  captures the feed) → a note; unopenable path / short write → an announced failure, never faked.
- **`feed_strip_ansi_into`** (`src/feed.cyr`): a pure ANSI stripper — drops thoth's 2-byte role/reset markers
  (`ESC` + `0xB0..0xB7`/`0xBF`), CSI sequences, and other 2-byte `ESC` forms, so the export is clean text.
  Never severs a UTF-8 glyph (only `ESC`-introduced runs are removed).

### Honest limits
- The feed ring is **TUI-only** (line-mode/one-shot never capture it) and **bounded** (`FEED_ROWS` lines) —
  older scrollback is evicted, not saved. Documented in the `cmd_save` header + surfaced by the empty-ring note.

## [0.24.0] - 2026-07-09

**Model-picker palette.** A new interactive **Ctrl-P** picker in the TUI: it fetches hoosh's model catalog,
fuzzy-filters it as you type, and switches the active model on Enter — a discoverable front-end to the
existing `/model` mid-session switch, no new switch machinery. Opens the `0.24.x` arc. Role modality (the
originally-planned `0.24.0`) is **deferred**: switching which aspect of an archetype is leaned into needs a
per-archetype role registry that is avatara's to provide — thoth never hand-authors aspect tables — so it
stays a design + upstream-request, not shippable thoth code. 1154 assertions; live-verified over a PTY
(Ctrl-P → list → filter `opus` → Enter → `model ->` switch). A 4-lens adversarial review (memory / logic /
TUI-floor / honesty) confirmed the modal sound and caught one defensive gap (fixed): an empty catalog id.

### Added
- **Ctrl-P model picker** (new `src/mpick.cyr` + wiring in `src/tui.cyr`): a modal over the feed band listing
  the switchable models (the selected row highlighted, the active routing target marked `*`). Type to
  case-insensitive-substring filter, `↑/↓` to move, `Enter` to switch, `Esc`/`Ctrl-C` to cancel. TUI-only
  (the modal needs cursor addressing); the line-mode REPL and one-shot never decode Ctrl-P, so their floor is
  byte-identical. Discoverable via the idle hint + the `/model` help line.
- **`hoosh_catalog_fetch`** (`src/hoosh.cyr`): the data-returning sibling of `hoosh_list_models` — GETs the
  concrete per-provider catalog (`/v1/models/catalog`), falling back to `/v1/models` on 404, and returns the
  parsed model array (or 0 with an error kind). The catalog is hoosh's domain; thoth only asks.

### Changed
- The switch reuses the exact `/model` seam (`session_set_model_copy` + terminal-title refresh + audit log),
  so a picked model routes identically to a typed `/model <id>`. Degrades honestly: no hoosh seam /
  unreachable gateway / empty catalog → a one-line feed note, never an empty or faked modal.

### Fixed
- `_mp_add` refuses an empty model id (a malformed catalog entry `{"id":""}` yields a non-null zero-length
  string that `bayan_json_v_str` accepts) — otherwise it would become a blank pickable row whose selection
  silently switched to an empty model. Review-caught (honesty lens); the id-skip is the single choke point.

## [0.23.1] - 2026-07-08

**Granted read roots — the user widens the jail.** The 0.23.0 read tools were confined to the launch
directory. Now the *user* (never the model) can grant read access to additional absolute roots — to review
another repo, or to read the **vidya** Cyrius knowledge base and bring the latest language features back to
this project. A permission model like every other restriction: grants come from config
(`[project].read_roots`, `[project].vidya`) and from a new `/allow` command; reads under a granted root are
permitted (still no `..`), everything else is refused honestly. Live-verified end-to-end (the model read a
file under a granted root; without the grant the same read was refused). 1135 assertions.

### Added
- **`/allow` command**: `/allow` lists read access (the always-jailed project + any granted roots);
  `/allow <abs-path>` grants read access to an absolute root (e.g. another repo); `/allow vidya` grants the
  configured `[project].vidya` knowledge base. The MODEL cannot call it — it is a slash command, the human's
  own authorization (mirroring `/run`'s trust model). Grants are additive within a session; config
  `read_roots` persists them across sessions.
- **`[project]` config table**: `read_roots = ["/abs/a", …]` (absolute roots granted at every startup, a
  persistent user grant) and `vidya = "/abs/path"` (the knowledge base, grantable via `/allow vidya`).
  Documented in `thoth.cyml.example`.
- **`/state` `reads` row** (shown when the agentic loop is on): `project (jailed)` plus a granted-root count.

### Changed
- **The read boundary widens** (`_project_read_ok`): a read is allowed if it is a jailed in-project relative
  path **or** an absolute path — with no `..` component — under a user-granted root (prefix match on a `/`
  boundary, so `/a/b` is under `/a` but `/ab` is not). A granted root must be absolute and more than `/`
  (granting `/` would defeat the jail); trailing slashes are stripped and duplicates ignored. `read_file` /
  `list_dir` now refuse with "outside the project and any user-granted read root". The symlink-inside-a-root
  residual carries over from the jail (documented, not faked).
- `read_file` / `list_dir` tool descriptions tell the model it may also read absolute paths inside a
  user-granted root, so a user-supplied external path is attempted rather than pre-refused.

## [0.23.0] - 2026-07-08

**The agent can see the project.** New model-invokable `read_file` and `list_dir` tools let the backing
model read and explore the codebase thoth was launched in — previously it was blind out of the box (it saw
code only via the user's `@file` mentions or the opt-in `shell` hammer). Opens the `0.23.x` project-awareness
line. 1113 assertions. A 3-lens security review (jail-bypass / bounds / dispatch) confirmed the jail is
airtight and caught one caching regression (fixed). See [ADR-0015](docs/adr/0015-project-read-tools-jailed-default-on.md).

### Added
- **`read_file(path)` + `list_dir(path)`** (new `src/project.cyr`): thoth-native, model-invokable tools that
  read a project file / list a project directory, riding the existing `/read` + file-tree substrate (no new
  read path; no spine fork — daimon MCP tools stay additive). Advertised **default-ON** whenever the agentic
  loop runs, dispatched LOCALLY in `agent.cyr` (never forwarded to daimon).
- **Project jail** (`_project_jail_ok`): every path is confined to the launch directory — absolute paths, a
  leading `~`, and any `..` component are refused, so the agent can read anything *in* the project and
  nothing outside it (no `~/.ssh`, `/etc`). This is the security boundary, so reads are **not** t-ron-gated
  (read-only, project-confined). Output is bounded (64 KiB/file, 16 KiB/listing).

### Changed
- **`agent_enabled()` = `[hoosh].tools` alone** (was "tools AND (daimon OR shell)"): read_file/list_dir are
  always-available local tools, so the agentic loop runs whenever tools are on — the agent sees the project
  even with no daimon and no shell. daimon (its MCP registry) and shell just add more tools.
- The tool-advertisement cache latches ready only on a good daimon fetch (or no daimon), not on total tool
  count — the default-on project tools would otherwise permanently cache an empty daimon registry if daimon
  was transiently down on the first turn (review-caught; the documented self-heal is restored).

### Notes
- **Residuals** (documented, not faked): a symlink *inside* the project pointing outside is followed (no
  portable `O_NOFOLLOW`); the jail's separator/escape rules are POSIX/AGNOS-correct — Windows backslash /
  drive-letter paths need extra handling when the `--win` lane ships (it's IOCP-gated, doesn't build today).
- **Live-verified**: given "what version is this project? read the VERSION file", the model autonomously
  called `read_file {"path":"VERSION"}`, read it through the jail, and answered "0.23.0" correctly.
- Next: **`0.23.1`** — user-granted read roots (widen the jail to another repo or **vidya**, a permission
  model like every other restriction).

## [0.22.4] - 2026-07-08

**File-tree git badges** — the file-tree pane marks changed files with `M`/`A`/`D` from the already-probed
sit status. Content-blind surfacing, no new probe. 1092 assertions (+5). A 3-lens adversarial review found
one nit (a sub-6-column-width overflow), fixed.

### Added
- **Git status badges** (`src/git.cyr` `git_status_of`, `src/tui.cyr` `_tui_tree_row_gitkind` + the tree
  painter): `git_probe` now caches the per-file status (`sit_repo_status` {path, kind}) into reused buffers
  (copied before the repo closes; no accretion). In a repo, every tree row reserves a 2-col gutter — a
  colored `M` (modified, amber), `A` (new, green), or `D` (deleted, red) for a changed file, else blank; the
  active pane keeps its alignment. Files only; the node's repo-relative path is matched against the cache.
  Outside a repo the tree render is byte-identical (no gutter). TUI-only.

### Fixed
- Width guard (review nit): at a tree width < 3 columns the 2-col gutter is skipped (badges off), so it never
  overflows the pane into the separator column. (Cosmetic — only at <6-column terminals, already unusable.)

### Notes
- Live-verified via PTY: changed files (`src/tui.cyr`, `src/git.cyr`) render an amber `M`; committed/unchanged
  files and directories render a blank gutter; the data path matches sit's changed-file set. Badges refresh
  on the existing probe triggers (boot / after a write / `/state` / `/git`).

## [0.22.3] - 2026-07-08

**Terminal window title** — the first polish sweep of the `0.22.x` line. On a real terminal, thoth sets the
window/tab title to `thoth - <model>`, updated on a `/model` switch. 1087 assertions (+2). Role modality was
moved to the `0.23.x` line; `0.22.x` now carries polish sweeps from the backlog.

### Added
- **OSC-0 window title** (`src/commands.cyr` `_term_title_build` / `term_title_set`): set at interactive
  startup and on `/model`, via the OSC-0 escape (`ESC ] 0 ; thoth - <model> BEL`) written raw to fd1 (like
  `/copy`'s OSC-52). Gated to a color-capable tier — a NO-OP at `PT_PLAIN`, so piped / one-shot / CI output
  stays byte-identical (verified: zero escapes on the plain floor). The model name is filtered to printable
  bytes (C0 controls + DEL stripped) so a crafted `/model` arg or `[hoosh].model` value can never inject a
  terminal escape into the title — a pre-cut review caught that the verbatim append lacked `/copy`'s
  encoding safety.

### Notes
- Live-verified by driving the real rich TUI through a PTY (title set to `thoth - claude-opus-4-8`) and
  confirming a piped run emits no OSC escape.

## [0.22.2] - 2026-07-08

**Persona blends + shadow.** `/persona blend <a> <b> …` composes a weighted multi-archetype persona and
`/persona shadow` wears the inverted aspect — both avatara-native verbs, still pure consumption. Completes
the `0.22.x` active-persona core. 1085 assertions (+7). A 3-lens adversarial review returned clean.

### Added
- **`/persona shadow [name]`** (`src/session.cyr` `persona_shadow`, `src/commands.cyr` `_cmd_persona_shadow`):
  makes the SHADOW of the active persona (or a named archetype) active — avatara's `shadow()` inverts the
  traits and emits its own name/desc/soul/spirit ("Shadow of X" / "Shadow aspect …"), so it is a usable
  persona. Effective next turn.
- **`/persona blend <name>[:weight] <name>[:weight] …`** (`persona_blend`, `_cmd_persona_blend`): a weighted
  multi-archetype blend via avatara's `compose()`. Weights are optional integers (default 1, clamped 1..99;
  built as f64 by repeated add since there is no int→f64 builtin); the DOMINANT (highest-weight, first on
  ties) archetype leads the voice, and the result carries a `"A + B"` composite name + merged tradition.
  Needs ≥ 2 archetypes; any unknown name aborts with an honest refusal.
- Both are pure consumption (composition + shadow are avatara verbs; thoth authors NO persona prose — a
  blend uses the dominant's prose, a shadow uses avatara's shadow text — it only parses, builds the weighted
  vec, and surfaces the result). `/help` + `/persona` refusal updated.

### Notes
- Live-verified in the real binary: `/persona shadow` → "Shadow of Thoth (Shadow aspect …)"; `/persona blend
  Athena:2 Odin` → "Athena + Odin (Composite archetype)", tradition "Greek + Norse", and `/dry` shows the
  request's system prompt in Athena's voice (the dominant); unknown name and single-archetype cases refused.
- The vendored avatara `compose` (2.7.1) already emits the dominant's prose + composite name, so no dep bump
  was needed. Next in the line: `0.22.3` role modality (long-term).

## [0.22.1] - 2026-07-08

**`/personas` discovery.** Browse the avatara archetypes you can switch to with `/persona`. Discovery +
display only — no new personality logic, read-only. 1078 assertions (+2). A 3-lens adversarial review
returned clean (two nits verified as refuted).

### Added
- **`/personas [tradition]`** (`src/commands.cyr` `cmd_personas`): no arg prints the ACTIVE persona card
  (name · tradition · desc + a word-bounded soul excerpt) then lists the avatara traditions with per-tradition
  archetype counts; an arg browses that tradition, listing its archetypes (each with its desc, the active one
  marked `●`). Unknown tradition → honest refusal. All data is read from avatara (`all_traditions` /
  `by_tradition` / the `prof_*` accessors) — thoth only surfaces it. New `_persona_excerpt` (bounded
  soul/spirit preview: ~90 bytes, backs up to a word boundary + `…`). `/help` line added.

### Changed
- The `/persona` unknown-name refusal now hints `/personas` (which lists the available archetypes).

### Notes
- Live-verified in the real binary: `/personas` shows the card + traditions (Egyptian 16, Greek 15, Norse 13,
  …); `/personas Egyptian` lists Thoth (● active), Isis, Anubis, …; unknown tradition/name → honest refusal.

## [0.22.0] - 2026-07-08

**The active persona — mid-session `/persona` switch.** The signature move's twin: thoth already switches the
backing MODEL mid-session (`/model`); now it switches the active PERSONALITY mid-session via avatara. Opens
the `0.22.x` line. Plus a Cyrius toolchain refresh to **6.4.29**. 1076 assertions (+14). A 3-lens adversarial
review found no code defects (persona machinery sound).

### Added
- **`/persona [name]`** (`src/session.cyr` `persona_set`/`persona_switch`, `src/commands.cyr` `cmd_persona`):
  no arg shows the active archetype (name / role / tradition); an arg resolves through avatara's
  `find_and_validate` (unknown → honest refusal) and swaps the persona, effective NEXT turn — exactly
  `/model`'s semantics. Pure consumption: avatara owns lookup + validation + content; thoth only selects,
  injects, and surfaces. The cached persona system prompt is invalidated (dirty-flag) and rebuilt IN PLACE
  from the new archetype's soul + spirit + thoth's fixed operating clause (no per-switch heap leak;
  `PERSONA_SYS_CAP` raised 1 KiB → 2 KiB for arbitrary archetypes, still clamp-bounded).
- **`[persona].name` startup default** (`src/config.cyr` `config_persona`): picks the launch archetype;
  absent → `egyptian_thoth` (byte-identical floor). An unknown configured name falls back to the default
  (the active persona is always surfaced honestly, never faked).
- Active persona surfaced in the **status bar** (after the version) and **`/state`** (name · role · tradition),
  plus a `/help` line; `thoth.cyml.example` documents `[persona]`.

### Changed
- **Cyrius toolchain 6.4.26 → 6.4.29** (`cyrius.cyml` pin + `cyrius lib sync`): only `lib/sakshi.cyr` and
  `lib/sigil.cyr` changed content in the vendored floor.
- **Identity split (decided 2026-07-07, now enforced):** the THOTH backronym ("Thinks, Handles, Orchestrates,
  Transforms, Heals") is the APPLICATION's naming and stays fixed across switches; "the Librarian" is thoth's
  role framing for the DEFAULT Thoth archetype ONLY — a switched persona's role is sourced from its OWN
  avatara `desc`, never thoth-authored per-archetype prose (`persona_role` is name-conditional).

### Notes
- Live-verified in the real binary: `/persona Athena` switches (role from Athena's avatara desc), `/state`
  shows the persona row, and `/dry` after the switch shows the request's system message rebuilt to the new
  archetype's voice (soul + spirit) with thoth's operating clause preserved; an unknown name is refused.
- Next in the line: `0.22.1` `/personas` discovery (list traditions, browse, show the active card).

## [0.21.1] - 2026-07-08

**Tree-fed Tab completion for `@file` mentions.** In the TUI composer, pressing `Tab` on a `@<prefix>`
completes the path from the file tree; when the cursor isn't on a `@`-token, `Tab` keeps its existing
composer↔tree focus-toggle behavior. Builds on the 0.21.0 expansion core. 1062 assertions (+25). A 3-lens
adversarial review caught (and this cut fixes) a mid-token completion bug before ship.

### Added
- **`@` Tab completion** (`src/ftree.cyr` `ftree_complete`, `src/mention.cyr` `mention_prefix_at`,
  `src/tui.cyr` `led_insert_cstr` + `_tui_at_complete` + the `KEY_TAB` handler): the completer splits the
  prefix at the last `/` and lists that directory via the tree's own `dir_list` — so it works at any depth
  WITHOUT the directory being expanded in the pane, and rides the tree's existing (ungated) read posture. A
  unique match completes fully (with a trailing `/` for a directory, so the next `Tab` descends); multiple
  matches complete to the longest common prefix. The token scan (`mention_prefix_at`) shares the 0.21.0
  `@`/boundary/path-char rules, so what `Tab` completes is exactly what a submitted `@mention` expands.
  Completion is inserted at the cursor via the tested `led_feed` path.

### Fixed
- **Mid-token completion corruption** (caught by the pre-cut adversarial review): `mention_prefix_at` scanned
  only backward from the cursor, so with the cursor in the middle of a token (e.g. `@VERbar`, cursor after
  `VER`) `Tab` would splice the completion into the middle (`@VERSIONbar`). Now it requires the cursor to be
  at the END of the token (the char at the cursor must be a non-path-char), else `Tab` falls through to the
  focus toggle. Regression-tested.

### Notes
- Completion is TUI-only (composer input); the line REPL / one-shot / plain floor is untouched. It lists the
  directory live (relative to the CWD), matching `@mention`'s relative resolution. Live-verified by driving
  the real rich TUI through a PTY (`@VER` + `Tab` → `@VERSION`).

## [0.21.0] - 2026-07-08

**`@file` mentions** — type `@path` in a message and that file's content is injected into the prompt as
explicit, delimited context. Opens the `0.21.x` composer-intelligence line. Rides the existing `/read`
machinery and its posture (`file_exists` + `file_read_all` into a bounded reused buffer) — NO new read path,
NO new security surface: the content comes from a path the user typed in their own message. Multiple mentions
compose; a `@token` that does not resolve to a readable file is left LITERAL, so ordinary prose (an email
`foo@bar`, a handle `@someone`) is never mangled. Works in the REPL, the TUI, and one-shot (all route through
`cmd_task`), and is visible in `/dry`. 1037 assertions (+16). A 3-lens adversarial review (buffer-safety,
scan-correctness, floor-identity) returned clean.

### Added
- **`@file` mention expansion** (new `src/mention.cyr`, pure `mention_expand`/`mention_count`): a `@path` at
  start-of-text or after whitespace whose path resolves to a readable file appends a delimited block
  (`\n\n--- @<path> ---\n<content>`) after the user's prose; the `@mention` stays in the prose. Path charset
  `[A-Za-z0-9/._-~]`; a trailing punctuation char (`.,;:)]}`) is trimmed when the full token doesn't resolve
  (so "see @file.cyr." works). Multiple mentions compose; duplicates inject once; directories / empty /
  unreadable paths stay literal. Bounds: 16 KiB per file (truncated with a marker), 32 KiB total injected
  (== `HOOSH_REQ_CAP/8`, hoosh's per-turn content budget), 16 files max; all buffers are reused module
  globals (no per-call heap on the turn hot path). When nothing resolves, `mention_expand` returns the
  original pointer byte-identically, so ordinary prompts are unchanged.
- Wired into `cmd_task` (echoes the original line, sends the expanded prompt, prints a faint
  `(+N file(s) attached as context)` note) and `cmd_dry` (same expansion in the preview; stays
  side-effect-free + network-free — `mention_expand` only reads files).

### Notes
- Tree-fed **Tab completion** for `@` in the composer is sliced to **`0.21.1`** (a TUI-input enhancement on
  top of this expansion core).
- Residual (documented): the path charset is ASCII, so a filename with non-ASCII bytes isn't matched (the
  token ends at the first non-`[A-Za-z0-9/._-~]` byte) — a first-cut limitation, not a fold.

## [0.20.4] - 2026-07-08

**The model's `shell` tool now works on Windows** — real timed capture with a wall-clock deadline — plus the
Cyrius toolchain refresh to **6.4.26** that unblocked it. This is the deferred `0.20.2` (Windows timed
capture) item, landing out-of-order after `0.20.3` now that 6.4.26 shipped the `TerminateProcess` primitive
(syscall `0xF01D`) that the earlier PE surface lacked — added upstream in response to thoth's filed issue
`2026-07-08-windows-pe-surface-no-terminateprocess`. **Verified end-to-end on a real Windows 11 x86_64 host
(`cass`)** with byte-identical code: capture, merged stdout+stderr, exit-code passthrough, clean over-cap
truncation, deadline kill, and partial-output-on-kill. Pin **6.4.26**. 1021 assertions (Linux unchanged —
the Windows path is `#ifdef`-gated and proven via a minimal `--win` harness, not the host test suite).

### Added
- **Windows `exec_shell_capture`** (`src/exec.cyr`, the `#ifdef CYRIUS_TARGET_WIN` block): replaces the
  0.16.0 announce-but-unsupported stub; `shell_supported()` now returns 1 on Windows. Uses the SAME
  **temp-file** design as the POSIX path (a file, never a pipe — a file has no writer backpressure, so a
  large-output command runs to genuine completion instead of deadlocking on the ~4 KiB anonymous-pipe buffer
  the PE surface can't drain concurrently: no `PeekNamedPipe`/overlapped-I/O/threads). Opens a CWD-relative
  `thoth_sh_<pid>_<n>.tmp` (`CreateFileW`), marks it inheritable (`SetHandleInformation`), redirects the
  child's stdout+stderr to it via the vendored `_win_create_process`, enforces the deadline +
  `TerminateProcess` + reap via the vendored `_win_wait_timeout`, reads the file back, and best-effort
  `DeleteFileW`s it. Runs `cmd /s /c "<cmdline>"` with the environment inherited (PATH reaches cmd.exe).
  The model-supplied command is length-checked against the 16 KiB UTF-16LE buffer and REJECTED fail-closed
  (`{-1,0}`, no spawn) beyond ~8179 bytes; the buffer is a reused module global (no per-call heap leak). A
  pre-cut adversarial review caught both — an uncapped copy would have overrun the buffer, and a fresh
  per-call `alloc` would have leaked on the no-free bump heap; both fixed and re-verified on `cass`.

### Changed
- **Cyrius toolchain 6.4.23 → 6.4.26** (`cyrius.cyml` pin + `cyrius lib sync`): only `lib/process_win.cyr`
  (the new `_win_terminate` / `_win_wait_timeout` primitives), `lib/math.cyr`, and `lib/io.cyr` changed
  content in the vendored floor.

### Notes
- **Windows residuals (documented, never faked):** no process-group kill on this surface, so a timeout that
  leaves a surviving detached grandchild can (a) let it outlive the shell and (b) hold the temp-file handle
  open so its `DeleteFileW` fails and that one temp file lingers in the CWD until the grandchild exits
  (parallels the pre-0.20.1 POSIX single-child behavior); temp file lives in the CWD, not a system temp dir
  (no `GetTempPathW`; a read-only CWD fails closed); no `O_EXCL`/`O_NOFOLLOW` (name-uniqueness + best-effort
  pre-delete; a lower-risk-than-/tmp TOCTOU residual); the exit code is the true unsigned 32-bit Win32 code,
  not the POSIX 0..127/128+sig shape; stdin is not redirected to NUL (a stdin-reading command blocks until an
  honest `-2` timeout).
- The full thoth **`--win` binary remains gated** on the async/epoll→IOCP transport (`lib/async.cyr`); this
  shell capture is verified in isolation and ships with the Windows binary once that separate gate lifts.

## [0.20.3] - 2026-07-08

**Shell `deny`/`allow` glob lists can now be written as natural TOML arrays** — `deny = ["…", "…"]` /
`allow = ["…", "…"]` under `[shell]` — instead of the `label = "glob"` section form that existed only
because bayan (≤ 1.0.4) had no array-value getter. bayan **1.1.0** ships `bayan_toml_get_array`, so the
lists move to the idiomatic form. The legacy `[shell.deny]`/`[shell.allow]` sections still work (documented
back-compat), used only when the array key is absent. 1021 assertions (+11). Pin **6.4.23**.

> `0.20.2` (Windows timed capture) is **deferred**: it needs a `TerminateProcess` primitive the Cyrius
> Windows PE syscall surface does not expose (spawn/wait/capture exist, but nothing can *kill* a timed-out
> child — shipping it would leak). Filed upstream as cyrius issue
> `2026-07-08-windows-pe-surface-no-terminateprocess`; it lands out-of-order once that reroute ships (the
> minimal-`--win`-build → run-on-Windows test pipeline is already proven, so verification is ready).

### Added
- **Array-value shell deny/allow config** (`src/config.cyr`): `[shell] deny = ["glob", …]` / `allow = […]`,
  read via `bayan_toml_get_array` (bayan 1.1.0). The array form is canonical and WINS when its key is
  present — an explicit empty array `deny = []` means "no patterns" and does NOT fall through to a section.
  A bare scalar string (`deny = "*rm -rf*"`, brackets forgotten) is accepted leniently as a SINGLE glob, so
  a deny-list never silently drops to zero patterns. Elements are quote-stripped, blank elements skipped;
  the table still caps at `SHELL_GLOB_MAX` (64). New `_shell_glob_array_load` / `_shell_glob_key_load`.

### Changed
- The legacy `[shell.deny]`/`[shell.allow]` `label = "glob"` SECTION form is now a documented back-compat
  alias, loaded only when the corresponding array key is absent (`thoth.cyml.example` shows the array form
  as canonical). Also corrected the example's stale timeout note — a timed-out command is killed by PROCESS
  GROUP since 0.20.1, so a backgrounded child dies with the shell.

## [0.20.1] - 2026-07-08

**A shell command that backgrounds a grandchild now has that grandchild killed too when the command times
out — not just the `/bin/sh`.** Plus a Cyrius toolchain refresh to 6.4.23. Until now a timeout `SIGKILL`ed
only the direct shell child, so `some-daemon &` (or any backgrounded process) survived and leaked. Now the
child runs in its OWN process group and the timeout kills the whole group. 1010 assertions (+2). Pin
**6.4.23**.

### Fixed
- **Process-group kill on timeout** (`src/exec.cyr`, the Linux `exec_shell_capture`): the child calls
  `setpgid(0,0)` before `execve` (becoming a group leader; the parent also sets it to close the fork race),
  and on timeout the reaper `kill(-pgid, SIGKILL)`s the whole group — the shell AND any backgrounded
  grandchild — then `kill(pid, SIGKILL)`s the child directly (belt-and-suspenders: guarantees the child
  dies so the blocking reap never hangs, even if `setpgid` didn't take). **Safe**: an independent code-trace
  confirmed `kill(-pid)` can never signal thoth's own group (a pgid always equals its leader's pid, so a
  child-pid group is either the child's isolated group or non-existent → ESRCH, never thoth). Grandchildren
  reparent to init; thoth reaps only its direct child (no zombie leak). Declared x86_64-only (matching the
  path's pre-existing raw `poll(#7)`; the aarch64 lane ships size-gapped — the comment documents the exact
  arch-conditional fix if it is ever un-gapped).
- **2 assertions** (`tests/thoth.tcyr`, `test_shell`): a backgrounded grandchild that would touch a marker
  after 1s is confirmed **absent** after a 300ms-timeout kill + a wait past 1s (the group-kill reached it),
  and the backgrounding parent still times out promptly (no hang).

### Toolchain
- **Pin `6.4.21 → 6.4.23`** (`cyrius.cyml` + `cyrius lib sync`, 70 floor modules; only
  `lib/syscalls_x86_64_agnos.cyr` changed — a new `SYS_READLINK` for AGNOS, unused here). Clears the drift
  warning; all lanes behave; 1010 assertions pass.

## [0.20.0] - 2026-07-08

**The `shell` tool now works standalone — the agentic loop runs on `[shell].enabled` alone, no daimon
required.** Opens the 0.20.x shell/agent-hardening line (the 0.16.0 deferred follow-ups). Until now the
agentic tool-calling loop needed an MCP host (daimon) wired, so the thoth-NATIVE `shell` tool — which needs
no daimon — was unusable without one. `agent_enabled()` is relaxed: `[hoosh].tools` stays the master switch,
but the tool SOURCE is now daimon OR the POSIX shell tool. 1008 assertions (+10). Pin **6.4.21**.

### Changed
- **`agent_enabled()`** (`src/agent.cyr`): `[hoosh].tools` required, then daimon-wired → on (unchanged), OR
  `[shell].enabled && shell_supported()` → on (new). Daimon-present and shell-off sessions are byte-identical.
- **Tool advertisement**: only fetches daimon's registry when the seam is present; standalone builds the
  tools array from just the local tools (`agent_format_tools(buf, 0)` → `add_memory` → `add_shell`), a valid
  `[…"shell"…]` array with no network call.
- **`_agent_run_calls` forces serial when daimon is absent, and the serial path refuses a non-local tool
  honestly** — both are **null-deref crash guards** (design-review catch): the parallel executor and
  `daimon_invoke` both `strlen()` the daimon URL via `_daimon_call_endpoint`, which is NULL when daimon is
  absent — so a round of hallucinated non-local tools (default `[hoosh].parallel=on`) would segfault. Now
  the standalone loop never touches daimon; a hallucinated non-local tool returns "(tool not available: no
  daimon wired)".
- **`/state` + `/tools`** reworded for standalone: the agent row shows "shell tool, standalone", the shell
  row's gate note points at `[hoosh].tools`, and `/tools` lists the native `shell`/`memory_write` tools when
  daimon is absent but the loop is on (instead of "no host").

### Security & scope
- shell stays t-ron-gated (`thoth_shell`) + `[shell.deny]`/`[shell.allow]` glob-filtered + local-only,
  never forwarded to daimon — unchanged; this cut only decides WHETHER the loop runs. No new tool is
  advertised and none becomes ungated; security degrades **closed**.
- Scope: keyed only on shell. `memory_write` is also local + daimon-free, but a memory-only standalone
  session intentionally stays `agent_enabled==0` — 0.20.0 targets the POSIX shell tool.

### Tests
- **10 assertions** (`tests/thoth.tcyr`, `test_agent`): the full `agent_enabled()` truth table (daimon
  wired → on; daimon absent + shell → on; shell off / `[hoosh].tools` off → off) by poking the config
  globals (restored after), plus a network-free advertise round-trip proving the standalone tools array
  parses and carries a "shell" tool.

## [0.19.3] - 2026-07-08

**Live spine-health — the status bar shows whether hoosh is reachable, and a transport failure during a
turn marks it down immediately.** Closes the 0.19.x session-visibility line. A cached reachability state
driven by TRAFFIC OUTCOMES (no background timer / idle probe): seeded by the startup greeting's probe,
updated by each turn's transport result, and re-probed on demand with **Ctrl-R**. So the spine going down
mid-session shows up as a red dot next to the model — you don't discover it on the next turn. 998
assertions (+5). Pin **6.4.21**.

### Added
- **Cached health** (`src/hoosh.cyr`): `_hoosh_health` tri-state (UNKNOWN/UP/DOWN) + `hoosh_health()`,
  `hoosh_health_mark_up`/`_down`, `hoosh_health_note(rc)` (a turn's `rc < 0` connection failure → DOWN; any
  answered request, even a non-2xx, → UP), and `hoosh_health_probe()` (a silent `hoosh_reachable` GET →
  UP/DOWN). Driven at two chokepoints: `hoosh_send` notes its `rc`; `agent_turn` marks each round (kind 2
  transport → down, an Esc-interrupt is neutral, everything answered → up).
- **Status-bar dot** (`src/tui.cyr`, `tui_draw_status`): green ● up / red ● down / faint ○ unknown next to
  the model, shown only when a gateway is configured. The startup greeting now seeds the cache via the same
  probe.
- **Ctrl-R re-probe** (`src/tui.cyr`, `KEY_REPROBE`): re-runs the silent reachability probe and notes the
  outcome (`hoosh: reachable / unreachable / absent`) in the feed + refreshes the dot. Legacy byte 18 +
  kitty. No idle poll — health only moves on a turn or an explicit Ctrl-R.
- **5 assertions** (`tests/thoth.tcyr`, `test_hoosh_health`): the mark/note state machine (rc<0 → DOWN,
  rc>=0 incl. a non-2xx → UP, and the mark helpers).

## [0.19.2] - 2026-07-08

**`/git <path>` renders that file's diff** — HEAD blob vs working tree, colored and syntax-highlighted. The
0.13.x deferred follow-up: `/git` already showed branch + changed files; now `/git <path>` shows the actual
diff of one file, computed by sit (`sit_diff_path`) and rendered through the same colored diff renderer
`/read` and write diffs already use. 993 assertions (+7). Pin **6.4.21**.

### Added
- **`diff_render_ann(path, ops)`** (`src/diff.cyr`): colors sit's annotated line-ops (the vec `sit_diff_path`
  returns — one `{kind, line-tuple, old_no, new_no}` record per line) by reusing `_diff_emit_line`
  (line-number gutter + a colored +/-/space gutter + a `detect_language`-highlighted body). A blue path
  header + a `+A -B` count line, then the full annotated file (changes in context) — matching thoth's other
  diff views. sit computes the LCS; thoth colors it.
- **`/git <path>`** (`src/commands.cyr`, `cmd_git(line)` now takes an arg): with a path, opens the repo and
  renders `sit_diff_path(repo, path)`; `sit_diff_path` returns 0 for an unchanged / untracked-and-absent /
  too-large file, reported honestly as "no changes vs HEAD" (never a blank or a fake diff). Bare `/git` is
  the unchanged branch + status listing. Help updated to `/git [path]`.
- **7 assertions** (`tests/thoth.tcyr`, `test_git_diff`): a hand-built ann-ops vec (keep/del/add, in sit's
  32-byte layout) renders to the path header, a `+1 -1` count, and three body lines whose text is preserved.

## [0.19.1] - 2026-07-08

**Live agentic-turn telemetry — the `tool-call:` feed lines now show verdict, elapsed, and result size, and
the spinner names the running tool.** Second slice of the session-visibility line. Each tool call gets a
faint sub-line under its result — `· ok · 142ms · 87B` — and the spinner reads ` running <tool>…` while that
call blocks (` running 3 tools…` for a parallel batch), instead of a generic `working…`. The roundlog thoth
already keeps now records the wall-time + byte count per call, so `/audit` shows them too. 986 assertions
(+2). Pin **6.4.21**.

### Added
- **Per-call telemetry** (`src/roundlog.cyr`): the round-call record gains `ms` (invoke wall-time) + `bytes`
  (result size) fields (`_rl_call_sz` 16→32); `roundlog_add_call(name, kind, ok, ms, bytes)`; new
  `roundlog_call_ms`/`roundlog_call_bytes`; `roundlog_report` (`/audit`) prints `<ms>ms/<bytes>B` per
  allowed call.
- **Live sub-line** (`src/agent.cyr`, `_agent_call_telem`): a faint `    · <verdict> · <ms>ms · <bytes>B`
  under each `result:` (just the verdict for a denied/no-name call). The **serial** path times the
  gate+invoke via `clock_now_ms`; the **parallel** path times each call in its worker (a new
  `elapsed`-ms field in the per-slot ctx, `PAR_CTX_SZ` 48→56, written by the worker and read serially after
  join — each worker owns its slot, no shared write). Emitted through the same sink as the tool-call lines
  (feed at OUT_RING, terminal at OUT_FD1); floor-verbatim at PT_PLAIN; not routed through the reply's
  inline-markdown pass.
- **Spinner label** (`src/tui.cyr`): `_spin_label` + `spin_label_set`/`spin_label_clear`; `spin_paint` shows
  ` running <tool>…`. `agent.cyr` labels the running tool (serial) or `N tools` (parallel batch) and clears
  it after; `spin_begin` resets the label per turn so it never leaks into hoosh-streaming ticks. No-op off
  the TUI.
- **2 assertions** (`tests/thoth.tcyr`, `test_roundlog`): the new `ms`/`bytes` fields round-trip; the
  existing `roundlog_add_call` callers updated to the 5-arg form.

## [0.19.0] - 2026-07-08

**Context-budget meter — you can now see context pressure before hoosh silently drops old turns.** Opens the
0.19.x session-visibility line. hoosh keeps only the newest tail of the conversation whose framed bytes fit
`HOOSH_REQ_CAP/8` (**exactly 32 KiB**); older turns are evicted from each request. That eviction was
invisible — now the status bar and `/state` show the framed history bytes vs the 32 KiB boundary and how
many turns are being dropped. No new producer — just thoth-owned data it already computes each turn. Bundles
a **Cyrius toolchain refresh to 6.4.21** (`cyrius lib sync`). 984 assertions (+10). Pin **6.4.21**.

### Added
- **Context meter** (`src/hoosh.cyr`): pure `hoosh_ctx_budget()` (= `HOOSH_REQ_CAP/8` = 32768),
  `hoosh_ctx_bytes()` (Σ `strlen(content)+16` over all messages — the *identical* unit
  `_hoosh_history_start` budgets against, so bytes-vs-budget IS the eviction decision, not an estimate), and
  `hoosh_ctx_evicted()` (= `_hoosh_history_start`, the count of oldest turns currently dropped).
- **Status bar** (`src/tui.cyr`, `tui_draw_status`): a `ctx <n>K/32K` segment after `turns`, the number
  RED once eviction begins. Omitted when single-turn (`[hoosh].history=false`) or empty (ADR-0010).
- **`/state`** (`src/commands.cyr`): the `context :` row now shows `<n>K / 32K budget` and `N oldest evicted`
  when over budget; a new `empty` branch for a fresh multi-turn session.
- **10 assertions** (`tests/thoth.tcyr`, `test_ctx_meter`): the budget constant; byte accounting for
  0/1/2 messages; and the eviction boundary (two ~20 KiB messages exceed 32 KiB → the oldest is evicted).

### Toolchain
- **Pin `6.4.20 → 6.4.21`** (`cyrius.cyml` + `cyrius lib sync`, 70 floor modules; only
  `lib/tls_native_hs13.cyr` changed — a small TLS-1.3 handshake update). All lanes behave; 984 assertions
  pass. NOTE: the local `cycc` wrapper has since advanced to **6.4.22**, so a residual drift warning remains
  — a future refresh clears it.

## [0.18.8] - 2026-07-08

**Inline markdown in the reply feed — headings, bold, inline code, and list markers are now styled, not
just fenced code.** Closes the 0.18.x re-renderable-feed line. A new inline pass in `mdhl` styles each PROSE
line as it streams; the styling is display-only (the raw reply in `_hoosh_acc` → history/`--json`/`-o` is
untouched) and composes with everything the feed already does: colors go through role MARKERS so **`/theme`
recolors** inline markdown, and a **feed search** match highlights correctly inside a styled heading or bold
span. Every construct only *wraps* its bytes in SGR — `strip_sgr(output) == the raw line` (the 0.15.1
discipline, property-tested). ASCII and PT_PLAIN are byte-identical. 974 assertions (+19). Pin **6.4.20**.

### Added
- **Inline markdown styling** (`src/mdhl.cyr`): the prose branch of `_mdhl_line_done` now calls
  `_mdhl_inline_line` (was `_mdhl_put_line`). Per complete prose line: an **ATX heading** (`#`..`######` +
  space) → whole line `ROLE_ACCENT`; a **blockquote** (`>`) → `ROLE_MUTED`; a **list marker**
  (`-`/`*`/`+` + space, or `N.`/`N)` + space) → the bullet `ROLE_ACCENT`; **inline code** `` `…` `` →
  `ROLE_BLUE` (highest precedence, its interior not re-scanned); **bold** `**…**` → `\x1b[1m`. Each span is
  closed by `ui_reset()` → a RESET marker, which clears `feed_clip_seg`'s soft-wrap carry (so inline spans
  never overflow it) and keeps `/theme` recolorable; spans do not nest. The inline scanner is **linear** (a
  failed forward close-scan latches that delimiter off — no closer can exist further right). Fenced code,
  continuation lines (>2048 B), and PT_PLAIN keep the verbatim path.
- **Search composes with bold** (`src/fsearch.cyr`): `fsearch_render` now tracks a `bold_open` flag (set on
  a stored `\x1b[1m`, cleared by a reset) and re-asserts `\x1b[1m` after a match-OFF — so highlighting a word
  inside a `**bold**` span no longer un-bolds the rest of it (headings/inline-code already composed via the
  role-marker `active_role` restore; bold was the one gap, caught by the pre-cut design review).
- **19 assertions** (`tests/thoth.tcyr`, `test_mdhl_inline`): heading / bold / inline-code / ordered +
  unordered list styling, each strip-covering back to the raw line; code precedence (`` `**x**` `` not
  bolded); an unmatched `**` left verbatim; the PT_PLAIN floor; and two compose cases — a search match inside
  a heading, and the bold re-assert after a match inside `**hello world**`.

### Notes
- Not yet styled (declared): single-`*`/`_` italic (ambiguous with lists/math), links, strikethrough,
  nesting, and any inline construct inside a heading or on a >2048-byte continuation line.

## [0.18.7] - 2026-07-08

**A glyph-width table — CJK/emoji lines now count 2 columns in the soft-wrap and scrollback math, instead
of overflowing.** Closes the 0.11.3 declared undercount: every glyph was counted as one terminal column, so
a line of CJK or emoji was reckoned half its true width and would spill past the feed column. A new
`feed_glyph_cols` decodes each glyph's codepoint and returns its display width (0 for combining/zero-width
marks, 2 for East-Asian Wide/Fullwidth glyphs + emoji, else 1), and all three feed column-counters use it —
so `feed_rows_for = ceil(display-columns / width)` stays consistent and a wide line wraps into the right
number of rows. ASCII output is byte-identical (width 1). 955 assertions (+14). Pin **6.4.20**.

### Changed
- **`feed_glyph_cols(src, i, gl)`** (`src/feed.cyr`): decodes the UTF-8 codepoint and classifies width via
  the common Unicode blocks — zero-width (combining 0x300–0x36F/0x1DC0–/0x20D0–, ZW joiners/space, variation
  selectors, BOM), wide (Hangul, CJK Unified + Ext A/B–F, Kana, Yi, fullwidth forms, and the emoji blocks
  0x2600–0x27BF + 0x1F000–0x1FAFF), else 1. `feed_visible_cols` (cached as `_feed_vis` at seal),
  `feed_clip`, and `feed_clip_seg` now add the glyph's width, not 1.
- **`feed_clip` (tree column) refuses a straddling wide glyph** rather than bleeding it into the feed pane to
  its right (`(cols + gw) <= max_cols`), and latches strict left-to-right truncation on the first refusal (a
  later narrow glyph can't slip into the freed column ahead of it — the diff-review catch).
- **Declared residuals** (honest limits, in the module comment): a wide glyph that straddles a *soft-wrap*
  boundary clips 1 column at the feed's right edge (the feed is the rightmost pane, so the terminal clips it
  — no pane corruption, and no glyph is lost or duplicated); EAW-Ambiguous symbols in 0x2600–0x27BF are
  treated wide (matches emoji rendering, may over-widen a few text symbols); a ZWJ emoji *sequence*
  overcounts; and a few scattered BMP emoji outside the listed blocks (e.g. U+2B50 ⭐) still count 1.
- **14 assertions** (`tests/thoth.tcyr`, `test_glyph_width`): `feed_glyph_cols` for ASCII / Hiragana / CJK /
  fullwidth / dingbat-emoji (U+2705) / plane-1 emoji (U+1F600) / combining / variation-selector; a wide line
  wrapping to 2 rows at width 3; `feed_clip` refusing a straddler + the strict-truncation swap guard;
  `feed_clip_seg` segmenting a wide line across a wrap.

## [0.18.6] - 2026-07-08

**The composer prompt returns immediately after a gate approval, instead of staying stuck until the turn
ends.** Live-testing surfaced it: when a t-ron gate confirm fires mid-turn, `confirm` (src/gate.cyr) brackets
to the live screen via `tui_confirm_begin`/`tui_confirm_end` so the `[y/N]` prompt and its cooked echo are
visible; but `tui_confirm_end` only resumed feed capture + the spinner — it never repainted the composer, so
the `…authorize …? [y/N] y` line lingered on the composer row until the whole response finished. Now
`tui_confirm_end` repaints the frame the instant the user answers (while still on OUT_FD1, so the chrome goes
to the screen, not the feed ring) — the `{(o>` prompt is restored and the spinner shows the turn continuing.
TUI-only; the REPL/piped confirm path never calls these hooks, so it stays byte-identical. 941 assertions
(unchanged). Pin **6.4.20**.

### Fixed
- **`tui_confirm_end` repaints the composer** (`src/tui.cyr`): `tui_repaint_body()` runs as its first step —
  before `out_mode_set(OUT_RING)` resumes capture — clearing the confirm prompt + echo and restoring the
  composer/frame immediately. An independent code-trace verified the out_mode balance (guaranteed OUT_FD1 at
  entry, so no ring corruption), that `tui_repaint_body` is read-only from the ring (safe mid-dispatch), and
  that the confirm text is never sealed into the feed. No behavior change off the TUI.

## [0.18.5] - 2026-07-08

**Feed search counts and jumps by OCCURRENCE, not by line.** Live-testing 0.18.4 surfaced it: a search for
`echo` over a reply where one line reads `bote_echo … empty echo` showed `2/2` (two matching *lines*) while
three `echo` spans were highlighted. Now the `i/n` count and n/N step **every hit**, and a line with several
matches highlights the **current** occurrence (by its byte offset) reverse+underline while the others stay
reverse. Match state is now per-occurrence — `(line, start-offset)` per hit — so navigation lands on the
exact occurrence. Feed-search-only; the floor is unchanged. 941 assertions (+5). Pin **6.4.20**.

### Changed
- **Occurrence-granular match model** (`src/fsearch.cyr`): `_fsearch_mline[k]` / `_fsearch_moff[k]` record
  the line **and** start offset of every non-overlapping hit (`_fsearch_add_line` walks a line exactly as
  `fsearch_render` does, so the recorded offsets coincide with the render's match-starts); `fsearch_rescan`
  records all occurrences (over the ring **and** the pending line), `fsearch_next` / `fsearch_prev` step
  occurrences, and `fsearch_render` now takes the current occurrence's `cur_off` (or -1) instead of a
  whole-line current flag — so exactly one occurrence is drawn current. `feed_repaint` passes
  `coff = (li == fsearch_cur_line()) ? fsearch_cur_off() : -1`.
- **Cap is announced, not silent** (design principle): the per-occurrence match cap (`FSEARCH_MATCH_CAP`,
  8192) can be reached by a very broad query over a full ring; when it is, the hint shows `i/n+` (the count
  is a floor, never a faked total) via a new `fsearch_saturated`. Caught by the pre-cut diff review.
- **5 assertions** (`tests/thoth.tcyr`, `test_fsearch`): a single line with two `echo` hits counts as 2 and
  n/N steps between the two offsets (the exact screenshot case); the render tests now pass an occurrence
  offset for the current-match styling.

## [0.18.4] - 2026-07-08

**Feed search — Ctrl-F / `/find` over the scrollback: highlight matches inline, jump between them with
n/N.** The next payoff of the 0.18.0 re-renderable feed. A new pure engine (`src/fsearch.cyr`) matches the
query against the *visible* text of every ring line (case-insensitive ASCII, transparent to the stored role
markers and any interleaved escapes), and a modal in the TUI highlights the matches and scrolls the current
one into view. **Net-floor-safe by construction**: the highlighter injects reverse-video SGR into a per-line
temp buffer that is handed to the **unchanged** `feed_clip_seg` — the injected escapes are just more
zero-width escapes it already carries across a soft-wrap. TUI-only; the piped/REPL/one-shot floor is
byte-identical. 936 assertions (+26). Pin **6.4.20**.

### Added
- **`src/fsearch.cyr` — the pure search engine** (unit-tested, no TTY): `fsearch_line_has` /
  `_fsearch_match_at` (glyph-aligned, escape-transparent, case-insensitive ASCII matching — a multi-byte
  UTF-8 query compares byte-exact, a declared limitation); `fsearch_render` (the highlighted-line render);
  `fsearch_rescan` / `fsearch_next` / `fsearch_prev` (the match-list state machine over the ring **and** the
  pending line); incremental query edit.
- **Ctrl-F / `/find [text]` modal** (`src/tui.cyr`, `src/commands.cyr`): Ctrl-F opens an incremental search
  (type the query, the feed highlights + jumps to the newest match as you go); **Enter** commits to a nav
  phase where **n / N** (and ↓/↑, Enter) jump newer/older between matches; **Ctrl-C** closes (Esc is
  best-effort). `/find <text>` jumps straight into nav; bare `/find` opens the input. Outside the TUI it
  announces honestly and does nothing (no re-renderable feed to highlight). The current match is drawn
  reverse+underline, others reverse; the hint row shows `find: <q>  (i/n)  ↑/N older · ↓/n newer · ⌃C close`.
- **`ui_match_on(cur)`** (`src/ui.cyr`): the match SGR (reverse, or reverse+underline for the current
  match), `""` at PT_PLAIN. **`feed_phys_before(li, width)`** (`src/feed.cyr`): soft-wrap physical-row
  distance to line `li`, for scroll-to-match. `feed_clip_seg` itself is **unchanged**.
- **26 assertions** (`tests/thoth.tcyr`, `test_fsearch`): the matcher (case-insensitive, escape-transparent,
  empty-query); the render (reverse injected, visible text preserved, current-vs-other SGR); the
  **interior-reset re-assert** and a **wrap-straddle** case (render piped through `feed_clip_seg` with a
  skip window so the reset lands in the SKIP region — proves reverse resumes at the wrap via the carry
  re-flush); a **bounded-carry** many-match wide-line case; the PT_PLAIN floor (render == src verbatim); and
  rescan/next/prev over the ring + the pending line.

### Design/review notes
- The pre-cut **design review** caught three issues, all folded before implementation: an **EOF busy-spin
  hang** (the modal shadowed the normal EOF teardown → `_tui_search_key` now tears the loop down on
  `KEY_EOF`); a **64-byte carry overflow** (many bare `ESC[27m` match-offs on a wrapped line's off-screen
  prefix would overflow `feed_clip_seg`'s carry → match-off is now a **reset marker + active-role restore**
  that collapses the carry to O(1) and is theme-correct); and **cursor mis-parking** on full repaints
  (`tui_park_cursor` now gates on the search modal → covers SIGWINCH / `/theme` / `/find`-entry). The
  as-built **diff review** raised zero findings.

## [0.18.3] - 2026-07-07

**Live-upgrading fenced-code card — the streamed code appears line-by-line, then snaps to highlighted at
the closing fence.** The long-deferred 0.15.1 "Option C", finally unlocked by 0.18.0's re-renderable feed.
Until now a streamed ```` ```lang ```` block was *withheld*: `mdhl` buffered every interior line and emitted
the whole highlighted block only at the closing fence, so the code was invisible mid-stream (the spinner
covered the gap). Now the interior lines emit **live** (unhighlighted) as they arrive, and at the closing
fence — or on an interrupt / truncated completion — the live rows are **dropped and re-emitted
syntax-highlighted**, an in-place upgrade. TUI-only and **net-result-preserving**: the final feed state is
the identical highlighted block, so the floor is untouched. 910 assertions (+15). Pin **6.4.20**.

### Added
- **Live fenced-code card** (`src/mdhl.cyr`): `_mdhl_block_put` now emits interior lines live when
  `out_mode() == OUT_RING` (`_mdhl_live()`), counting sealed rows in `_mdhl_block_rows` while still buffering
  the interior for the at-close highlight. New `_mdhl_block_close()` performs the upgrade — `feed_drop_last`
  the live rows + `feed_drop_pending` any un-sealed partial, then `_mdhl_block_flush` re-emits highlighted —
  and is wired into both the fence-close branch of `_mdhl_line_done` and `mdhl_finish` (so an interrupted or
  unterminated block upgrades honestly). The **line REPL** (OUT_FD1) keeps the withhold-until-close behavior
  (a terminal it can't rewind); **PT_PLAIN** stays verbatim.
- **Feed drop primitives** (`src/feed.cyr`): `feed_drop_last(n)` removes the most-recent `n` sealed rows
  (clamped to `_feed_count`; slots reused by the next seals); `feed_drop_pending()` discards an un-sealed
  partial line. Both are counter-only — no ring corruption, no OOB — and are dead no-ops off OUT_RING.
- **15 assertions** (`tests/thoth.tcyr`, `test_mdhl_livecard`): the drop primitives (drop-last clamps to 0,
  drop-pending clears the partial); a well-formed block streamed in chunks that split every token/delimiter
  upgrades to exactly `[opener verbatim, interior highlighted, closer verbatim]` with **no leftover live
  rows**; a **regression guard** for an unterminated block whose last interior line has no trailing newline
  (an interrupt) — the live partial must not double with the highlighted re-emit; and a ```` ```text ````
  no-grammar block stays verbatim.

### Fixed
- **Over-clamp guard** (`src/mdhl.cyr`, `_mdhl_block_close`): a single fenced block whose live interior
  exceeds the feed ring (`> FEED_ROWS` logical lines, but under `MDHL_BLOCK_CAP`) evicts the opener/prior
  rows while streaming; `feed_drop_last(_mdhl_block_rows)` would then over-clamp and wipe unrelated ring
  content. The upgrade now runs only when the drop is exact (`_mdhl_block_rows <= feed_count()`); a block
  larger than the ring falls back to leaving its live verbatim rows (unhighlighted). Caught by the pre-cut
  adversarial diff-review.

## [0.18.2] - 2026-07-07

**Maintenance: re-sync the vendored bote-core to 3.0.1 + a toolchain refresh to Cyrius 6.4.20.**
Follows a full-stack MCP-tool investigation that fixed two upstream conformance bugs (bote 3.0.1 wraps
`bote_echo`, daimon 1.3.5 wraps its `libro_*` built-ins, both in MCP content blocks — see those repos'
changelogs). thoth itself needed **no source change** for the tools to work (it was already a correct,
strict MCP client — it honestly reported "no text content" for the non-conformant results); with the spine
fixed, `/call bote_echo`, `/call libro_query`, and the agentic tool loop now render tool output. This cut
just realigns thoth with the released spine + toolchain. 895 assertions unchanged. Pin **6.4.20**.

### Changed
- **Re-synced `src/vendor/bote-core.cyr` to bote 3.0.1** (`scripts/sync-bote.sh`). The vendored bundle is
  bote's `[lib.core]` MCP dispatcher (referenced by the vendored t-ron); bote's `bote_echo` fix was
  server-side (`main_common.cyr`, not in `[lib.core]`), so the only content delta is the embedded
  `_bote_server_version()` string (3.0.0 → 3.0.1) — the dispatcher code is byte-identical. No behavior change.
- **Toolchain pin `6.4.19 → 6.4.20`** (`cyrius.cyml` + `cyrius lib sync`, 70 floor modules, zero content
  change). Clears the drift warning (the wrapper had advanced to 6.4.20) and realigns thoth with the
  bote 3.0.1 / daimon 1.3.5 patches (both now on 6.4.20). All build lanes behave (linux ships, AGNOS
  builds, aarch64 size-gapped, windows IOCP gap, macOS native-runner skip); 895 assertions pass unchanged.

## [0.18.1] - 2026-07-07

**`/theme` recolors scrollback — the 0.18.0 keystone's first payoff. Plus a Cyrius 6.4.19 refresh.**
Because the feed ring now stores role MARKERS (0.18.0) rather than baked SGR, a theme switch already
recolors the whole window: `ui_set_theme` rebuilds the SGR table and the post-dispatch `feed_repaint`
(for `/theme`) / `tui_relayout` (for ⌃T) RE-EXPANDS every stored marker with the new theme. This closes
the **0.10.0 limitation** ("existing feed lines keep their baked colors; `/clear` for a clean window") for
all role-colored text and syntax highlighting — no code change beyond validating it and correcting the
docs. Bundles the **toolchain refresh to Cyrius 6.4.19** (pin-only: `cyrius lib sync` re-vendored the
declared floor subset with **zero content change**; drift cleared). 895 assertions (+5). Pin **6.4.19**.

### Changed
- **`cmd_theme` doc corrected** (`src/commands.cyr`): the switch now recolors existing scrollback (via the
  0.18.0 marker store + the post-dispatch repaint), not just chrome + new output. **Residual, documented:**
  diff-row background TINTS (`ui_bg`) are stored verbatim (not markers), so they do not recolor on a switch
  — a bounded follow-up (the fg text + syntax colors, the bulk of the feed, recolor fully).
- **5 assertions** (`tests/thoth.tcyr`, `test_feed_markers`): paint one stored marker slot under dark then
  light and assert the painted SGR **differs** while the stripped text is identical (`"hi"`) and both are
  colored — proving the same scrollback slot recolors across a theme switch.

### Toolchain
- **Pin `6.4.18 → 6.4.19`** — source-change-free; zero floor-content delta (the 6.4.19 changes were
  elsewhere in the toolchain); clears the drift warning. All build lanes behave (linux ships, AGNOS builds,
  aarch64 size-gapped, windows IOCP gap, macOS native-runner skip).

## [0.18.0] - 2026-07-07

**The re-renderable feed — the ring stores role metadata, SGR is applied at paint. Plus a Cyrius 6.4.18 refresh.**
Opens the 0.18.x line. The feed ring used to store PAINTED bytes (the current theme's concrete SGR baked
into each slot), which is why `/theme` could not recolor scrollback (0.10.0 limit) and why the 0.15.1 live
fenced-code card was deferred. The ring now stores logical text + compact **role MARKERS**, and the painter
**expands a marker to the current theme's SGR at paint time** — with **byte-identical rendered output** for
the current theme (a golden test proves it on both paint paths). This is the architectural keystone; the
payoff (theme-recolor scrollback, the live card, feed search, glyph-width) is the later 0.18.x items.
Bundles the **toolchain refresh to Cyrius 6.4.18** (pin-only: `cyrius lib sync` re-vendored the declared
floor subset with **zero content change** — the 6.4.17/6.4.18 changes were elsewhere; drift cleared). 890
assertions (+15). Pin **6.4.18**.

### Added / Changed
- **Role markers** (`src/feed.cyr`): a marker is `ESC` + a private byte — `0xB0..0xB7` (role 0..7) or
  `0xBF` (reset). To the existing escape scanner a marker is a 2-byte escape, so it is zero visible width,
  copied whole, and never severed — **no scanner change**. `feed_visible_cols` / soft-wrap row math are
  unchanged (a marker is zero-width, exactly like the SGR it replaces).
- **`ui_role_of_sgr`** (`src/ui.cyr`): reverse-maps an SGR escape to its semantic role by an **exact
  whole-string byte match** against the 8 cached role SGR prefixes + the reset (so `ui_reset_fg` `ESC[39m`,
  `ui_bg`, `ui_eol` are never matched — diff-row output stays verbatim + byte-identical). `ui_sgr` itself
  is **unchanged** (the many `emit_raw(ui_sgr(role))` paint-path sites — spinner/tree/rule — that run while
  `OUT_RING` is set must keep getting concrete SGR; the capture happens at store time, not in the emit
  layer).
- **`_feed_pack`** (`src/feed.cyr`): the seal-time reverse-map — rewrites each recognized role/reset SGR to
  its 2-byte marker, preserves `_feed_safe_copy`'s contracts (whole-unit truncation at `FEED_LINE_CAP`,
  drop a severed trailing escape), and **sanitizes** a raw `ESC` + `0xB0..0xBF` in untrusted captured
  output (drops that ESC) so the marker space is **unforgeable** by content.
- **Paint-time expansion** (`feed_clip` + `feed_clip_seg`, both the PAINT phase and the soft-wrap SKIP/carry
  phase): a role marker expands to `ui_sgr(role)`, a reset marker to `ui_reset()`, using the **expanded
  length** in the capacity check; the soft-wrap carry stores the expanded SGR so color continues correctly
  across a wrap. `PAINT_CAP` raised `2112 → 24576` to fit a marker-dense slot's expanded worst case (a
  one-time alloc; the ring is already ~4 MiB).
- **15 assertions** (`tests/thoth.tcyr`, `test_feed_markers`): reverse-map exactness (`ui_reset_fg` stays
  verbatim), packing (a `ui_emit` line stores a 2-byte marker; visible-cols unchanged), the **byte-identical
  golden** on BOTH `feed_clip` and the real paint path `feed_clip_seg`, the collision sanitizer, a non-role
  escape passing through verbatim, and color continuing across a soft-wrap segment boundary.

### Process
- **Two-pass adversarial review** (Workflow): an understand phase confirmed a mode-aware `ui_sgr` would be
  unsafe (paint-path `emit_raw(ui_sgr)` sites) → reverse-map at store; a **design pass** (3 lenses) caught a
  load-bearing blocker (the marker-expand branch is required in feed_clip + both feed_clip_seg phases), the
  `PAINT_CAP` expansion-sizing, the exact-match requirement, and folded a collision sanitizer; a **diff pass**
  (3 lenses, each finding independently adversarially verified) surfaced one should-fix (add a
  `feed_clip_seg` byte-identical golden — the real paint path) and otherwise **zero defects**. **The live
  render verifies on a real tty (`--tier=rich`); the byte-identical property is harness-proven.**

## [0.17.4] - 2026-07-07

**Turn interrupt — Esc aborts a streaming turn without exiting the session. Closes the 0.17.x line.**
Pressing **Esc** during a streaming turn (plain or agentic) now stops it cleanly: the partial output stays
in the feed with an honest `— interrupted` marker (never presented as a complete answer), the conversation
history stays consistent, and control returns to the composer — where before, only Ctrl-C (which tears down
the whole session) could stop a runaway turn. TUI-only and Linux-gated (the poll uses termios ioctls that
are `#ifdef CYRIUS_TARGET_LINUX`); the REPL/piped/one-shot floor is **byte-identical** by construction.
875 assertions (unchanged — the cut is terminal I/O + turn-loop integration with no meaningful new pure
seam; verified by the two-pass review + live tty). Pin **6.4.16**.

### Added
- **`intr_*` interrupt module** (`src/tui.cyr`): `intr_reset` (per-turn), `intr_arm`/`intr_disarm`
  (per-stream — install/restore a non-canonical, non-blocking `VMIN=0/VTIME=0` termios so a lone Esc is
  readable while a turn runs in cooked mode; **gated on `out_mode()==OUT_RING`** so only the TUI capture
  path ever touches the terminal), `intr_poll` (drain pending stdin per SSE frame; any Esc → set the flag),
  `intr_pending`, and `intr_note` (the feed-only marker). arm/disarm use a PRIVATE saved-termios buffer
  and never touch darshana's raw-mode bookkeeping, so `tui_run_line`'s post-dispatch `tty_raw(0)` still
  re-enters the TUI cleanly. The ioctls are `#ifdef CYRIUS_TARGET_LINUX`; off Linux the whole thing
  no-ops (no interrupt), matching darshana's own termios gating.
- **Streaming abort wiring**: both SSE callbacks (`_hoosh_sse_cb`, `_agent_sse_cb`) call `intr_poll()` and
  `return 0` on Esc (sandhi stops the stream cleanly). The stream wrappers (`_hoosh_stream_turn`,
  `_agent_iter_stream`) bracket the stream with `intr_arm`/`intr_disarm` and, on `intr_pending()`, land the
  partial: `hoosh_send`'s existing "append the accumulated reply if non-empty, else roll back the user
  turn" branch already keeps a consistent user+assistant pair; `agent_turn` gains a new **interrupted
  outcome (kind 4)** that appends the partial (or pops the user turn) and ends the loop — deliberately
  *keeping* the partial (unlike the max-iters branch, which clears it).

### Fixed / Process
- **Blocker caught in the design pass** (folded before code): `agent_turn`'s round dispatch was three bare
  `if`s; a non-returning `kind==4` arm would have fallen through into the `k==1`/`else` block and
  double-appended (or, with no content, double-popped) history. The dispatch is now a single
  `if/elif/elif/elif/else` chain so exactly one arm runs.
- **Documented limitations** (honest, by design): interrupt is **streaming-only** — a blocking turn
  (`[hoosh].stream=false`) is one synchronous POST and is not interruptible mid-flight. The Esc poll runs
  per SSE frame, so a **stalled** stream (gateway connected but sending nothing) is only interruptible
  when the next frame arrives or sandhi's read timeout fires. An Esc pressed during tool execution (cooked
  mode) lands at the next streaming frame. An aborted turn's token/cost may be incomplete (the trailing
  usage frame is skipped — omit-until-seen). All announced, never faked.
- **Two-pass adversarial review** (Workflow): an understand phase mapped the streaming/agent/terminal/
  history mechanics; a **design pass** (3 lenses) caught the dispatch blocker + the stalled-stream limit;
  a **diff pass** (3 lenses, each finding independently adversarially verified) returned **zero findings**.
  **The live interrupt behavior verifies on a real tty (`--tier=rich`), not the harness.**

## [0.17.3] - 2026-07-07

**OSC 52 clipboard copy — `/copy` writes the last model reply to the system clipboard.**
Continues the 0.17.x input-completeness line. `/copy` base64-encodes the last reply and writes an OSC 52
set-clipboard escape (`ESC ] 52 ; c ; <base64> BEL`) straight to the terminal — a byte write, no
fork/exec/dup2, so it **works on AGNOS and over SSH** (the AGNOS lane builds it). Best-effort by nature
(OSC 52 is fire-and-forget — a terminal may ignore it or a tmux/screen wrapper may swallow it, and we can't
read back success), so the announcement never asserts it landed. REPL + TUI; gated on a real terminal
(`ui_isatty(1)`) so piped/CI/one-shot output is never polluted with the escape. 875 assertions (+3). Pin
**6.4.16**.

### Added
- **`/copy` command** (`src/commands.cyr`, `cmd_copy`): reads `hoosh_last_reply()` (the accumulator,
  bounded by `HOOSH_ACC_CAP` = 64 KiB, so no truncation is needed), base64-encodes it with
  `bayan_base64_encode`, and writes `ESC ] 52 ; c ; <base64> BEL`. The escape goes to fd1 via `emit_raw` +
  a raw `SYS_WRITE` **write-all loop** (a single tty write can short-write an ~87 KB payload), which bypass
  the `OUT_RING` feed sink (an escape is terminal control, not feed text — the same path the kitty/mouse
  enable escapes use); the announcement uses the normal sink so it lands in the feed / stdout. Guards: an
  empty reply → "nothing to copy yet"; a non-tty stdout → "clipboard copy needs a terminal"; a failed
  write → an honest failure note. `CMD_COPY` wired through `classify_input` / `_dispatch_d`, a `/help` line,
  and the TUI slash palette (`/copy`). BEL (not ST) terminates the OSC — the more widely accepted form.
- **Not t-ron-gated** — `/copy` only SETS the clipboard (never emits an OSC 52 query to READ it) with
  content the user can already see, the same ungated display class as `/read`; no file/exec/network surface.
- **3 assertions** (`tests/thoth.tcyr`): `/copy` → `CMD_COPY` in `test_classify`; the slash-palette counts
  (`/c` → 3 = /call+/clear+/copy, `/co` → 1, `/copy` → 1). The OSC 52 emit + clipboard are live-tty verified.

### Process
- **Two-pass adversarial review** (Workflow): a **design pass** (2 lenses — correctness/routing, integration/
  security/tests) returned no blockers and confirmed the escape correctly bypasses `OUT_RING` to fd1, the
  base64 length formula and write-all loop, and the no-t-ron/security posture; it folded a should-fix (do
  BOTH palette edits — `SLASH_N`→17 and the `_slash_name` branch — and update the `/c` count) and a nit
  (gate on `ui_isatty(1)`, matching the tier probe, rather than `tty_isatty` — they can disagree on AGNOS).
  A **diff pass** (2 lenses, each finding independently adversarially verified) returned **zero findings**.
  **The live clipboard behavior verifies on a real tty (`--tier=rich` or the line REPL), not the harness.**

## [0.17.2] - 2026-07-07

**SGR mouse — wheel scrolls the feed, click focuses the composer/tree, a tree-row click selects/expands.**
Continues the 0.17.x input-completeness line. The T2 TUI now enables SGR mouse reporting (`CSI ?1000h` +
`CSI ?1006h`) on enter (disabled on every exit, paired with the kitty/bracketed-paste push/pop) and decodes
`ESC[<Cb;Cx;Cy(M|m)` events: the wheel scrolls the feed (in any focus), a left-click in the file-tree pane
selects the node under the cursor (a directory toggles expand/collapse, a file just selects) and focuses the
tree, and a click anywhere else focuses the composer. Pure decode + the existing scroll/focus/tree seams;
TUI-only, so the line REPL / piped / one-shot / CI floor is **byte-identical** by construction (every new
symbol lives only in `src/tui.cyr`). 872 assertions (+11). Pin **6.4.16**.

### Added
- **Decode** (`src/tui.cyr`): new `KEY_MOUSE`. `tui_read_key` branches on the `ESC[<` private prefix to
  `_tui_read_mouse`, which reads `Cb;Cx;Cy` + the final `M`/`m` (until the terminator or EOF) and calls the
  pure `_tui_mouse_decode(cb, final)`: a wheel (button bit 64) maps buttons 0/1 to `KEY_SCROLL_UP`/`_DOWN`
  (reusing the existing feed-scroll arm — so the wheel scrolls the feed in any focus) while a horizontal
  wheel (66/67) is ignored; a **left-button press** (`cb & 3 == 0`, not motion, final `M`) becomes
  `KEY_MOUSE` with the coords stashed; release (`m`), middle/right, and motion are ignored. The normal CSI
  path (arrows, `~`, kitty CSI-u, paste) is untouched — `ESC[<` occurs for no other key.
- **`_tui_mouse_click`** (`src/tui.cyr`): a left-click in the tree pane (shown; within columns `[1, tw]`
  and the feed-band rows) maps the screen row to the tree node via the SAME `_ftree_scroll_first` geometry
  the painter uses (`li = first + (row - feed_top)`), `ftree_set_sel`s it, and — for a directory — toggles
  expand/collapse (`tui_relayout`, the visible row count changed); a file just moves the selection; a click
  elsewhere focuses the composer. Wired as a `tui_loop` dispatch arm placed before the `FOCUS_TREE` branch
  so a click sets focus regardless of the current focus.
- **`tui_mouse_enable`/`tui_mouse_disable`** (`CSI ?1000h?1006h` / `?1006l?1000l`), wired into the
  `tui_loop` enter/teardown next to the kitty/bracketed-paste pair — balanced on every exit so the terminal
  is never left in mouse-reporting mode after thoth quits. A terminal that ignores the mode sends no events
  (degrades to no mouse). Trade-off (documented): while mouse mode is on the terminal routes clicks to thoth,
  so native click-drag selection in the feed is intercepted — Shift+drag bypasses it in most terminals.
- **11 assertions** (`tests/thoth.tcyr`, `test_tui`): the pure `_tui_mouse_decode` across wheel up/down
  (with and without modifier bits), horizontal-wheel ignored, left press → click, release/middle/right/
  motion/no-terminator → ignored.

### Process
- **Two-pass adversarial review** (Workflow): a **design pass** (3 lenses — decode, click-mapping, integration)
  returned no blockers and folded two decode nits (drop the reader byte-cap → read to the `M`/`m` terminator
  so an over-long report can't desync stdin; gate the wheel strictly to buttons 0/1 so a horizontal wheel is
  ignored rather than scrolling vertically). A **diff pass** (3 lenses, each finding independently adversarially
  verified) returned **zero findings**. **The live mouse behavior verifies on a real tty (`--tier=rich`), not
  the harness** — the unit tests cover the pure decode; the reader + click mapping are live-tty verified (like
  the rest of the tree interaction).

## [0.17.1] - 2026-07-07

**Word-wise composer editing — readline-basics parity in the raw-mode composer.**
Continues the 0.17.x input-completeness line. The T2 composer gains **word motion** (Ctrl/Alt-Left/Right,
plus Alt-b/Alt-f), **Ctrl-W** (delete the word before the cursor), and **Ctrl-K** (kill from the cursor to
end of line). All the new logic is pure and unit-tested; TUI-only, so the line REPL / piped / one-shot / CI
floor is **byte-identical** by construction (every new symbol lives only in `src/tui.cyr`). 861 assertions
(+36). Pin **6.4.16**.

### Added
- **Pure word ops** (`src/tui.cyr`, before `led_feed`): `_led_is_wsep` (a word separator is space or
  newline — punctuation is a word char, the WERASE/bash convention shared by motion and Ctrl-W);
  `_led_word_left`/`_led_word_right` (the word-boundary index either side of the cursor over the flat
  buffer, crossing embedded newlines; the `i > 0` term is FIRST in every leftward loop so `&&`
  short-circuits before the `load8` — no OOB read at column 0); `_led_delword` (Ctrl-W: delete
  `[word-start, cursor)` via the same bounded shift idiom as backspace); `_led_kill_eol` (Ctrl-K: kill to
  end of the current logical line, or, when already at end-of-line, delete the newline to join the next
  line — the emacs/readline semantics; a no-op at the buffer end). Wired into `led_feed` alongside the
  existing motion/delete keys (all `ACT_NONE`, so word ops never submit).
- **Decode** (`src/tui.cyr`): four new keys `KEY_WORD_LEFT`/`KEY_WORD_RIGHT`/`KEY_DELWORD`/`KEY_KILL_EOL`.
  `_tui_csi_final` routes a modified Left/Right arrow (`CSI 1;<mod>C/D` with `mod >= 3`, i.e. any Ctrl or
  Alt combo) to word motion while plain (`-1`) and Shift (`2`) stay ordinary arrows (no regression);
  `tui_read_key` maps the control bytes Ctrl-W (23) and Ctrl-K (11), and the ESC-prefix Alt-b/Alt-f
  (`ESC b`/`ESC f`) to word motion; `_tui_kitty_u` decodes the kitty CSI-u forms (Ctrl-W `119;5`,
  Ctrl-K `107;5`, Alt-b `98;3`, Alt-f `102;3`) so the bindings work under the kitty keyboard protocol too.
- **36 assertions** (`tests/thoth.tcyr`, `test_tui`): the CSI/kitty decode (including the no-regression
  plain/Shift-arrow cases and that Ctrl-B `98;5` is not shadowed by Alt-b), word motion over
  `"foo bar baz"` (including the column-0 no-op and multi-space runs, punctuation-as-word-char), Ctrl-W
  mid-buffer and **across a newline** (asserting `led_lines()` drops 2→1 — the reflow path), Ctrl-K
  kill-to-eol / buffer-end no-op / **end-of-line join** (2→1), and every word op as a bounds-safe no-op on
  an empty buffer.

### Process
- **Two-pass adversarial review** (Workflow). A **design pass** (3 lenses — editor/bounds, decode, integration)
  folded two should-fixes before code: the leftward word scan must place `i > 0` first so `&&` short-circuits
  before the backward `load8` (else an OOB read on word-left from column 0), and the test plan must cover the
  two height-changing (reflow) cases (delete/kill removing a newline). It also prompted broadening the arrow
  modifier gate to `p2 >= 3` (any Ctrl/Alt combo) rather than exact `5`/`3`. A **diff pass** (3 lenses, each
  finding independently adversarially verified) returned **zero findings**. **Live behavior verifies on a real
  tty (`--tier=rich`), not the harness** — the unit tests + review cover the pure logic + decode.

## [0.17.0] - 2026-07-07

**Bracketed paste — a multi-line paste lands in the composer instead of submitting at the first newline.**
Opens the 0.17.x input-completeness line. In the T2 TUI the raw-mode composer mapped both LF and CR to
`KEY_ENTER`, so pasting a stack trace or a code block fired a turn on line 1 and stranded the rest. thoth
now enables the terminal's bracketed-paste mode (`CSI ?2004h`) on TUI enter (disabled on every exit,
paired with the kitty push/pop), decodes the `ESC[200~` … `ESC[201~` brackets, and inserts the whole
paste into the composer as literal text. TUI-only — the line REPL / piped / one-shot / CI floor is
**byte-identical** (verified: `--help`/piped paths emit zero `?2004`/ESC bytes; every paste symbol lives
only in `src/tui.cyr`). 825 assertions (+19). Pin **6.4.16**.

### Added
- **`KEY_PASTE` + `_tui_csi_final` decode** (`src/tui.cyr`): the existing unified CSI parser already
  reduced `ESC[200~` to `_tui_csi_final(126, 200, -1)` (previously ignored); it now returns the new
  `KEY_PASTE`. The end marker `ESC[201~` and the legacy `5~`/`6~` page keys are untouched.
- **`_tui_paste_slurp` — the paste-body reader** (`src/tui.cyr`, I/O, live-tty verified): once `KEY_PASTE`
  is decoded (the fd sits at the first content byte), reads stdin a byte at a time into a lazily-alloc'd
  `_paste_buf` until the `ESC[201~` end marker (or EOF). A byte-wise marker matcher flushes a broken
  partial match back as literal content and re-anchors on `ESC` (the marker's only self-restart), and the
  end marker is consumed but not buffered. Bounded through a single capped writer (`_paste_commit`,
  `PASTE_CAP` = 4096 == `COMPOSER_CAP`): over-cap content is dropped but the stream is still consumed to
  the marker, so a large paste never desyncs the input.
- **`led_paste(src, len)` — the paste filter + insert** (`src/tui.cyr`, PURE, unit-tested): inserts the
  slurped buffer at the cursor by reusing the tested `led_feed` path one byte at a time. Filter: LF/CR
  (and CRLF) collapse to a single `\n`; a tab becomes one space; printable ASCII plus high/UTF-8 bytes
  (≥ 128) are kept; **ESC, every other C0 control, and DEL (127) are dropped** — so a paste can never
  inject a terminal escape sequence into the composer render and no control byte ever enters the buffer
  (the composer stays byte == column). It never submits (only `KEY_NEWLINE`/`KEY_CHAR`, both `ACT_NONE`);
  a pasted leading `/` does not dispatch (`tui_palette_active` is a derivation of the buffer, not a flag,
  and any pasted space/newline makes it inactive).
- **`tui_bpaste_enable`/`tui_bpaste_disable`** (`src/tui.cyr`): `CSI ?2004h`/`CSI ?2004l`, wired into the
  `tui_loop` enter/teardown next to the kitty enable/disable, balanced on every exit path (the two early
  `return repl_loop()` paths run before alt-screen enter, so paste mode is never set on them). A terminal
  that ignores the mode never sends the brackets, so paste degrades to the legacy Enter-per-newline
  behavior. The `KEY_PASTE` loop arm inserts the buffer and reflows the composer (a > 8-line paste clamps
  to `COMPOSER_MAX_ROWS` and scrolls internally); it is a composer-focus action (a paste while the tree is
  focused is a no-op — the body was already consumed, so no desync).
- **19 assertions** (`tests/thoth.tcyr`, `test_tui`): the `ESC[200~`→`KEY_PASTE` / `ESC[201~`→`KEY_NONE`
  decode (legacy `5~` unshadowed) and the pure `led_paste` filter — LF/CRLF/lone-CR/trailing-CR newline
  collapse, ESC+BEL dropped while `[31m` survives as literal text (no escape injection), DEL dropped,
  tab→space, insert-at-cursor, and an over-`COMPOSER_CAP` paste bounded at `COMPOSER_CAP-1` (no OOB).

### Process
- **Two-pass adversarial review** (the standing discipline). A **design pass** (4 perspective-diverse
  lenses — bounds, protocol, floor/security, Cyrius-integration — before any code) returned no blockers
  and folded two should-fixes: the partial-marker flush must route through the capped writer (else a
  near-miss at the cap boundary could write up to 4 bytes past the buffer), and tab is converted to a
  space rather than kept literal (keeps the composer strictly printable + byte == column, making the
  "no control byte enters the composer" invariant literally true). A **diff pass** (4 lenses, each finding
  independently adversarially verified) returned **zero findings**. **The live TUI paste behavior verifies
  on a real tty (`--tier=rich`), not the harness** — the unit tests + review cover the pure logic + decode.

## [0.16.1] - 2026-07-07

**Toolchain refresh to Cyrius 6.4.16 (bayan TOML array getter + aarch64 trig polyfills).**
Maintenance: pin `6.4.11 → 6.4.16` (`cyrius.cyml` + `cyrius lib sync` — 70 floor modules; two changed
content, the rest byte-identical). No thoth source-logic change; **806 assertions pass unchanged**; all
lanes behave (linux ships, AGNOS builds git natively, aarch64 size-gapped at 17.06/16 MiB, windows IOCP
gap). Clears the pin-drift warning (the wrapper cycc had already advanced to 6.4.16). Pin **6.4.16**.

### Changed
- **Pin `6.4.11 → 6.4.16`.** `cyrius lib sync` re-vendored the 70-module declared floor subset; only two
  modules changed content, both **additive** — no existing thoth path is affected:
  - **`lib/bayan.cyr` 1.0.4 → 1.1.0** — bayan gains a **TOML array-VALUE getter**: `key = [a, b, c]` is
    captured verbatim and decomposed on demand via `bayan_toml_array_parse` / `bayan_toml_get_array`
    (the scalar-array counterpart to `[[section]]` arrays-of-tables), plus a multi-line-array parse fix
    (literal `'` quotes and `#` comments inside a bracketed value no longer truncate it). This **lifts
    the constraint the 0.16.0 `shell` tool worked around** — the `[shell.deny]`/`[shell.allow]` glob
    lists are modelled as `label = "glob"` sections *because* "bayan had no TOML-array getter." That
    workaround is now removable; it is left as a scheduled cleanup (a config-surface change earns its own
    slice + review), not folded into this source-change-free refresh.
  - **`lib/math.cyr`** — new **aarch64 `f64_sin` / `f64_cos` polyfills** (Taylor range-reduction; x86
    keeps native `fsin`/`fcos`). Purely additive; thoth invokes no trig, and x86/AGNOS codegen is
    unchanged. Does **not** shrink the aarch64 binary, so that lane stays size-gapped (unrelated cap).

## [0.16.0] - 2026-07-06

**The model-invokable `shell` tool, with protections — plus a toolchain refresh to Cyrius 6.4.11.**
The backing model can now propose a shell command during an agentic turn; thoth runs it locally under
a wall-clock timeout, captures the combined stdout+stderr, and feeds a bounded result back into the
loop. It mirrors the `memory_write` local-tool shape (advertised only when opt-in `[shell].enabled` and
the target can capture, dispatched in the serial executor, never forwarded to daimon) and is gated at a
single t-ron choke point under the **distinct reserved name `thoth_shell`** — separate from `thoth_run`
(the human `/run`), so a policy can permit the operator's own shell while independently denying the
model's. Opt-in and off by default. [ADR-0014](docs/adr/0014-model-shell-tool-local-posix-gated.md).
806 assertions (+40). Pin **6.4.11**.

### Added
- **`src/shell.cyr` — the `shell` agentic tool.** `shell_run_tool({"command":…})` parses the command,
  runs a **local `[shell.deny]`/`[shell.allow]` glob filter BEFORE t-ron** (so a deny-list holds even
  with no `[tron].policy`: deny wins; a non-empty allow-list is default-deny), then the `thoth_shell`
  t-ron gate (the raw command passed as the JSON-escaped scanned payload), then a bounded, timed
  capture; it NUL-terminates + scrubs interior NULs→spaces, formats a result with an exit/timeout/
  truncation footer, and audits every proposed + executed command (`log_begin("shell")`, exit + byte
  count, never the output). Advertised via `agent_tools_add_shell` after `agent_tools_add_memory`.
- **`src/exec.cyr` — `exec_shell_capture` (timed, output-capturing shell exec).** Copies
  `lib/regression.cyr`'s proven pattern (child stdout+stderr → a `/tmp/thoth_sh_<pid>_<ctr>` temp file
  with `O_CREAT|O_EXCL|O_WRONLY`, a `WNOHANG`-poll-with-deadline, `SIGKILL` + blocking reap, then
  `file_read_all` + unlink) — combining capture and timeout so a runaway command is killed with its
  partial output preserved and no pipe-fill deadlock. `shell_supported()` reports POSIX capability.
- **`[shell]` config** (`src/config.cyr`): `enabled` (default off), `timeout_ms` (default 30 s, clamped
  10 min), `max_output` (default 64 KiB, clamped 1 MiB), and `[shell.deny]`/`[shell.allow]` glob
  tables loaded as sections of `label = "glob"` pairs (bayan has no TOML-array getter). A `/state`
  `shell` row (omitted when off) showing timeout / cap / deny+allow counts, and honest "gated on
  daimon" / "unsupported on this target" lines.

### Security
- **`thoth_shell` is a distinct t-ron reserved name** from `thoth_run` — the human-vs-model trust split
  is real: a policy can allow `/run` and deny/flag/rate-limit the model's shell (or vice-versa). One-shot
  is fail-closed (the confirm denies). The deny/allow globs are a **coarse pre-filter, explicitly NOT a
  sandbox** (a shell can `cd`/chain/decode around a string glob) — stated honestly everywhere; real
  containment is default-off + the operator's trust decision + the t-ron policy + OS confinement.

### Portability / floor
- **POSIX only, degrade closed.** The raw-syscall capture is compiled out on AGNOS (no `/bin/sh -c`, no
  `WNOHANG`) and Windows (`#ifndef CYRIUS_TARGET_AGNOS`/`_WIN`, mirroring `lib/process.cyr`); the tool
  is **not advertised** there and `/state` announces it — never faked. The AGNOS build stays clean.
- **Byte-identical floor when disabled** (the default): `agent_tools_add_shell` returns the tools length
  unchanged (zero writes), no `/state` row, no request-body delta. A hallucinated/un-advertised `"shell"`
  call is neither executed **nor** forwarded to daimon (matched unconditionally in `_agent_round_has_local`
  → serial dispatch re-checks enabled+supported → honest not-enabled string).

### Toolchain
- **Refresh Cyrius `6.3.41 → 6.4.11`** (`cyrius.cyml` pin + `cyrius lib sync` — 14 floor modules changed);
  clears the toolchain-drift + shadow-lib warnings. No source change from the refresh; the existing 766
  assertions pass unchanged on 6.4.11 before the feature. `aarch64` stays best-effort size-gapped (the
  pre-existing 16 MiB output cap, unchanged); Windows stays on its pre-existing `SYS_EPOLL_CREATE1` gap.

### Tests
- `test_shell` (+40): config scalars + clamps, the `[shell.deny]`/`[shell.allow]` loader, the glob
  verdict (deny-wins / allow-list default-deny / empty-allow allow-through), `shell_run_tool`'s pre-gate
  returns (parse/blank/deny), and the real `exec_shell_capture` (capture, exit code, merged stderr,
  timeout + partial output, over-cap truncation) plus the advertise-off floor.

## [0.15.1] - 2026-07-03

**Markdown fenced code blocks in the reply are now syntax-highlighted.**
The model's reply is markdown; where `/read` (0.8.4) and diff bodies (0.8.5) already colour
source, a ` ```bash ` / ` ```python ` / `~~~c` block in an answer now renders syntax-highlighted
in the TUI feed — reusing the SAME coverage-guarded highlighter (`_hl_span`) with zero changes.
New `src/mdhl.cyr`; [ADR-0013](docs/adr/0013-reply-code-highlighting-block-buffered.md). 766
assertions; pin **6.3.41**.

### Added
- **`src/mdhl.cyr` — a fenced-code highlighter for the reply feed.** A line-assembling fence
  state machine in front of all four reply-emit paths (hoosh/agent × blocking/streaming). It
  buffers each fenced block until its closing fence, then highlights the **whole block in one
  `_hl_span` pass** (so multi-line strings / block comments colour correctly), emitting fence
  delimiters and prose verbatim. Handles ` ``` ` and `~~~` fences, indented (≤3) fences,
  longer-run / CRLF / unterminated fences, and mixed fence types. Fence info-strings map to
  vyakarana grammar names via a small alias-first table (`bash`/`sh`→`shell`, `py`→`python`,
  `js`→`javascript`, `rs`→`rust`, `c++`→`cpp`, …); every canonical name falls through, and
  `_hl_span` self-heals an unknown grammar to verbatim. `text`/`plain`/`diff`/… deliberately
  stay uncoloured. Wired via a new `_hoosh_print_reply` (blocking) + `mdhl_feed`/`_reset`/
  `_finish` (streaming); error bodies keep `_hoosh_print_str` (never highlighted).

### Streaming behaviour
- A fenced block is **withheld until its closing fence** arrives, then appears highlighted at
  once (correctness: the whole block reaches one tokenizer; the spinner covers the gap; prose
  is unaffected). Because a fence is a whole-line construct, TUI text renders **line-by-line**
  rather than character-by-character — this removes per-character flicker (complementing the
  0.15.0 throttle) but is a behaviour change. The fully-live "upgrade the block to a
  highlighted card in place" is deferred to its own cut (it must re-render sealed feed rows).

### Floor
- **Byte-identical.** At `PT_PLAIN` (piped / one-shot / CI / `NO_COLOR`) `mdhl_feed`/`mdhl_reply`
  are a strict `emit_n` pass-through and `mdhl_finish` is a no-op — same bytes, same order, once.
  The raw reply accumulator (`_hoosh_acc`) is untouched, so history / `--json` / `-o` read the
  RAW reply. Proven by a property test: `strip_sgr(output) == input` (never drops/reorders a byte).

### Tests
- `test_mdhl_tag_map` / `test_mdhl_fence` / `test_mdhl_render` / `test_mdhl_stream` (+52): the
  tag→grammar map, the fence open/close/info scanners, the end-to-end render (PT_PLAIN floor =
  0 escapes; PT_ANSI = code coloured + delimiters verbatim + SGR-strip coverage), and streaming
  (byte-at-a-time chunk-split invariance; unterminated-fence flush with no phantom closer). The
  colour on screen is live-verified on a real tty (`--tier=rich`).

## [0.15.0] - 2026-07-03

**Smoother streaming — coalesce per-chunk feed repaints onto a frame budget.**
Opens the 0.15.x streaming-polish line (0.15.1 will add markdown fenced-code highlighting on top).
At 80–150 tok/s the TUI feed was repainting on **every** SSE delta — 100+ full repaints/sec — which
thrashes the pending line + spinner and can outrun the terminal (visible tearing / "splash"). This
decouples paint rate from token rate: `feed_stream_tick` now coalesces repaints onto a
`STREAM_FRAME_MS` (33 ms, ~30fps) budget. It is **throttling, not a typewriter delay** — content is
never held back (the chunk's bytes are already in the ring from the emit that ran before the tick;
the model is not slowed), only the intermediate PAINT rate is capped. 714 assertions; pin **6.3.41**.

### Changed
- **`feed_stream_tick` (`src/tui.cyr`) coalesces streamed repaints.** New pure
  `_stream_should_paint(now, last)` decides whether a chunk arriving at `now` (ms) should repaint,
  given the last paint at `last`: repaint at most once per `STREAM_FRAME_MS`; an intra-budget tick is
  dropped (the bytes are already captured). `clock_now_ms` is monotonic, but a backward step
  (`now < last`) **fails open** (paints) rather than stalling. The spinner now advances only on
  painted frames, so at high throughput it animates at a human ~30fps instead of a blur; at
  < 30 tok/s every tick still paints (unchanged cadence). `spin_begin` resets the paint clock so the
  **first** streamed chunk of every turn paints instantly (no first-token latency).
- No content can be stranded: the guaranteed post-dispatch `feed_flush_pending` + `feed_repaint`
  (`src/tui.cyr` run-line, ~1045) always lands the final state after the stream ends, on every exit
  path (success / error / early return).

### Floor
- **Byte-identical.** `feed_stream_tick` still early-returns off `OUT_RING`, so the line REPL / piped
  / one-shot / CI floor never enters the throttle — the change is TUI-only by construction. The
  reply accumulator (`_hoosh_acc`), history, `--json`, and `-o` are untouched (paint timing only).

### Tests
- `test_stream_throttle` (+7): the frame boundary (dt 0/32 coalesce, 33/large paint), the fail-open
  backward-clock step, and the first-tick (last=0) instant paint. The paint itself is I/O
  (live-verified on a real tty via `--tier=rich`, not the harness).

## [0.14.1] - 2026-07-03

**Agentic vertical now completes end-to-end — hoosh 2.4.12 resolves the tool-continuation 502.**
Consumes the upstream hoosh fix for 0.14.0's finding **(1)**. No thoth source-logic change; the
change is in the consumed spine (hoosh), re-verified live. 707 assertions pass.

### Resolved (upstream)
- **hoosh tool-continuation `502` → fixed in hoosh 2.4.12.** The 0.14.0 vertical proved every hop
  except the *completion* of an agentic loop: hoosh returned `502 "provider backend unreachable"` on
  the tool-continuation turn (an assistant `tool_calls` message + a `role:"tool"` result). Root cause
  was in hoosh — its Anthropic request-builder copied the OpenAI tool messages verbatim instead of
  translating them into `tool_use` / `tool_result` content blocks (a request-build error
  misclassified as a transport error). hoosh **2.4.12** translates them; the loop now completes.
  thoth needed no change — it already emitted OpenAI-shape tool messages correctly and consumes hoosh
  over HTTP.

### Verified (live vertical — hoosh 2.4.12 + daimon + bote 3.0.0 + thoth)
- **Full loop CLOSES**: a one-shot agentic turn (`thoth '…use fs_write…'`) runs
  thoth → hoosh (`claude-opus-4-8`) → tool call → t-ron `allow` → daimon → bote 3.0.0 `fs_write`
  (file written under `BOTE_FS_ROOT`) → result fed back → **hoosh returns the final summary turn** →
  thoth prints it and **exits 0**. Previously the continuation turn 502'd and one-shot exited 1 with
  empty stdout despite the tool having executed. Streaming also restores the closing summary that
  had come back empty.

### Notes
- **Requires hoosh ≥ 2.4.12** for agentic tool loops on Anthropic-backed models (earlier hoosh 502s
  on the tool-continuation turn). No change to non-agentic turns. thoth pin unchanged (6.3.41);
  vendored bote-core unchanged (3.0.0); 707 assertions unchanged.
- 0.14.0's findings **(2)** (bayan inline-comment config parse) and **(3)** (bote `bote_echo` sample
  tool returns a bare `{}`) are unchanged — both are upstream quirks, neither blocks the vertical.

## [0.14.0] - 2026-07-03

**Vendored bote 2.7.7 → 3.0.0 (MCP-protocol refresh) + a full vertical integration test.** Refreshes
the in-process MCP-protocol bundle to bote 3.0.0 (a major upstream bump — minor here) and exercises
the whole thoth → hoosh → daimon → bote stack live. No thoth source-logic change; 707 assertions pass.

### Changed
- **Vendored bote-core `2.7.7 → 3.0.0`** (`src/vendor/bote-core.cyr`; `scripts/sync-bote.sh`
  default tag → `3.0.0`). bote 3.0.0's breaking changes are all in its HTTP-server/full-bundle
  surface (session-less→404, `listChanged` notifications); the `[lib.core]` dispatcher bundle thoth
  vendors — used only to satisfy the vendored t-ron's dispatcher references — stays API-compatible
  (thoth builds clean, no undefined/arity errors, 707 tests).
- **`scripts/stack.sh`**: the generated `thoth.cyml` no longer puts an inline `#` comment on the
  `stream = false` value line (see the bug note below) — comments go on their own line.

### Integration test (live vertical — hoosh + daimon + bote 3.0.0 + thoth)
- **PROVEN end-to-end**: stack up (hoosh :8088 / daimon :8090 / bote 3.0.0 :9000); `thoth /tools`
  lists daimon's registry (fs_mkdir/write/read + bote_echo); `thoth /call` round-trips a tool
  (t-ron `allow` → daimon → bote 3.0.0 → executed); and an **agentic turn** runs the full loop —
  thoth → hoosh(Opus) → tool-call → t-ron → daimon → bote 3.0.0 `fs_write` **executed** (file
  written) + result parsed.
- **Findings** (none in thoth's git-producer / spine code): **(1)** the agentic loop can't COMPLETE
  — hoosh returns **HTTP 502 "provider backend unreachable"** on the tool-continuation turn (assistant
  `tool_calls` + `tool` result messages); simple + repeated calls succeed, so it's specific to the
  tool-continuation shape (a hoosh OpenAI→Anthropic tool-message translation bug, **filed on hoosh's
  roadmap** with a minimal repro). **(2)** a **bayan** inline-comment config bug — `key = val # note`
  is read with the comment attached, so thoth's `_cfg_*` mis-parse it (this is why `stream = false #…`
  read as streaming); worked around in stack.sh, root cause is bayan. **(3)** bote's sample
  `bote_echo` returns a bare `{…}` (not MCP content blocks) so `/call bote_echo` shows "no text
  content" — the real fs tools return proper content blocks; a bote sample-tool quirk.

### Notes
- 707 assertions unchanged. Pin unchanged (6.3.41). Requires bote-core ≥ 3.0.0 (`sync-bote.sh 3.0.0`).

## [0.13.2] - 2026-07-03

**Toolchain refresh to Cyrius 6.3.41 (globals cap raised) + a detached-HEAD test fix (CI green).**
Maintenance: pin `6.3.38 → 6.3.41` (`cyrius.cyml` + `cyrius lib sync` — 70 floor modules). No thoth
source-logic change; 707 assertions pass; all lanes behave (linux ships, AGNOS builds git natively,
aarch64 size-gapped, windows IOCP gap).

### Changed
- **Pin `6.3.38 → 6.3.41`.** Clears the drift warning. 6.3.41 **raised the `max 1024 initialized
  globals` per-compilation-unit cap** (the ceiling that forced sit's read profile + sankoch's zlib
  profile). Those lean profiles are **kept** — they're worthwhile on their own (smaller bundles, less
  dead code); the raised cap just means consumers are no longer *forced* into them, not that thoth
  should revert to the full bundles.

### Fixed
- **`test_git` is now detached-HEAD-robust** — CI checks out a bare SHA (detached HEAD), where a
  present repo has no named branch and `git_branch()` returns the `"?"` sentinel; the 0.13.0 test
  wrongly assumed a present repo always has a named branch and failed CI. It now asserts a real branch
  only when attached, and the sentinel when detached (the UI already rendered `(detached)` via
  `git_detached()` — production was never wrong, only the test). 707 assertions unchanged.

## [0.13.1] - 2026-07-03

**Refold the git producer onto patched sit + sankoch — drop two of the three vendor
workarounds.** 0.13.0 shipped the git producer with three thoth-side patches on its vendored
deps; two are now root-caused upstream and gone. No behavior change — same `/git`, `/state`,
status-bar git; a cleaner, current-tracking dependency surface.

### Changed
- **sankoch: full 2.2.5 pin → the 2.4.9 `zlib` profile** (`dist/sankoch-zlib.cyr`, sankoch's new
  `[lib.zlib]` distlib profile). thoth now tracks the **current** sankoch instead of pinning an old
  release: the zlib profile is DEFLATE/zlib-only (**53 initialised globals** vs the full bundle's
  175), so it stays well under cyrius's fixed `max 1024 initialised globals` cap — the reason 0.13.0
  had to pin the lean-but-old 2.2.5.
- **sit: 1.3.0 → 1.3.1 read profile** — sit made `sit_repo_open` **chdir-free** (reads at the process
  cwd; behavior-preserving — every consumer passes `"."`). So thoth's `sit_repo_open` `SYS_CHDIR`
  neutralisation sed is **dropped**, and the read profile is AGNOS-native with no thoth-side patch.

### Removed (vendor workarounds, now upstream-fixed)
- The `scripts/sync-sit.sh` **`_stream_grow` rename** — the zlib profile drops `stream.cyr`, so the
  function that collided with vyakarana's is no longer in the bundle.
- The **`SYS_CHDIR` neutralisation** — sit 1.3.1's chdir-free open removed the reference at the source.
- Only the **`entry_hash`/`ann_new` renames** remain (sit's fns vs thoth's libro/bote — an inherent
  thoth-integration collision sit can't know about, so it stays a thoth-side sed).

### Notes
- **AGNOS now builds git NATIVELY** (`build/thoth_agnos`, no sed) — v1.0 gate 1 intact, git works there.
  aarch64 stays best-effort size-gapped (the 16 MiB cap is hit by the binary's static data, not
  sankoch's version; unchanged by the refold). windows on its IOCP gap; linux ships. 707 assertions
  (unchanged — no source logic change). Pin unchanged (6.3.38). Requires **sit ≥ 1.3.1** + **sankoch
  ≥ 2.4.9**; re-vendor with `SIT_LOCAL=… SANKOCH_LOCAL=… ./scripts/sync-sit.sh 1.3.1 2.4.9`.

## [0.13.0] - 2026-07-03

**The git producer — branch / status / diff, by consuming sit.** thoth reports the
working repository's branch and working-tree status in `/state`, the TUI status bar, and
a new `/git` command — reading real `git` **and** `.sit` repos through **sit's** read-only
VCS API, no shell-out to system `git`. thoth owns **no** VCS logic: sit owns the domain
(git's on-disk format, the delta interpreter, all of it); thoth only asks and renders.
Omit-until-present ([ADR-0010](docs/adr/0010-data-producer-honest-omit.md)): the status-bar
segment appears only at a repo; `/state` shows a git row always (present → branch + count,
absent → the honest line). Unblocked by **sit 1.3.0**'s lean read-only dist profile.

### Added
- **`SEAM_GIT`** on the capability ladder (`src/seams.cyr`, seam #6; `SEAM_COUNT` → 7) —
  owner **sit**, binding **native** by construction (vendored dist bundle, like bote/avatara),
  capability-effect **FULL** at a repo / **ABSENT** with no repo at cwd. Shown in `/seams`.
- **`src/git.cyr`** — the producer. `git_probe()` reads branch + changed-file count through
  `sit_repo_open(".")` / `sit_repo_branch` / `sit_repo_status`, copies the branch out of sit's
  arena into a static buffer, and caches (probed at startup, after each dispatched turn, and on
  `/state` / `/git` — never per status-bar paint). Content-blind: thoth only sums/renders.
- **`/state` git row** (`branch — N changed`, or the honest absent line) + a **TUI status-bar
  segment** (`⎇ branch +N`, omitted with no repo) + a new **`/git`** command listing the branch
  and each changed file (`M`/`A`/`D` path) via `sit_status_path` / `sit_status_kind`.
- **`scripts/sync-sit.sh`** — vendors sit's read profile (`dist/sit-read.cyr`) + **sankoch 2.2.5**
  (git-object inflate), applying the collision + portability patches (below) on sync.

### Notes
- **Vendoring** (`src/vendor/sit-read.cyr` + `src/vendor/sankoch.cyr`, both source-included, NOT
  `[deps]` blocks): sankoch pinned to **2.2.5** (50 globals) not sit's 2.4.8 (175) — 2.4.8 blows
  cyrius's fixed max-1024-initialised-globals cap; 2.2.5 has both `zlib_*` functions, unchanged
  base inflate, and the absolute 16 MiB output cap. Three same-name/different-semantics clashes
  with thoth's spine bundles are `\b`-renamed on sync (`_stream_grow`→`_sk_stream_grow` vs
  vyakarana; `entry_hash`→`_sit_entry_hash` vs **libro**'s audit-chain getter — an unrenamed
  identity fn crashed `test_tron`; `ann_new`→`_sit_ann_new` vs bote-core). `sit_repo_open`'s
  `syscall(SYS_CHDIR, cwd)` is neutralised (thoth always passes `"."`) — AGNOS has no chdir, so
  this **keeps the AGNOS build (v1.0 gate 1) AND makes git work there** (sit reads at the real
  cwd). Three `sign` symbols stay unresolved as dead-path placeholders (the read API never signs).
- **Cross-target:** linux ships. **AGNOS builds with working git** (the chdir-free open made it
  portable — gate 1 intact). **aarch64** now exceeds its fixed 16 MiB output cap with the sit
  bundle → announced best-effort **size-gap** in `scripts/build.sh` (unblocks on a decompress-only
  sankoch / sigil static-data trim, or a cyrius cap raise). windows stays on its architectural
  IOCP gap.
- **Floor byte-identical**: git probes only in the interactive path (one-shot skips it → clean
  stdout); the `/state` row + status bar render through empty T0 ui-roles (verified: 0 escape
  bytes piped). **Pre-cut adversarial review** (4 lenses — memory/correctness/floor/vendoring,
  each finding independently verified): **zero confirmed findings**. 707 assertions (+11,
  `test_git` + the seam-count bump). Pin unchanged (6.3.38). **Deferred to a follow-up:**
  per-file `sit_diff_path` diff rendering in `/git`; sit shipping a chdir-free open + a
  decompress-only sankoch would let thoth drop the two vendor patches and track current sankoch.

## [0.12.3] - 2026-07-03

**Toolchain refresh to Cyrius 6.3.38 — and the AGNOS build lane lights up (v1.0
gate 1).** Maintenance: the source pin moves `6.3.15 → 6.3.38` (`cyrius.cyml` +
`cyrius lib sync` — 70 floor modules, 15 changed). **No thoth source change**; 696
assertions pass unchanged; x86_64 Linux builds + ships as before. What makes this
more than a routine drift-clear: refreshing the floor cleared **both** documented
transient gaps and lit up the **AGNOS** lane.

### Changed
- **Pin `6.3.15 → 6.3.38`** (`cyrius.cyml`, `lib/` re-synced). Clears the
  toolchain-drift + shadow-lib warnings. The benign `_sandhi_conn_open_v6_fully_timed_a`
  arity warning (documented since 0.10.1) also cleared — the 6.3.38 sandhi bundle
  fixes the h2-promotion arg count.

### Fixed (upstream, picked up by the refresh)
- **AGNOS lane now BUILDS** (`build/thoth_agnos`, a valid statically-linked
  x86_64-AGNOS ELF, zero undefined symbols). The lane's last blocker — the agnos
  peer omitting the `SIGHUP` signal-NUMBER constant (filed
  `agnos 2026-06-23-cyrius-agnos-peer-missing-signal-number-constants`) — is
  resolved: the 6.3.38 peer defines the signal enum. **This clears the BUILD half
  of v1.0 gate 1** (roadmap.md). The RUNTIME half (a downstream consumer green on
  real AGNOS) is **gate 2** — external, unchanged: the ELF targets the AGNOS
  syscall ABI and cannot be exercised on a Linux host.
- **Windows `SYS_GETRANDOM` transient gap cleared** (patra ≥1.12.4 now bundled).
  The `--win` lane now stops on the genuine ARCHITECTURAL `SYS_EPOLL_CREATE1`
  (IOCP) gap — where it *should* stop — instead of a fixable patra bug.

### Maintenance
- `scripts/build.sh`: emptied `TRANSIENT_GAP` (both `SYS_GETRANDOM` and `SIGHUP`
  cleared — kept as RESOLVED history in-comment) and guarded the empty case so a
  trailing `|` can never make the known-gap regex match every failure. Refreshed
  the `win`/`agnos` target docstrings. Re-verified `build.sh all`: linux ships,
  win skips on the architectural epoll gap, **aarch64 + agnos both build**.

### Notes
- 696 assertions (unchanged — no source change). Pin **6.3.38**.
- The AGNOS *build* clearing is verified here (file type, size, clean `OK`, zero
  undefined symbols); the AGNOS *runtime* (gate 2) still requires an AGNOS host and
  is not claimed. See [roadmap.md](docs/development/roadmap.md) gates 1–2.

## [0.12.2] - 2026-07-02

**`memory_write` tool (the agentic write path) + `AGENTS.md` pickup — closes the
0.12.x memory-seam line.** The model can now save durable facts to project memory
during an agentic turn, and the read set gains an optional project-root
`AGENTS.md`. No new spine, no new security surface.

### Added
- **`memory_write` MCP tool** — advertised to the model **alongside daimon's
  tools** (`agent_tools_add_memory`, `src/agent.cyr`) whenever the memory seam is
  active (`[memory].enabled`). When the model calls it, thoth **intercepts it in
  the executor** and handles it **locally** — gated under the reserved name
  `thoth_remember` (the SAME t-ron choke point as `/remember`), **never forwarded
  to daimon** (`_agent_run_calls_serial`). A round containing `memory_write` is
  forced through the serial executor so the parallel daimon workers never see it
  (`_agent_round_has_local`). Backed by the shared `memory_append`
  (`src/memory.cyr`); `memory_write_tool` parses `{"text":…}` and returns a plain
  result string. **Verbatim only** — no summarize/tag/dedupe/link (mneme's engine).
- **Project-root `AGENTS.md`** — read (if present) into the memory system message
  alongside `.thoth/memory` (model-facing project notes; `CLAUDE.md` stays the
  harness's contract and is not auto-injected). `memory_system_prompt` no longer
  early-returns on a missing `.thoth/memory` dir, so `AGENTS.md` alone is enough.
- `/remember` refactored onto the shared `memory_append` (one writer for the
  command and the tool). `thoth.cyml.example` `[memory]` note updated.

### Notes
- **Live-verified**: an agentic turn where Opus called `memory_write` →
  `[t-ron] allow: remember to .thoth/memory/MEMORY.md` → the fact landed in
  `MEMORY.md` (not routed through daimon).
- Advertised only with daimon wired (the agentic loop's precondition) — the same
  path the mneme MCP tools will ride when mneme's port lands. Manual `/remember`
  covers the no-daimon case.
- 696 assertions (+7: advertise splice + tool arg-validation). Pin unchanged
  (6.3.15). **0.12.x memory-seam line complete**; next active line is the
  externally-gated 0.13.0 git producer.

## [0.12.1] - 2026-07-02

**`/remember` — the memory-seam write half.** `/remember <fact>` appends a
verbatim bullet to `.thoth/memory/MEMORY.md`, **t-ron-gated** under the reserved
name `thoth_remember` (the same choke point as `/write` — a policy can allow it;
absent-t-ron falls to the fail-closed confirm). No new security surface, no new
spine.

### Added
- **`/remember <fact>`** (`CMD_REMEMBER`, `src/commands.cyr`) — appends `- <fact>`
  to `.thoth/memory/MEMORY.md` via the portable `file_append_locked` (creates the
  file; the AGNOS append gap is handled in `lib/io.cyr`), then calls
  `memory_invalidate()` so the fact is live on the **next turn** (verified:
  `/remember` then `/dry` shows it). Verbatim only — thoth does NOT summarize,
  tag, dedupe, or link (that is mneme's engine — ADR-0012).

### Notes
- **No portable `mkdir`**: `sys_mkdir`'s arg shape differs on AGNOS
  (`path, pathlen` vs `path, mode`), so thoth does NOT create `.thoth/memory/` —
  it degrades **closed** with guidance if the dir is missing (a candidate to file
  against the agnos peer, same class as the `sys_open` mode gap). A write failure
  also degrades closed + announced.
- Works whether or not `[memory].enabled` (the fact is saved either way; a note
  says it is not injected until the seam is enabled).
- 689 assertions (+1). Pin unchanged (6.3.15). Next: `memory_write` MCP tool +
  `AGENTS.md` pickup (0.12.2).

## [0.12.0] - 2026-07-02

**Memory seam + local `.thoth/memory` reader — the mneme fallback.** Opens the
0.12.x line ([ADR-0012](docs/adr/0012-memory-seam-omit-until-mneme.md)). Memory
is **mneme's** domain (the AGNOS knowledge base — semantic search / RAG; still
Rust, not yet Cyrius-ported), so thoth does **not** build a memory engine. It
models memory as a capability seam that binds native → mneme when present and
degrades to a dumb project-local flat-file reader when absent — the same
`git → sit` omit-until-owner shape. **Off by default → byte-identical floor.**
(The git producer moves to **0.13.0**; memory, drivable now, takes 0.12.x.)

### Added
- **`SEAM_MEMORY` on the capability ladder** (`src/seams.cyr`) — owner `mneme`,
  domain "persistent memory / project note library". `seam_cap_state` is
  special-cased like t-ron: `absent` (off) → `degraded` (local reader) →
  `full` (mneme). Rendered in `/seams`; the binding stays `absent` until
  mneme's port registers with daimon (then discover `mneme_*` in the registry
  and flip to `remote`/`full` — zero change to the injection point).
- **`src/memory.cyr` — the local reader.** `memory_system_prompt()` reads
  `.thoth/memory/MEMORY.md` (curated index, first) + `*.md` fact files
  (dir order, whole-or-skip) up to **4 KB**, verbatim, cached once (mirrors
  `persona_system_prompt`). `memory_context()` is the single injectable
  contract (`a cstr or 0`) the mneme branch will marshal into.
  **Content-blind by construction** — recency/budget only, NO search / rank /
  embed / link (that is mneme's engine; the litmus is in the module + ADR).
- **Injection** — a second `{role:system}` message **after** the avatara
  persona, **before** history, threaded as a `mem` parameter through
  `hoosh_build_request` / `hoosh_build_messages` / `hoosh_build_dry`
  (`src/hoosh.cyr`) and `agent_build_request` (`src/agent.cyr`); acquired
  gated on `seam_cap_state(SEAM_MEMORY) != CAP_ABSENT` at the three sites
  (`hoosh_send`, `agent_turn`, `/dry`). Shown faithfully in the `/dry` preview.
- **`[memory].enabled`** config (opt-in, default off — `src/config.cyr`): a
  checked-in `.thoth/memory` is a prompt-injection surface (same trust as
  `CLAUDE.md`), so auto-injection requires an explicit opt-in.
- **`/state` memory row** + a documented `[memory]` block in
  `thoth.cyml.example`.

### Notes
- **Byte-identical floor**: memory off (default) or `.thoth/memory` absent →
  `memory_context()` returns 0 → the builders omit the message (verified via
  `/dry`, 0 occurrences). All prior request bodies are byte-identical
  (existing builder tests pass unchanged with `mem = 0`).
- Notes carry frontmatter matching mneme's vault format, so the local store is
  later ingestible by mneme — the fallback is not throwaway.
- 688 assertions (+13: seam registry/ladder + `test_memory` injection & floor).
  Pin unchanged (6.3.15). `/remember` (0.12.1) + `memory_write` tool (0.12.2)
  are the next cuts.

## [0.11.12] - 2026-07-01

**AGNOS cross-build readiness.** thoth now compiles cleanly under
`cyrius build --agnos`. Host build byte-identical (every agnos change is
`#ifdef CYRIUS_TARGET_AGNOS`-gated); 675 assertions still pass.

### Changed
- **Vendored bundle re-synced**: `darshana` 0.8.1 → **0.8.2** (adds the agnos
  peers for `tty_isatty` / `tty_raw` / `tty_cooked`).

### Fixed
- **`--agnos` build** — guarded the Linux-only terminal paths that have no agnos
  equivalent, each degrading to an existing thoth fallback:
  - `src/ui.cyr` `ui_isatty`: agnos has no `ioctl(TCGETS)` (Linux syscall 16 is
    `kill` on agnos) — returns "tty" (the fb console is ANSI/SGR-capable).
  - `src/tui.cyr` signalfd(SIGWINCH)+epoll multiplex: no signalfd/epoll on agnos
    — `tui_events_init` returns 0 so the loop uses the bare-blocking-read
    fallback (instant resize disabled); `tui_wait_event` / `tui_drain_winch` /
    `tui_events_teardown` + the SIGINT-signalfd open guarded to match.
  - Full-screen TUI degrades to thoth's line REPL on agnos (darshana `tty_raw`
    → -1: no termios raw mode).

## [0.11.11] - 2026-06-30

**cyrius 6.3.15 base-stack migration.** thoth joins the coordinated migration onto
cyrius **6.3.15**, over the freshly-released base security stack. Toolchain pin +
vendored-bundle refresh + the 6.3.x stdlib reconciliation. All 675 assertions
(+ the smoke) pass on the new stack; no thoth-side logic changed.

### Changed
- **Cyrius toolchain pin: 6.2.43 → 6.3.15.**
- **Vendored bundles re-synced** to the migrated releases: `bote-core` 2.7.3 → **2.7.7**,
  `libro` 2.7.2 → **2.7.9**, `t-ron` 2.1.5 → **2.1.7** (via `scripts/sync-*.sh <tag>`).
  avatara / darshana / vyakarana unchanged (not in this migration; var-bomb-clean under 6.3.15).
- **`[deps] stdlib`**: added `sync` — patra (pulled through the vendored libro/t-ron audit
  chain) declares `lib/sync.cyr` as a hard stdlib dep on the 6.3.x line; `sync` builds on the
  already-present `atomic`.

## [0.11.10] - 2026-06-26

**`--tier` flag replaces the `THOTH_TIER` env-var.** The presentation tier is now a first-class
flag — `thoth --tier=simple|rich|auto` (also `--tier <mode>`) — with capability-aware
auto-detection. `THOTH_TIER` is **dropped entirely** (no `getenv` for it remains). 675 unit
assertions (+17). Pin unchanged (6.2.43).

### Added
- **`--tier=<mode>` / `--tier <mode>`** (`src/oneshot.cyr`) — a global modifier flag selecting the
  presentation tier: `auto` (default), `rich`, `simple`. Not a one-shot mode, does not force a run;
  the space form won't swallow a following flag (`--tier --version` still prints the version); an
  unknown value warns on stderr and falls back to auto. `--help` + the bash/zsh completion scripts
  gain it (completing `auto rich simple`).
- **Tier preference in `src/ui.cyr`** — `TIER_AUTO`/`TIER_SIMPLE`/`TIER_RICH`,
  `ui_set_tier_pref`/`ui_tier_pref`/`ui_tier_pref_from_name`, and a factored-out pure
  `_ui_color_capable()` (NO_COLOR/isatty/TERM). `main.cyr` applies the pref before `ui_detect_tier`.

### Changed
- **`auto` (the default) now launches the rich TUI on a capable terminal** (stdin+stdout are TTYs,
  TERM not dumb/empty, color provable) — a deliberate behavior change: bare `thoth` opens the TUI
  where it can (was the line REPL). Pipes / CI / dumb terminals / `NO_COLOR` still degrade to plain;
  one-shot (`git diff | thoth 'x'`) is unchanged. `simple` = line mode (ANSI when color is provable,
  else plain); `rich` = force the TUI when usable, degrading to the line tier otherwise.
- The live-verify command for the TUI is now `./build/thoth --tier=rich` (was `THOTH_TIER=rich`).

### Removed
- **`THOTH_TIER` environment variable** — superseded by `--tier`. `ui_detect_tier` no longer reads it.

## [0.11.9] - 2026-06-26

**TUI polish — faint rules, a multi-line composer, a live status line.** Three rough edges in
the T2 rich-TUI, all TUI-only (the line-mode REPL / piped / one-shot floor stays byte-identical
— a one-line composer renders exactly as before). (1) A faint full-width rule (`─`) divides the
status bar from the feed and the feed from the input prompt. (2) The composer is now multi-line:
**Shift+Enter** (via the kitty keyboard protocol, on terminals that support it) and **Alt+Enter**
(universal, legacy `ESC CR`) insert a newline; the composer grows upward, the feed shrinks, plain
Enter still submits the whole buffer, and Up/Down navigate between lines (falling through to
input-history recall at the top/bottom edge). (3) The hardcoded `READY` greeting now reflects a
live reachability **probe**: `Status: READY` only when the hoosh gateway actually answers, else
`Status: hoosh unreachable — <url> (is the gateway up?)` (a URL is set but nothing responds) or
`Status: hoosh absent — set [hoosh].url` (none configured) — honest, never faked; the "type a
task" guidance moved to its own line below. 658 unit assertions (+59). Pin unchanged (6.2.43).

### Added
- **Faint horizontal rules** (`tui_draw_rule`, `src/tui.cyr`) under the status bar (suppressed
  when the status bar is hidden via Ctrl-G) and above the composer.
- **Multi-line composer** — `KEY_NEWLINE` inserts `\n`; pure `led_*` line helpers (`led_lines`,
  `led_cursor_line`/`_col`, `led_line_start`/`_len`, `led_up`/`led_down`); a cursor-anchored
  vertical window (`_comp_vscroll_first`) with one logical line per physical row + per-line
  horizontal scroll. The composer height (clamped to `COMPOSER_MAX_ROWS`, always leaving
  `MIN_FEED` feed rows) tracks the line count; the feed band reflows on a height change via the
  `tui_after_edit` redraw gate (no flash — `tui_repaint_body`, no `tty_clear`).
- **Shift+Enter / Alt+Enter newline decode** — the kitty keyboard protocol is pushed
  (`CSI > 1 u`, disambiguate) on TUI entry and popped (`CSI < u`) on every exit; a unified CSI
  parser + `_tui_csi_final`/`_tui_kitty_u` decode `CSI 13;<mod>u` → newline and the Ctrl-combos
  (which kitty remaps to CSI-u) back to their keys, so exit/toggles + Shift-arrow feed-scroll
  keep working under the protocol. Terminals that don't support it ignore the push and use the
  universal Alt+Enter fallback.
- **Live status greeting** — `Status: READY` / `hoosh unreachable — <url>` / `hoosh absent`,
  driven by `hoosh_reachable()` (`src/hoosh.cyr`) — a silent GET to the gateway's models
  endpoint; any HTTP response means reachable (even 404/401), only a transport failure (refused/
  timeout/DNS) means down. Reflects what a turn would actually find (a refused localhost gateway
  fails instantly); the guidance line sits below it.

### Changed
- Layout geometry (`src/tui.cyr`) is now pure over explicit `(rows, lines, show)` params
  (mirroring `tui_tree_w`/`tui_feed_width`): `tui_feed_top` → 3 when the status bar shows;
  `tui_feed_bot`/`tui_composer_top`/`tui_composer_height`/`tui_sep_bottom_row` take the composer
  line count. `tui_relayout` now delegates to `tui_repaint_body`.

### Fixed
- **Multi-line input-history persistence** (`src/inhist.cyr`) — embedded newlines and literal
  backslashes are escaped on write (`\` → `\\`, newline → `\n`) and decoded on read, so a
  multi-line entry no longer shatters the line-oriented `[history].file` into bogus entries. The
  decoder is backward-compatible (a stray `\X` in a pre-0.11.9 file is preserved verbatim).

## [0.11.8] - 2026-06-26

**Shell completion (0.11.x terminal-citizen line).** `thoth --completion <shell>` prints a
bash or zsh completion script to stdout — completing thoth's argv flags and a filename after
`-o`/`--out` — for the non-interactive front door (the interactive REPL slash-palette already
completes commands live). The last clean rider on the 0.11.x line. A print-and-exit mode like
`--version`/`--help`. 599 unit assertions (+11). Pin unchanged (6.2.43).

### Added
- **`--completion` / `--completions [shell]`** (`src/oneshot.cyr`, `ONESHOT_COMPLETION`) — a
  print-and-exit mode that emits a completion script for `bash` (default) or `zsh` and exits.
  The shell is the next argv token (optional); an unsupported shell degrades closed (stderr +
  nonzero exit, nothing to stdout). Wired into `main.cyr`'s one-shot dispatch.
- **`_completion_bash` / `_completion_zsh`** — the emitted scripts (static text thoth prints;
  the shell runs them, thoth never executes them — no spine path, no security surface). bash
  completes the flags (`compgen -W`), filenames after `-o`/`--out`, and `bash zsh` after
  `--completion`; zsh uses `_arguments` (source-style, ending in `compdef _thoth thoth`; fpath
  users prepend a `#compdef` line, noted in the script). The flag lists mirror `_oneshot_parse`
  (the source of truth) — sync comments at each site.
- **`test_completion`** (+11): the `--completion`/`--completions` parse (the COMPLETION mode,
  the captured shell, the bash default, the position-independent short-circuit, reset across
  calls). The emitted SCRIPTS are validated by a host smoke (`thoth --completion bash | bash -n`,
  `zsh -n`, and a functional `COMPREPLY` check) — shell tooling the in-process unit harness lacks.
- A `--completion` usage row + a sourcing example in `--help`.

### Notes
- **Cyrius string-literal escaping** (the risk this feature carried): a design pass confirmed
  empirically that `$` is literal in Cyrius string literals (so no `\$` is needed); only an inner
  `"` (written `\"`) and a trailing line-continuation `\` (written `\\`) escape, and the bash
  flag list uses single quotes to minimize it. The emitted scripts were verified byte-correct via
  `bash -n` / `zsh -n` + a functional completion check.
- **Two-pass adversarial review (Workflow).** A DESIGN pass (4 lenses, before code) settled the
  escaping question and pinned the folds applied pre-implementation (a bash `--completion` case
  arm, the zsh `compdef` registration form, the `--completions` alias in both scripts, single-
  quoted bash flags, sync comments). A DIFF pass (4 lenses, each finding independently verified,
  and the host smoke re-run) returned **zero must-fixes**.

## [0.11.7] - 2026-06-25

**`-o` / `--out` file tee (0.11.x terminal-citizen line).** `thoth -o <file> <task>` tees the
turn's answer — the plain reply, or the `--json` envelope — to `<file>` (plain bytes) **as well
as** stdout. It is the user's OWN redirection (the path is an argv token, like shell `>`), so
it is **NOT t-ron-gated** — t-ron gates the MODEL writing files (`/write`); choosing where
thoth's own output goes is not a model action (the path is fixed from argv before the turn, so
the model can't influence it). The first item of the riders slot. 588 unit assertions (+19).
Pin unchanged (6.2.43).

### Added
- **`-o` / `--out <file>`** (`src/oneshot.cyr`) — a one-shot **modifier** flag that consumes the
  next argv token as the output path (verbatim). Like `--json` it does not force a run on its
  own (a positional task or `-p` is still the run intent); a dangling `-o` with no following
  token is ignored. Composes with `--json` (`thoth --json -o out.json <task>` tees the envelope).
- **`_oneshot_write_out`** (`src/oneshot.cyr`) — writes the answer plus a trailing newline (if
  absent) so the file matches stdout byte-for-byte; create + truncate at 0644 through the
  portable `lib/io.cyr` wrappers (the AGNOS `AO_*` open bridge — never a raw `sys_open`).
  Degrades closed: an open / short / newline-write failure returns an error; `one_shot_run`
  announces it on stderr and exits nonzero (the answer still reached stdout — a best-effort tee).
  A FAILED turn writes no file (the tee is inside the success path).
- **`test_oneshot_out`** (+19): the flag parse (path consumed, not a positional; the `--out`
  alias; a dangling `-o`; reset across calls; `-o` + `--json` composition) and the writer
  (bytes + a trailing newline read back; an already-newline reply not doubled; O_TRUNC re-write;
  the unwritable-path error). The writer is unit-tested against a scratch file under `build/`
  (file I/O works in the harness, unlike a live TCP turn).

### Notes
- **Perms:** the file is created at `0644` (umask-respecting; tighter than shell `>`'s
  `0666 & ~umask`); on AGNOS the create-mode is dropped by the frozen-ABI open bridge. The
  answer may contain secrets, so keep secret-bearing output in an owner-only directory — noted
  in `--help`. REPL/TUI-only by scope (one-shot is where clean output to a file matters).
- **Two-pass adversarial review (Workflow).** A DESIGN pass (4 lenses, before code) confirmed
  the flag-with-an-argument parse and the security calls (0644 like `>`, not t-ron-gated) and
  pinned one required fix folded in pre-implementation — check the trailing-newline write so a
  failed newline forces degrade-closed (keeping file/stdout tee-identical). A DIFF pass (4
  lenses, each finding independently verified) returned **zero must-fixes**. Verified live:
  `--help`, and that a failed turn writes no file; the success tee + trailing-newline + degrade
  are exact-tested (a live gateway round-trip is host-side — the sandbox blocks a compiled
  binary's TCP).

## [0.11.6] - 2026-06-25

**JSON-envelope output (0.11.x terminal-citizen line).** `thoth --json <task>` runs the
one-shot turn and prints a single JSON object to stdout instead of the plain reply —
`{response, model, turns, tokens?, cost?, elapsed_ms}` — for `jq` / CI. It rides the 0.11.0
one-shot clean-stdout seam (progress already discarded). Opt-in: default one-shot stays plain
text and the interactive TUI/REPL + the byte-identical floor are untouched. Completes the
introspection slot. 569 unit assertions (+13). Pin unchanged (6.2.43).

### Added
- **`--json` / `-j`** (`src/oneshot.cyr`) — a one-shot **modifier** flag (orthogonal to the
  mode): it does not force a run on its own (a positional task or `-p` is still the run intent)
  and is parsed as an `elif` on the `-p` chain (so it is never a positional and never breaks
  `-p`). `thoth --json` alone falls through to the TUI.
- **`oneshot_json_envelope`** (`src/oneshot.cyr`) — the pure serializer:
  `{"response":…,"model":…,"turns":N[,"tokens":N][,"cost":"$d.cc"],"elapsed_ms":N}`. The reply
  is escaped **by length** (an embedded NUL survives as `\u0000`, matching the plain path's
  by-length print); `tokens`/`cost` follow ADR-0010 **omit-until-present** (shown only once
  hoosh reports usage / a `[pricing]` rate prices it — never a faked `0`/`$0`); `turns` is
  always present; `elapsed_ms` is the wall-clock turn time (`clock_now_ms`, with a
  non-monotonic-step guard). The envelope buffer is sized so a worst-case 6×-escaped max reply
  never truncates → the object is always complete, valid JSON.
- **`_json_escape_n_into_cap`** (`src/hoosh.cyr`) — a length-bounded JSON escaper for the
  by-length reply; `_json_escape_into_cap` is refactored to delegate to it at `strlen(src)`
  (byte-identical for all existing callers — the request builders, `/dry`, …).
- **`test_json_envelope`** (+13): the `--json`/`-j` flag parse (sets the flag, no force, not a
  positional, reset across calls, `-p` still works), and the envelope across field combos
  (response+model+turns, +tokens, +tokens+cost, the embedded-NUL by-length escape, model-id
  escaping).

### Notes
- **Failure contract:** on any failure (no answer), **nothing** goes to stdout in either mode
  (no partial/invalid JSON), a concise diagnostic goes to stderr, and the exit is nonzero — a
  `jq`/CI consumer checks the exit code. Documented in `--help`.
- `cost` is the `$d.cc` string (consistent with `/state` + the status bar); `tokens` is an
  integer. **REPL/TUI-only by scope** — one-shot is where clean stdout matters; the
  interactive surfaces are for humans.
- **Two-pass adversarial review (Workflow).** A DESIGN pass (4 lenses, before code) confirmed
  the buffer-sizing/valid-JSON guarantee and the failure contract, and pinned the fixes folded
  in pre-implementation (parse `--json` as an `elif`, reset the flag before the early return,
  a self-documenting cap, the by-length escaper). A DIFF pass (4 lenses, each finding
  independently verified) returned **zero must-fixes**. Verified live: `--help`, and the
  failure path (empty stdout + stderr + exit 1) with no hoosh configured; the success envelope
  serialization is exact-tested (a live gateway round-trip is host-side — the sandbox blocks a
  compiled binary's TCP).

## [0.11.5] - 2026-06-25

**`/dry` — request-body preview (0.11.x terminal-citizen line).** `/dry <task>` renders the
exact hoosh request body thoth would compose for `<task>` and **skips the POST** — a local
introspection command for "what goes to the model?". It is **side-effect-free** (no session
history / token / cost mutation) and **network-free** (no hoosh POST, no daimon fetch). It is
NEVER a hoosh `/preview` endpoint — that would creep toward forking the inference spine;
`/dry` only renders thoth's *own* composed request buffer. The introspection slot's first
item. 551 unit assertions (+9). Pin unchanged (6.2.43).

### Added
- **`hoosh_build_dry`** (`src/hoosh.cyr`) — composes the multi-turn request body (system
  persona + the budgeted history tail + the pending user turn) **without mutating** session
  history, so the preview has no side effects (the live `hoosh_send` appends the turn to
  history first; this reads only). Reuses the same `_hoosh_emit_msg_cap` / `_hoosh_history_start`
  / cap-bounded builders, so the bytes match a real turn. Plus `hoosh_model_cur()` (the exact
  model precedence `hoosh_send` uses — session `/model` → `[hoosh].model` → `"default"`) and
  `hoosh_dry_buf()` (the shared request buffer).
- **`/dry` command** (`src/commands.cyr`, `CMD_DRY`) — mirrors `hoosh_send`'s path selection
  (multi-turn → `hoosh_build_dry`, else `hoosh_build_request`), prints the endpoint + active
  flags (model, stream, history, agent, byte count) and the request body, and degrades
  honestly: when `[hoosh].url` is unset it notes "the body thoth WOULD send" and still composes
  it locally (never refuses). In **agentic mode** it shows the message envelope and **annotates**
  (never fetches/fakes) that the live turn also sends a `tools` array (see `/tools`). Listed in
  `/help` and the TUI slash palette.
- **`test_dry`** (+9): the classifier, `hoosh_model_cur` precedence, exact body shapes
  (bare user turn, system + user, streaming flags, history tail + pending turn), the prompt
  JSON-escape, and the **no-mutation invariant** (`session_history_len` before == after).

### Notes
- **REPL/TUI-only** — one-shot (`thoth 'task'`) routes its whole argv to `cmd_task` as a
  free-text task by design, so it does not interpret `/dry`. Use it interactively (the line
  REPL also accepts it piped). In the TUI feed a body over the 2 KiB feed-slot cap truncates
  on screen (noted on output); the line REPL / piped shows it whole.
- Known faithfulness edge (documented in the builder): `_hoosh_history_start` budgets the
  history tail without the pending prompt's bytes, so at a ~32 KiB-of-history boundary the
  preview can include one more old message than the live turn. Faithful for any normal
  conversation; the prompt is bounded by the 4 KiB input line.
- **Two-pass adversarial review (Workflow).** A DESIGN pass (4 lenses, before code) confirmed
  the side-effect-free / network-free design and pinned the fixes folded in pre-implementation
  (reuse `_hoosh_model` to avoid model drift; annotate-not-fetch agent tools; honest hoosh-absent
  handling; the read-only build over a lossy temp-append). A DIFF pass (4 lenses, each finding
  independently verified) returned **zero must-fixes**. Verified live (piped REPL): the composed
  body for configured + absent seams, and `turns: 0` / `0 messages` after two `/dry` calls
  (side-effect-free).

## [0.11.4] - 2026-06-25

**`[alias]` prompt macros (0.11.x terminal-citizen line).** User-defined slash macros in
`thoth.cyml`: a `[alias]` table of `name = "expansion"` pairs. Typing `/<name> [args]` that
is NOT a built-in command expands to the configured text (with any trailing args appended)
and RE-DISPATCHES it — so an alias can map to a built-in (`/ship → /run git status`), a
free-text task (`/explain foo → explain this code: foo`), or even `/quit`. Reuses the bayan
TOML parser (no second config format). **Opt-in — with no `[alias]` table the behaviour is
byte-identical to before** (an unknown `/x` still prints "unknown command"). Resolves in the
interactive **REPL/TUI** dispatch path. 542 unit assertions (+20). Pin unchanged (6.2.43).

### Added
- **`[alias]` config table** (`src/config.cyr`): `_alias_load` caches each `[alias]` pair's
  `name`/`expansion` into a stable fixed table (cap 64), iterating the section's pairs vec
  directly (`bayan_toml_pair_key`/`_value`). Blank name/value skipped; a duplicate key keeps
  the **first** definition; a name ≥ 256 chars is skipped (it could never match a typed token,
  which the composer caps at 255 — so it is never a dead, count-inflating entry).
  `config_alias_lookup(name)` (first-match) and `config_alias_count()`.
- **Expand-then-redispatch** (`src/commands.cyr`): `_alias_name_of` extracts the bare slash
  token; `alias_expand(line, depth)` builds `value [+ " " + trailing args]` into a per-depth
  buffer (every copy cap-bounded, always nul-terminated). `dispatch(line)` is now a thin
  wrapper over `_dispatch_d(line, depth)`: at `CMD_UNKNOWN_SLASH` it tries an alias and
  re-dispatches the expansion one level deeper. Recursion is **bounded** (`ALIAS_MAX_DEPTH`
  = 8): the guard fires **before** the next expansion writes a buffer slot, so a cycle is
  refused ("alias: expansion too deep") — never an unbounded recursion or an out-of-bounds
  write. Per-depth disjoint buffer slots keep a parent's line intact while a child expands.
- **`aliases` row in `/state`** — `N defined`, shown **only when N > 0** (so default `/state`
  is unchanged). `thoth.cyml.example` gains a documented `[alias]` block.
- **`test_alias`** (+20): name extraction (bare `/`, spaces, truncation), the table load
  (blank-skip, duplicate first-wins, the ≥256-char-name skip), expansion (value verbatim +
  arg append), per-depth buffer disjointness, oversized-value truncation (nul-terminated),
  and the no-alias byte-identical-floor case.

### Security / posture
- An alias that expands to `/run`, `/write`, or `/call` is **re-dispatched through the same
  `_dispatch_d`**, so it still passes through the t-ron authorization gate unchanged — aliases
  assemble the line that dispatch then gates; they cannot bypass authorization or pre-approve
  an action.
- **Built-ins always win** — aliases resolve only in the `CMD_UNKNOWN_SLASH` gap, so an alias
  named like a real command (`read`, `run`, …) never fires (it is dead — documented).
- Aliases are an interactive **REPL/TUI** feature (those front-ends run `dispatch`); one-shot
  (`thoth 'task'`) routes its whole argv straight to `cmd_task` as a free-text task by design,
  so it does not interpret `/aliases` — the user assembles the full command there anyway.

### Notes
- **Two-pass pre-cut adversarial review (Workflow).** A DESIGN pass (4 lenses, before any
  code) caught two real blockers folded in pre-implementation — the depth guard had to fire
  *before* `alias_expand` (else a cycle wrote one slot past the per-depth buffer) and
  `_alias_bufs` needed lazy first-use allocation — plus the name-buffer pin and doc notes. A
  DIFF pass (4 lenses, each finding independently verified) surfaced exactly one must-fix (the
  ≥256-char-name dead entry), fixed + regression-tested before cut. Aliases verified live
  (piped REPL): `/st → /state`, a 2-alias cycle refused, and the no-config floor unchanged.

## [0.11.3] - 2026-06-25

**Soft-wrap long feed lines (0.11.x terminal-citizen line).** The T2 TUI feed stops
TRUNCATING a logical line wider than the feed column and instead REFLOWS it across
several physical rows — the top-ranked pure-substrate win from the SecureYeoman-TUI
review (no argv dependency, no spine touched). It is a painter + scrollback-math change
only; the line-REPL / piped / CI floor never paints the feed, so it is **byte-identical**
by construction (`feed_clip` and the file-tree pane painter are untouched). 522 unit
assertions (+42). Pin unchanged (6.2.43).

### Added
- **`feed_clip_seg`** (`src/feed.cyr`) — soft-wrap's load-bearing PURE primitive: paints
  the visible-column WINDOW `[skip_cols, skip_cols+max_cols)` of a stored line (segment N
  of a reflowed line is `feed_clip_seg(.., N*width, width)`). It carries SGR color across
  the wrap boundary via a bounded 64-byte carry of the active SGR-since-last-reset, so a
  color opened on one row continues onto the next; whole-or-drop carry flush (never a
  severed CSI), suppresses `ESC[...K`, never severs a UTF-8 glyph, closes an open span
  with `ui_reset()` (room permitting). `feed_clip` is left UNCHANGED (it still drives the
  fixed-width tree column, which truncates by design).
- **`feed_rows_for(vis, width)`** + **`_feed_total_phys(width)`** (`src/feed.cyr`) — the
  physical-row height of a logical line (`ceil(vis/width)`, a blank line is one row) and
  of the whole virtual document. The painter's scroll oracle under soft-wrap.
- **`test_softwrap`** (+42): `feed_rows_for` (ceil / blank / width<1 guard); `feed_clip_seg`
  (window/skip, SGR continuity incl. cumulative carry + reset-mid-skip, empty window,
  whole-or-drop carry, `ESC[...K`, `dst_cap`, UTF-8 across the skip boundary, plus a
  forced-PT_ANSI proof that the defensive close emits real reset bytes); and
  `_feed_total_phys` across sealed + blank + pending lines at several widths.

### Changed
- **`feed_repaint`** (`src/tui.cyr`) rewritten to the physical-row model: it maps each
  physical row to a `(logical line, segment)` pair and paints that segment's window, so a
  wide line spans several rows instead of being clipped. Top-pinned when the document is
  shorter than the band, as before.
- **Scrollback is now reckoned in PHYSICAL (soft-wrapped) rows** (`feed_scroll()`
  redefinition; `src/feed.cyr` accessor + `_tui_feed_scroll_by` / new `_tui_feed_maxscroll`
  in `src/tui.cyr`). A width change (resize / tree toggle) re-flows the document, so
  `tui_relayout` upper-clamps the stored scroll offset before repainting (cross-width
  scroll position is an approximate physical offset, not a logical anchor).

### Known limitations (honest, declared)
- **Glyph width = 1 column.** Visible width counts glyphs (the existing `feed_visible_cols`
  contract), so a double-width CJK / emoji glyph is counted as one column: a CJK-heavy line
  wraps a column late and `_feed_total_phys` undercounts its rows, drifting the scroll /
  segment mapping by up to a row for such captured output. ASCII / thoth's own output is
  exact. Cosmetic; never a correctness or floor issue.
- **Cumulative-SGR carry cap.** The carry tracks SGR-since-last-reset up to 64 bytes; an
  over-cap cumulative run (pathological captured tool output) drops the overflow WHOLE —
  a bounded cosmetic color glitch across that one wrap. thoth's own output is
  single-span-then-reset, so it never overflows.

### Notes
- **Pre-cut adversarial review, two passes.** A DESIGN-verification pass (4 perspective-diverse
  lenses, each refuting against the real source) ran BEFORE implementation; its one real
  finding — `feed_scroll()`'s unit had to be redefined to physical rows and clamped on a
  width change — was folded in before any code. A DIFF-review pass (4 lenses, each finding
  then independently verified) confirmed the change correct on every input the live caller
  can produce (the `feed_clip_seg` contract edges it raised were unreachable through
  `feed_repaint` because `fwidth >= 1` and `PAINT_CAP` headroom is proven); two zero-risk
  contract-hardening edits (empty-window guard + whole-or-drop carry flush) were applied to
  bring the canonical feed primitive into line with its own docstring before it is reused
  downstream. The painter itself verifies on a real tty (`THOTH_TIER=rich`), not the harness.

## [0.11.2] - 2026-06-25

**Opt-in persistent input history.** Completes the 0.11.1 composer input-history recall:
set `[history].file` in `thoth.cyml` and thoth loads your prior submitted lines into the
recall ring at TUI startup and saves new ones across sessions. **Off by default** (no
`[history].file` → in-memory-only recall, the floor untouched). DISTINCT from
`[hoosh].history` (the model's multi-turn conversation memory). 480 unit assertions (+13).
Pin unchanged (6.2.43).

### Added
- **`[history].file` config** (`src/config.cyr`, `config_history_file`) — path to the
  persistent input-history file; mirrors the `[log].file` opt-in. Unset → persistence off.
- **Persistence I/O** (`src/inhist.cyr`) — a streaming loader (chunked, bounded buffers;
  each line pushed through the ring so dedup/skip-empty/evict apply, keeping the most-recent
  128), a **non-destructive** writability probe at init (create-if-absent without truncating
  — merely starting thoth never rewrites your file), and a rewrite-the-ring saver invoked
  after each stored submit (so the file stays bounded to the recall ring, not append-grow).
  Created mode **0600** on POSIX (best-effort, see below). Uses the portable `lib/io.cyr`
  wrappers (which bridge the AGNOS open ABI), never a raw `sys_open`.
- **Honest startup announce** in the TUI feed — the active path + how many lines were
  recalled, or a degrade-closed "cannot write — in-memory only" note when the path is
  unwritable; plus a one-time "write failed — persistence disabled" note if a save fails
  mid-session.
- **`test_inhist_persist`** (+13): load→ring, the non-destructive-init guarantee (file
  bytes unchanged after binding), save→rewrite→reload round-trip, and the unwritable-path
  degrade. The 0600 create-mode is asserted empirically by `stat` after the suite.

### Security / degrade-closed
- The file holds your **typed composer lines** (which may contain secrets), so a freshly
  created file is **0600** (owner-only) on POSIX targets. This is **best-effort and is
  never asserted as fact in the UI**: the create mode applies only on CREATE (a pre-existing
  looser file keeps its perms — thoth does not silently re-tighten it, since `chmod` is
  absent on Windows and a frozen-ABI no-op on AGNOS, so calling it would fork the floor),
  and the path is opened following symlinks. Documented honestly in `thoth.cyml.example`
  (keep the file in an owner-only directory; don't point it at a pre-existing world-readable
  file). Persistence degrades closed: an unwritable path or a mid-session write failure is
  **announced**, never silently faked.

### Notes
- **Pre-cut adversarial review (4 perspective-diverse lenses — security/file-mode, file-I/O
  + fd safety, floor/posture/portability, integration)** found a real honesty defect — the
  first draft's announce hardcoded "0600", a guarantee not held on AGNOS or for a
  pre-existing file. Fixed before cut: the announce no longer asserts a mode, the init is
  non-destructive, the saver checks write returns and degrades closed, and the residual
  caveats are documented. A targeted re-review confirmed the fixes complete with no
  regression. Persistence + the live TUI verify on a real tty (`THOTH_TIER=rich`), not the
  harness; the load/save/round-trip + degrade paths are covered by `test_inhist_persist`.

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
