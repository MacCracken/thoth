# thoth — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.
>
> **Forward-facing only — what's left to v1.0.** Shipped history lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md) and the version log in
> [`state.md`](state.md); this file is just the road ahead. Where a
> milestone is marked done below, it is a one-line pointer — the detail
> is in CHANGELOG/state.md, not repeated here.
>
> **Where we are (0.22.2):** **M0–M7 are done and shipping**, and every feature line
> through 0.16.x has landed (the log lives in
> [CHANGELOG](../../CHANGELOG.md)/[state.md](state.md)); the `0.16.1` refresh (Cyrius **6.4.16**)
> then the **0.17.x input-completeness line to COMPLETION** — `0.17.0` **bracketed paste**, `0.17.1`
> **word-wise composer editing** (Ctrl/Alt-arrow, Ctrl-W, Ctrl-K), `0.17.2` **SGR mouse** (wheel
> scroll, click focus, tree-row select/expand), `0.17.3` **OSC 52 clipboard copy** (`/copy` — works
> on AGNOS + over SSH), `0.17.4` **turn interrupt** (Esc aborts a streaming turn without killing the
> session); then the **0.18.x re-renderable-feed line** opened with `0.18.0` **the keystone refactor**
> (role-metadata storage + paint-time SGR, byte-identical output; bundled Cyrius **6.4.18**) and `0.18.1`
> **`/theme` recolors scrollback** (the keystone's first payoff — closes the 0.10.0 baked-color limitation;
> bundled Cyrius **6.4.19**); then a full-stack MCP-tool investigation fixed two upstream conformance bugs
> (bote 3.0.1 + daimon 1.3.5), and `0.18.2` re-synced the vendored bote-core to 3.0.1 + refreshed the pin to
> Cyrius **6.4.20** to realign the family. Then `0.18.3` landed the **live-upgrading fenced-code card** (the
> 0.15.1 deferred "Option C" — streamed code renders live, then snaps to highlighted at fence close), and
> `0.18.4` the **feed search** (Ctrl-F / `/find` over the scrollback — match highlight + n/N jump, injected
> into the unchanged soft-wrap clip), refined by `0.18.5` to be **occurrence-granular** (count + n/N step
> every hit, not every line), and `0.18.6` fixed the **confirm-prompt return** (the composer refreshes
> immediately after a gate approval), and `0.18.7` added the **glyph-width table** (CJK/emoji count 2
> columns in the soft-wrap + scrollback math), and `0.18.8` the **inline markdown** (headings/bold/code/list
> markers styled in the feed, composing with `/theme` + search). **The 0.18.x re-renderable-feed line is now
> COMPLETE** (0.18.0 keystone → theme recolor → live card → feed search → occurrence-granular →
> confirm-prompt → glyph-width → inline markdown).
> The 0.10.x data producers
> (tokens, cost), the 0.11.x terminal-citizen backlog in full, the 0.12.x memory seam,
> the 0.13.x git producer (sit), the 0.14.x bote-3.0.0 refresh + the proven end-to-end
> agentic vertical, 0.15.x streaming polish (paint throttle + fenced-code highlighting),
> and the 0.16.0 model `shell` tool. The **four v1.0 gates below are unchanged**
> (AGNOS-dominated). The next active feature work is the planned **0.17.x–0.22.x UX
> lines** below — input completeness → the re-renderable feed → session visibility →
> shell/agent hardening → composer intelligence → the active persona — every item a
> floor/TUI port or a thin spine-consuming seam, none gating; smaller ideas gather in
> the **polish backlog** until enough accumulate to earn a sweep minor.

## Framing (read first)

thoth is **OS-agnostic at the substrate layer and AGNOS-sovereign at the
capability layer**. The two never collide because they govern different
layers:

- **The floor — portable.** Syscalls, allocation, argv, process spawn,
  terminal I/O. The vendored Cyrius stdlib already fans this out across
  one shared codebase to multiple targets behind one stable interface
  (`syscalls_x86_64_agnos` / `syscalls_x86_64_linux` /
  `syscalls_aarch64_linux` / `syscalls_macos` / `syscalls_windows`, plus
  matching `alloc_` / `args_` / `process_` variants). thoth writes
  against the portable interface and picks the target at build time —
  never against a per-OS file.
- **The spine — sovereign.** Model routing and mid-session switching
  (hoosh), agent orchestration + MCP tool execution + the host registry
  (daimon), the MCP protocol (bote), per-tool authorization (t-ron), and
  the Thoth/Librarian archetype overlay (avatara). thoth owns **no**
  domain logic of its own; it consumes this spine and never reimplements
  any part of it.

The bright line: **port the floor; never fork the spine.** thoth may
abstract the OS beneath it, but it must never re-create above it anything
AGNOS already owns. AGNOS is the primary, fully-realized home (native,
co-resident, sandboxed end to end); other operating systems run the
**same** spine reached as a client over a portable transport,
capability-gated. The posture: **everywhere capable, AGNOS canonical** —
portability owns the floor (it always runs), AGNOS owns the ceiling (it
runs best), and the gap between them is an explicit, documented contract.

See [ADR-0001](../adr/0001-os-agnostic-agnos-primary.md) for the full reasoning, [ADR-0002](../adr/0002-consume-the-agnos-stack.md) for the consume-the-stack mandate, and [architecture note 001](../architecture/001-consumer-only-no-domain-logic.md) for the invariant.

## Path to v1.0 — the blocking gates

v1.0 is an **AGNOS gate**: the downstream-green criterion is satisfied
**on AGNOS**, where the whole spine is native. Everything thoth owns is
shipping; the remaining v1.0 work is dominated by AGNOS lighting up plus
two process gates — **not** by presentation or data-producer polish.

Four gates remain, in rough dependency order (gate 1's **build** half cleared at
0.12.3):

1. **AGNOS lane lights up — BUILD half CLEARED (0.12.3).** The last build blocker —
   the agnos peer omitting the signal-number constants (`SIGHUP`; the signal infra
   `sigprocmask`#17 / `signalfd`#18 was already DONE) — is resolved: the **Cyrius
   6.3.38** agnos peer defines the signal enum, so the `--agnos` lane now compiles a
   valid statically-linked x86_64-AGNOS ELF with **zero undefined symbols**, with
   **zero thoth source change** (exactly as forecast). Filed issue
   `agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md` →
   resolved. What remains is the **runtime** half, which is gate 2 (the ELF targets
   the AGNOS syscall ABI and cannot be exercised on a Linux host — it needs a real
   AGNOS runner). **Status: build ✓ (done, 0.12.3) · runtime → gate 2.**

2. **At least one downstream consumer green on AGNOS (external
   verification gate).** Now the nearest advanceable v1.0 gate: gate 1's build
   half is done (0.12.3), so this is unblocked to start — it needs a real AGNOS
   runner to exercise the `build/thoth_agnos` ELF (the spine native, a consumer
   green end to end). **Status: blocking · owner: external · needs an AGNOS host.**

3. **Security review pass (process gate).** A full security review of the
   fail-closed posture, the t-ron authorization choke point, and the
   parallel-tool-execution concurrency model. **Status: blocking · owner:
   TBD · not scheduled.**

4. **1.0 versioning scheme decided (deferred ADR).** thoth stays SemVer
   `0.x` through pre-1.0 by design ([ADR-0004](../adr/0004-semver-pre-release.md)).
   Whether 1.0 adopts CalVer (the binary standard) or stays SemVer is
   deferred to a later ADR. **Status: deferred · owner: thoth · decide
   before the 1.0 tag.**

### v1.0 criteria checklist

**Satisfied on Linux (shipped — see CHANGELOG/state.md):** the core driver loop, the
mid-session model switch through hoosh (M3), MCP tool execution via daimon + bote gated by
t-ron (M4), off-AGNOS security that fails closed, the avatara overlay (M5), the honest
capability ladder (M6), and a complete CHANGELOG. These are now AGNOS-**buildable** (gate 1
build cleared, 0.12.3 → `build/thoth_agnos`); AGNOS-green pends the gate-2 runtime verification.

**Open:**

- [ ] **At least one downstream consumer green on AGNOS** — gate 2 (external)
- [ ] **Security review pass** — gate 3 (not scheduled)
- [ ] **1.0 versioning scheme decided (SemVer vs CalVer)** — gate 4
      (deferred ADR; see [ADR-0004](../adr/0004-semver-pre-release.md))

## Versioning

thoth uses **SemVer `0.x`** through its pre-1.0 phase — see
[ADR-0004](../adr/0004-semver-pre-release.md). This supersedes the earlier
"CalVer at first release" plan: a `0.x` number honestly signals that the
surface is still moving (commands and the seam interface still change
release to release). The 1.0 scheme (CalVer vs. staying SemVer) is gate 4
above, deferred to a later ADR.

## Remaining work (post-M7; NON-GATING)

> **None of this blocks v1.0** — the four gates above take priority. Data fields follow the
> **omit-until-present** policy ([ADR-0010](../adr/0010-data-producer-honest-omit.md)): a
> field surfaces only when its producer has real data, and announces absence in `/state` —
> never faked.

### 0.11.x — terminal citizen + TUI substrate — COMPLETE

The vetted SecureYeoman-TUI-review backlog shipped in full (`0.11.0` → `0.11.8`; one-line
detail in [CHANGELOG](../../CHANGELOG.md)/[state.md](state.md)): the one-shot/argv front-door,
input-history recall + opt-in `[history].file` persistence, feed soft-wrap, `[alias]` prompt
macros, `/dry` request-body preview, `--json` envelope output, `-o`/`--out` file tee, and shell
completion. Every item was a substrate/floor port or a thin seam binding, never a spine fork.
The only 0.11.x items left are deferred:

- **live spine-health** — traffic-outcome reachability + Ctrl-R
  refresh; defer the timerfd tick + active probe until idle-drop detection is actually wanted.
  **Scheduled: `0.19.3`.**
- **clipboard sink** — effort L; needs an upstream cyrius `process` stdin-feed
  primitive (Linux/macOS/Windows). **Architecturally impossible on AGNOS** (frozen
  0-33 ABI: no fork/exec/dup2) → degrades closed there, by ABI, announced.
  **The COPY direction no longer waits on this:** `0.17.3` schedules OSC 52 copy — a
  terminal escape WRITE, no process spawn — which works on AGNOS and over SSH; only an
  external-command paste/sink still needs the process primitive.

### 0.12.x — memory seam (omit-until-mneme; the mneme fallback)

- **`0.12.0` — memory seam + local reader.** A `SEAM_MEMORY` on the capability
  ladder ([ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md)): binds native →
  **mneme** (its 8 `mneme_*` MCP tools, discovered through the daimon registry) when
  mneme's Cyrius port lands; degrades to a thin thoth-owned reader of a project-local
  `.thoth/memory/*.md` flat store (verbatim inject, recency + byte budget, **no
  search** — search/ranking/graph are mneme's) when absent; `absent` (off) by default.
  Opt-in `[memory].enabled` (a checked-in `.thoth/memory` is a prompt-injection
  surface, same trust as `CLAUDE.md`). Injected as a second `{role:system}` message
  after the avatara persona, before history — the same context-assembly verb thoth
  already ships. Notes match mneme's vault frontmatter, so the fallback store is later
  ingestible by mneme (not throwaway). Announced in `/seams` + `/state`, never faked.
- **`0.12.1` — `/remember`.** Verbatim append to `.thoth/memory/MEMORY.md`,
  t-ron-gated under the reserved name `thoth_remember` (no new security surface).
  Never summarized or curated — curation is the human's or mneme's.
- **`0.12.2` — `memory_write` MCP tool + `AGENTS.md` pickup.** The agentic loop can
  write memories through the existing daimon + t-ron choke point; an optional
  project-root `AGENTS.md` is added to the read set.

The bright line ([ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md)): thoth owns
**reading + injecting** (content-blind recency + budget); mneme owns the **engine**
(retrieval, embeddings, ranking, auto-link, graph, curation). The cardinal risk is
relevance-creep — "select the *relevant* memories" is retrieval, a spine fork; the
selection stays content-blind.

### 0.13.x — git producer (SHIPPED — consumes sit)

- **`0.13.0` — git producer. DONE (2026-07-03).** Real branch / status via **sit**'s
  read-only VCS API — no faked branch/diff, no hand-rolled `.git/` parser (sit owns VCS —
  ADR-0010). Surfaced in `/state`, the TUI status bar (omit-until-present), and a new `/git`
  command (per-file `M`/`A`/`D`). `SEAM_GIT` on the ladder; `src/git.cyr` + `scripts/sync-sit.sh`.
  Unblocked by **sit 1.3.0**'s lean read-only dist profile (`dist/sit-read.cyr`) — the "sit ships
  `.git/` read-mode" gate cleared (sit 1.2.0 shipped read-mode; 1.3.0 made it cleanly consumable).
  Vendors sit-read + **sankoch 2.2.5** (the 2.4.8 pin overflows cyrius's 1024-global cap); the
  chdir-free open keeps the AGNOS build (gate 1) and works there. See CHANGELOG/state.md.
- **`0.13.1` — refold onto patched deps. DONE (2026-07-03).** sit 1.3.1 made `sit_repo_open`
  chdir-free and sankoch 2.4.9 shipped a lean `[lib.zlib]` distlib profile (53 globals vs 175), so
  thoth dropped two of its three vendor workarounds: the `SYS_CHDIR` neutralisation (AGNOS now builds
  git natively) and the `_stream_grow` rename (the zlib profile drops `stream.cyr`), and moved off the
  old sankoch-2.2.5 pin onto the current 2.4.9 zlib profile. Only the `entry_hash`/`ann_new` renames
  remain (sit's fns vs thoth's libro/bote — inherent). No behavior change. See CHANGELOG/state.md.
- **`0.13.2` (deferred follow-up)** — per-file `sit_diff_path` diff rendering in `/git`. The aarch64
  best-effort lane stays size-gapped until the binary's static data (sigil-dominated) shrinks or the
  cyrius output cap rises — unrelated to sankoch's version. **The diff half is scheduled: `0.19.2`.**

### 0.16.x — the model's `shell` tool (SHIPPED)

- **`0.16.0` — model-invokable `shell` tool + protections. DONE (2026-07-06).** A thoth-native,
  opt-in, POSIX-only agentic tool: the model proposes a command, thoth runs it under a timeout,
  captures merged stdout+stderr, and returns a bounded result — mirroring the `memory_write`
  local-tool shape, gated under the **distinct** reserved t-ron name `thoth_shell` (vs `thoth_run`).
  Defense in depth: a local `[shell.deny]`/`[shell.allow]` glob filter **before** t-ron, the
  `thoth_shell` gate, a bounded+timed capture (`exec_shell_capture` in `src/exec.cyr`), and an audit
  of every command. `[shell]` config; a `/state` row (omit-when-off). Degrades closed on AGNOS/Windows
  (no capturing `/bin/sh` — announced, not advertised). Byte-identical floor when off. Also bundled the
  toolchain refresh to Cyrius **6.4.11**. [ADR-0014](../adr/0014-model-shell-tool-local-posix-gated.md).
- **Deferred `shell` follow-ups** (none blocking; each degrades honestly today —
  **now scheduled as the `0.20.x` line below**):
  - **`agent_enabled()` relax** — let `[shell].enabled` enter the agentic loop even without daimon, so
    the shell tool is usable standalone. A core-routing change (touches `cmd_task` + the request
    builder + the iter paths); today the tool follows the `memory_write` precedent (advertised only
    with daimon wired) and `/state` announces "gated on daimon", so it is never silently inert.
  - **Windows timed capture** — a `WaitForSingleObject`(finite)+`TerminateProcess` + pipe/temp-file
    drain, once verified on the Windows host; today Windows is treated like AGNOS (unadvertised, announced).
  - **process-group kill on timeout** — `setpgid` the child + `kill(-pgid)` so a backgrounded grandchild
    is also killed; today the SIGKILL reaps the `/bin/sh`, not its descendants (documented, matches `/run`).

### 0.17.x — input completeness (PLANNED)

> The one live input defect plus four terminal-I/O items. `0.17.0`–`0.17.3` are
> TUI-side decode/paint work riding the existing unified CSI parser — no spine
> surface, floor byte-identical by construction (none of this code is reachable off
> PT_RICH). `0.17.4` is the line's one exception: it reaches into the turn loop and
> earns its own design pass. Paste ships first because it is the sharpest everyday
> friction.

- **`0.17.0` — bracketed paste. DONE (2026-07-07).** `CSI ?2004h` on TUI enter (disabled on
  every exit, paired with the kitty push/pop), `ESC[200~`…`ESC[201~` decoded, and the whole
  paste inserted into the composer as literal text — no longer submitting at the first newline.
  `KEY_PASTE` + `_tui_paste_slurp` (bounded, single capped writer, marker matcher) + the pure
  `led_paste` filter (LF/CRLF→one `\n`, tab→space, ESC/C0/DEL dropped = no escape injection).
  TUI-only → floor byte-identical (verified). Two-pass adversarial review: design pass folded 2
  should-fixes, diff pass zero findings. 825 assertions. See CHANGELOG/state.md.
- **`0.17.1` — word-wise composer editing. DONE (2026-07-07).** Ctrl/Alt-arrow word motion
  (+ Alt-b/Alt-f), Ctrl-W delete-word, and Ctrl-K kill-to-end (join-on-second-K) — readline
  parity for the raw-mode composer. Pure `_led_word_left`/`_led_word_right`/`_led_delword`/
  `_led_kill_eol` (WERASE word model, `i > 0`-first bounds), decoded across legacy CSI/control
  bytes + the kitty CSI-u forms. TUI-only → floor byte-identical. Two-pass adversarial review:
  design pass folded 2 should-fixes, diff pass zero findings. 861 assertions. See CHANGELOG/state.md.
- **`0.17.2` — mouse. DONE (2026-07-07).** SGR mouse (`?1000h`+`?1006h`): the wheel scrolls
  the feed (any focus), a left-click in the tree pane selects the node (dir toggles expand/collapse,
  file selects) + focuses the tree, a click elsewhere focuses the composer. Pure `_tui_mouse_decode`
  + `_tui_read_mouse` (`ESC[<Cb;Cx;Cy(M|m)`) + `_tui_mouse_click` (row→node via the painter's own
  `_ftree_scroll_first` geometry); enabled on TUI enter, disabled on every exit (no mouse-mode leak).
  TUI-only → floor byte-identical. Two-pass adversarial review: design pass folded 2 decode nits, diff
  pass zero findings. 872 assertions. See CHANGELOG/state.md.
- **`0.17.3` — OSC 52 clipboard copy. DONE (2026-07-07).** `/copy` base64-encodes the last reply
  and writes an OSC 52 set-clipboard escape (`ESC ] 52 ; c ; <base64> BEL`) straight to fd1 — a byte
  write, no fork/exec/dup2, so it works on AGNOS (the lane builds it) and over SSH. The escape bypasses
  the `OUT_RING` feed sink (write-all loop for the ~87 KB payload); gated on `ui_isatty(1)` so piped/CI
  output is never polluted; best-effort (never asserts success); not t-ron-gated (SET only, no query —
  same class as `/read`). Two-pass adversarial review: design pass folded a should-fix + a nit, diff pass
  zero findings. 875 assertions. See CHANGELOG/state.md.
- **`0.17.4` — turn interrupt. DONE (2026-07-07).** Esc aborts a streaming turn (plain or
  agentic) without exiting the session: partial output stays in the feed with an honest
  `— interrupted` marker, history stays consistent, control returns to the composer. NEW
  `intr_*` module (a `VMIN=0/VTIME=0` poll termios bracketed around each streaming read, since a
  turn runs cooked for the confirm); both SSE callbacks `intr_poll()`→`return 0` on Esc; a
  thoth-side flag discriminates abort from `[DONE]`; `agent_turn` gains an interrupted outcome
  (kind 4) that keeps the partial. TUI-only + `#ifdef CYRIUS_TARGET_LINUX` → floor byte-identical
  (agnos/win/macos still build). Documented limits: streaming-only (a blocking turn is one POST);
  per-frame granularity (a stalled stream / an Esc during tool-exec lands at the next frame).
  Two-pass adversarial review: design pass caught + folded a history-dispatch BLOCKER (kind==4
  fall-through) + the stalled-stream limit, diff pass zero findings. 875 assertions. See
  CHANGELOG/state.md. **The 0.17.x input-completeness line is COMPLETE.**

### 0.18.x — the re-renderable feed (PLANNED)

> The architectural keystone of the line: the feed ring stores PAINTED bytes (baked
> SGR), which is why `/theme` cannot recolor scrollback (0.10.0 known limit) and why
> the 0.15.1 fenced-code card was deferred. Store logical lines + role metadata and
> apply SGR at paint time; everything after `0.18.0` is unlocked by it.
>
> **DIVERTED then RESOLVED (2026-07-07):** the feature line paused for a full-stack MCP-tool
> investigation — a live-stack test found a handful of tools returning no usable result. The root
> cause was UPSTREAM (bote's `bote_echo` + daimon's `libro_*` built-ins returned bare JSON, not the
> MCP content-block envelope) plus a `scripts/stack.sh` policy gap (`libro_*` denied). Fixed across
> the spine — **bote 3.0.1** (`bote_echo` → content block) and **daimon 1.3.5** (`_mcp_wrap_builtin`
> wraps the `libro_*` results), both on cyrius 6.4.20, + thoth's stack policy — and verified end to
> end. thoth needed NO src change (it was already a correct, strict MCP client). `0.18.2` was the
> maintenance realign (re-sync vendored bote-core → 3.0.1 + toolchain → 6.4.20). The feature line then
> resumed at `0.18.3` (live card) → `0.18.4` (feed search) → `0.18.5` (occurrence-granular) → `0.18.6`
> (confirm-prompt return) → `0.18.7` (glyph-width table) → `0.18.8` (inline markdown), all DONE — **the
> 0.18.x line is COMPLETE**. The `0.19.x` session-visibility line then opened with `0.19.0` (context-budget
> meter, DONE, + the Cyrius 6.4.21 refresh) → `0.19.1` (live turn telemetry, DONE) → `0.19.2` (`/git`
> per-file diff, DONE) → `0.19.3` (live spine-health, DONE) — **the 0.19.x session-visibility line is
> COMPLETE**. The `0.20.x` shell/agent-hardening line then opened with `0.20.0` (`agent_enabled()` relax —
> shell standalone, DONE) → `0.20.1` (process-group kill on timeout + Cyrius 6.4.23, DONE) → `0.20.3`
> (array-value shell deny/allow config via bayan 1.1.0, DONE) → `0.20.4` (**Windows timed capture — the
> deferred `0.20.2` item, DONE**: Cyrius 6.4.26 shipped the `TerminateProcess` primitive thoth filed for, so
> the model's `shell` tool now works on Windows, verified end-to-end on `cass`; bundled the 6.4.26 refresh) —
> **the 0.20.x shell/agent-hardening line is COMPLETE**. The `0.21.x` composer-intelligence line then opened
> with `0.21.0` (**`@file` mention expansion, DONE** — `@path` injects a file as delimited prompt context via
> the new pure `src/mention.cyr`, riding the `/read` posture) → `0.21.1` (**tree-fed `@` Tab completion,
> DONE** — `Tab` completes a `@<prefix>` from the file tree in the composer; live-verified in the rich TUI).
> The `0.22.x` active-persona line then opened with `0.22.0` (**mid-session `/persona` switch, DONE** — the
> signature move's twin, swapping the active avatara archetype mid-session like `/model` swaps the model;
> bundled the Cyrius 6.4.29 refresh) → `0.22.1` (**`/personas` discovery, DONE** — browse the traditions +
> archetypes and the active card, read-only over avatara) → `0.22.2` (**blends + shadow, DONE** — `/persona
> blend` weighted-composes archetypes and `/persona shadow` wears the inverted aspect, avatara-native verbs).

- **`0.18.0` — the refactor. DONE (2026-07-07).** The ring stores logical text + compact **role
  markers** (`ESC` + `0xB0..0xB7`/`0xBF`, reverse-mapped at seal by `_feed_pack` via `ui_role_of_sgr`);
  the painter (`feed_clip`/`_seg`) **expands a marker to the current theme's SGR at paint** — byte-identical
  rendered output for the current theme, golden-tested on both paint paths. `ui_sgr` unchanged (paint-path
  `emit_raw(ui_sgr)` sites forced the reverse-map-at-store approach); markers are unforgeable (a raw
  `ESC`+marker-byte in untrusted output is sanitized). `PAINT_CAP` raised for expansion. **Bundled the
  Cyrius 6.4.18 refresh** (pin-only, zero floor content change). TUI-only → floor byte-identical; all lanes
  build. Two-pass adversarial review: design pass caught a blocker + folded a collision sanitizer, diff
  pass folded one test-coverage should-fix. 890 assertions. See CHANGELOG/state.md.
- **`0.18.1` — `/theme` recolors scrollback. DONE (2026-07-07).** The 0.18.0 keystone's first payoff:
  because the ring stores role markers, a theme switch (`/theme` or ⌃T) rebuilds the SGR table and the
  post-dispatch `feed_repaint` re-expands every stored marker with the new theme — closing the 0.10.0
  "existing lines keep baked colors" limitation for all role-colored text + syntax highlighting, with no
  production code change beyond validation + a doc fix. Residual (documented): diff-row background tints
  are verbatim, so they don't recolor. Bundled the Cyrius **6.4.19** refresh (pin-only, zero floor change).
  895 assertions. See CHANGELOG/state.md. *(Reordered ahead of the live card — it was near-free once the
  keystone landed and directly validates it.)*
- **`0.18.2` — maintenance: bote-core re-sync + toolchain 6.4.20. DONE (2026-07-07).** After the
  full-stack tool investigation (above) landed the upstream fixes, thoth re-synced its vendored
  `bote-core` to 3.0.1 (only the embedded version string moved — the `[lib.core]` dispatcher is
  byte-identical, since bote's fix was server-side) and refreshed the pin `6.4.19 → 6.4.20` to realign
  with bote 3.0.1 / daimon 1.3.5. No thoth src change. 895 assertions. See CHANGELOG/state.md.
- **`0.18.3` — live-upgrading fenced-code card. DONE (2026-07-07).** The 0.15.1
  deferred "Option C": streamed code renders live line-by-line, then upgrades in place
  to the highlighted block at fence close (or on interrupt/truncation) — removes the
  withhold-until-close gap. TUI-only (needs the re-renderable feed); net-result-preserving
  so the floor is byte-identical. New `feed_drop_last`/`feed_drop_pending` primitives +
  `_mdhl_block_close`; an over-clamp guard (skip the upgrade for a block larger than the
  ring) caught by the pre-cut diff-review. 910 assertions. See CHANGELOG/state.md.
- **`0.18.4` — feed search. DONE (2026-07-08).** Ctrl-F / `/find` over the ring: match
  highlight + n/N jump. A pure engine (`src/fsearch.cyr`) matches the visible text of every
  ring line (case-insensitive ASCII, marker/escape-transparent, glyph-aligned); a TUI modal
  highlights matches by injecting reverse-video into a per-line temp buffer handed to the
  UNCHANGED `feed_clip_seg` (net-floor-safe). Two-phase: type to search incrementally, Enter
  to a nav phase where n/N jump. Design review caught + folded an EOF hang, a carry overflow
  (reset-collapse match-off), and cursor-park on repaints; diff review clean. 936 assertions.
  See CHANGELOG/state.md.
- **`0.18.5` — feed search: occurrence-granular. DONE (2026-07-08).** Live-test follow-up
  to 0.18.4: the `i/n` count + n/N now step every HIT (a line with two matches is two
  occurrences), and a line's CURRENT occurrence is drawn reverse+underline (by byte offset)
  vs reverse for the rest. Per-occurrence `(line, offset)` state; the match cap is announced
  (`i/n+`) not silently truncated. 941 assertions. See CHANGELOG/state.md.
- **`0.18.6` — confirm-prompt return. DONE (2026-07-08).** Live-test follow-up: after a
  t-ron gate confirm during an agentic turn, the composer prompt now refreshes immediately
  (was: the confirm line stayed stuck on the composer row until the whole response finished)
  — `tui_confirm_end` repaints the frame while still on OUT_FD1 (chrome to the screen, not the
  ring), then resumes capture. Independent code-trace verified (out_mode balance, ring
  read-only mid-dispatch). 941 assertions. See CHANGELOG/state.md.
- **`0.18.7` — glyph-width table. DONE (2026-07-08).** East-Asian-Wide/Fullwidth + emoji
  count 2 columns (combining/ZW = 0) via `feed_glyph_cols`, shared by all three feed
  col-counters so `feed_rows_for = ceil(display-cols/width)` stays consistent — a CJK/emoji
  line no longer overflows its width. ASCII byte-identical. Declared residuals: a wrap-boundary
  wide glyph clips 1 col at the (rightmost) feed edge (no loss/dupe); ambiguous 0x2600–0x27BF
  treated wide; ZWJ sequences overcount. Diff-review folded a tree-column truncation nit. 955
  assertions. See CHANGELOG/state.md.
- **`0.18.8` — inline markdown rendering. DONE (2026-07-08).** Extends reply rendering
  beyond fenced code: headings/bold/inline-code/list-markers styled in the feed (mdhl's
  prose branch grows an inline pass). Colors go through role markers so `/theme` recolor +
  search highlighting compose (fsearch_render gained bold-tracking so a match inside bold
  keeps it); raw bytes untouched off PT_RICH + in `_hoosh_acc`/history/`--json`;
  `strip_sgr(output)==raw` (0.15.1 discipline, property-tested). Linear scanner. Design
  review folded the search-inside-bold gap + the O(n²) latch; diff review clean. 974
  assertions. **This closes the 0.18.x re-renderable-feed line.** See CHANGELOG/state.md.

### 0.19.x — session visibility (COMPLETE — 0.19.0–0.19.3 DONE)

> Surfacing data thoth already has (or already probes) — no new producers, no spine
> surface. Items are independent slices; omit-until-present per ADR-0010 where a
> producer can be absent.

- **`0.19.0` — context-budget meter. DONE (2026-07-08).** Framed history bytes vs the
  exact 32 KiB (`HOOSH_REQ_CAP/8`) evict boundary in the status bar (`ctx <n>K/32K`, red on
  eviction) + `/state` (bytes + `N oldest evicted`). Pure `hoosh_ctx_bytes`/`_budget`/
  `_evicted` mirror `_hoosh_history_start` line-for-line, so the meter IS the eviction
  decision. Omit-until-present (single-turn/empty). Bundled the Cyrius **6.4.21** refresh.
  984 assertions. See CHANGELOG/state.md.
- **`0.19.1` — live agentic-turn telemetry. DONE (2026-07-08).** Each `tool-call:` gains a
  faint `· <verdict> · <ms>ms · <bytes>B` sub-line; the roundlog records ms+bytes per call
  (so `/audit` shows them); the spinner reads `running <tool>…` (or `N tools` for a parallel
  batch). Serial path times gate+invoke; parallel path times each call in its worker slot
  (PAR_CTX_SZ 48→56). Diff review clean. 986 assertions. See CHANGELOG/state.md.
- **`0.19.2` — `/git` per-file diff. DONE (2026-07-08).** `/git <path>` renders a file's
  diff (HEAD vs worktree) via `sit_diff_path` through the colored diff renderer — new
  `diff_render_ann` colors sit's annotated line-ops by reusing `_diff_emit_line` (the same
  gutter + syntax highlight `/read` uses); `sit_diff_path`==0 → honest "no changes". Verified
  live + code-trace clean. 993 assertions. See CHANGELOG/state.md.
- **`0.19.3` — live spine-health. DONE (2026-07-08).** A cached hoosh reachability driven by
  traffic outcomes (a turn's transport failure → DOWN, any answered request → UP; no idle
  timer), shown as a green/red ● dot by the model in the status bar, seeded by the startup
  probe and re-probed on Ctrl-R. Two chokepoints (`hoosh_send` rc, `agent_turn` round kind);
  Esc-interrupt is neutral. Verified (code-trace clean). 998 assertions. **Closes the 0.19.x
  session-visibility line.** See CHANGELOG/state.md.

### 0.20.x — shell/agent hardening (0.20.0–0.20.1, 0.20.3–0.20.4 DONE; 0.20.2 delivered as 0.20.4)

The 0.16.0 deferred follow-ups, promoted to a line:

- **`0.20.0` — `agent_enabled()` relax. DONE (2026-07-08).** `[shell].enabled` (POSIX)
  enters the agentic loop without daimon, so the shell tool is usable standalone.
  `[hoosh].tools` stays the master switch; tool source = daimon OR shell. The design +
  diff reviews caught that the daimon-absent path needed **null-deref crash guards** (force
  serial + refuse a non-local tool — the parallel/serial daimon call `strlen`s a null URL);
  `/state`+`/tools` reworded; security unchanged (shell stays t-ron-gated, local-only). Floor
  byte-identical for daimon-wired/shell-off. 1008 assertions. See CHANGELOG/state.md.
- **`0.20.1` — process-group kill on timeout. DONE (2026-07-08).** The shell child
  `setpgid(0,0)`s into its own group and a timeout `kill(-pgid, SIGKILL)`s the whole group
  (+ a direct child kill so the reap never hangs), so a backgrounded grandchild dies with
  the `/bin/sh`. Code-trace confirmed `kill(-pid)` can never hit thoth's group; x86_64-only
  (declared, aarch64 gapped). Proven by a marker-based grandchild-death test. Bundled the
  Cyrius **6.4.23** refresh. 1010 assertions. See CHANGELOG/state.md.
- **`0.20.2` — Windows timed capture. DONE — delivered as `0.20.4` (2026-07-08).** Blocked at
  first because the Cyrius Windows PE surface had spawn/wait/exit-code/pipe but **no
  `TerminateProcess`** (a timed-out child could be *detected* but not *killed* — shipping it would
  leak). thoth filed cyrius issue `2026-07-08-windows-pe-surface-no-terminateprocess`; Cyrius
  **6.4.26** added the `TerminateProcess` reroute (syscall `0xF01D`) + `_win_terminate` /
  `_win_wait_timeout` in `lib/process_win.cyr`. A design workflow + empirical `cass` testing then
  established that a **temp-file** (not a pipe) is the correct mechanism — the pipe path deadlocks
  and false-timeouts any command exceeding the ~4 KiB pipe buffer (no `PeekNamedPipe`/overlapped-
  I/O for concurrent draining). Landed out-of-order **as `0.20.4`** (after `0.20.3`, to keep the
  version monotonic), bundling the 6.4.26 refresh; verified end-to-end on `cass`. The full thoth
  `--win` binary stays IOCP-gated on the async/epoll transport (`lib/async.cyr`); this shell
  capture is proven via a minimal exec-only `--win` harness and ships with the Windows binary when
  that separate gate lifts.
- **`0.20.3` — array-value shell deny/allow config. DONE (2026-07-08).** The
  `[shell.deny]`/`[shell.allow]` glob lists modelled as `label = "glob"` sections *because* bayan
  (≤ 1.0.4) had no TOML array-VALUE getter now move to the natural `deny = ["…"] / allow = ["…"]`
  array form under `[shell]`, read via `bayan_toml_get_array` (bayan **1.1.0**). The array form is
  canonical and wins when present (an explicit `[]` means zero, no fallback); a bare scalar string
  is accepted leniently as one glob (never a silent-zero deny-list); the `label = "glob"` section
  form stays a documented back-compat alias used only when the array key is absent. 1021
  assertions (+11). See CHANGELOG/state.md.

### 0.21.x — composer intelligence (0.21.0–0.21.1 DONE)

- **`0.21.0` — `@file` mention expansion. DONE (2026-07-08).** A `@path` in a submitted
  message injects the named file into the prompt as explicit, delimited context — the
  expansion CORE (new pure `src/mention.cyr` `mention_expand`/`mention_count`, unit-tested),
  wired into `cmd_task` + `cmd_dry` so it works in the REPL, TUI, and one-shot and is visible
  in `/dry`. Multiple mentions compose; a non-resolving `@token` stays LITERAL (prose like
  `foo@bar` / `@handle` never mangled — `@` counts only at start/after-whitespace); rides the
  `/read` machinery + posture (no new read path, no new security surface). Bounded (16 KiB/file,
  32 KiB total == `HOOSH_REQ_CAP/8`, 16 files; reused buffers); byte-identical passthrough when
  nothing resolves. 3-lens adversarial review clean; 1037 assertions (+16); live-verified.
- **`0.21.1` — tree-fed Tab completion. DONE (2026-07-08).** `Tab` on a `@<prefix>` in the
  composer completes the path from the file tree; with the cursor NOT on a `@`-token, `Tab` keeps
  its prior composer↔tree focus-toggle. `ftree_complete` lists the prefix's directory live via the
  tree's own `dir_list` (works at any depth without expanding the pane; unique → full completion +
  `/` for a dir, multiple → longest common prefix); `mention_prefix_at` reuses the 0.21.0 token
  rules; `_tui_at_complete` + `led_insert_cstr` do the insert. A 3-lens adversarial review caught a
  mid-token splice bug (fixed pre-cut: the cursor must be at the END of the token). 1062 assertions
  (+25); live-verified by driving the real rich TUI through a PTY.
- Further slices (e.g. the model-picker palette from the polish backlog) may promote into this
  line once vetted.

### 0.22.x — the active persona (0.22.0–0.22.2 DONE)

> The signature move's twin: thoth switches the backing MODEL mid-session (hoosh);
> this line switches the ACTIVE PERSONALITY mid-session (avatara). Pure consumption —
> the vendored avatara already ships hundreds of validated archetype profiles across
> ~25 traditions with a full registry (`all_profiles`/`lookup`/`find_and_validate`/
> `by_tradition`/`all_traditions`), trait queries, weighted composition (`compose`),
> affinity/conflict scoring, and shadow derivation — and thoth today consumes exactly
> ONE of them (`egyptian_thoth()`, cached once per process, `src/session.cyr`). The
> bright line (same shape as the memory seam): avatara owns the personality CONTENT
> and every personality VERB (validation, composition, affinity, shadow); thoth owns
> selection + injection + surfacing, content-blind — never a line of thoth-authored
> persona prose.
>
> The naming's own logic (2026-07-07): the deity Thoth carries MANY roles; the
> application draws on ONE — the **keeper of symbols and language** (code being
> both). Other archetypes lean into their own personas, which is the point — a
> dynamic chat mechanism. The selection principle throughout the line: **default
> to what benefits the user's task**; expressiveness is opt-in, never imposed.

- **`0.22.0` — `/persona <name>` mid-session switch. DONE (2026-07-08; bundled the
  Cyrius 6.4.29 refresh).** Resolves through avatara's `find_and_validate` (unknown name →
  honest refusal — the `/personas` hint lands with 0.22.1), swaps the cached profile and
  rebuilds the persona system prompt — `_persona_sys` becomes dirty-flag-invalidatable and
  rebuilds IN PLACE (no per-switch leak) — effective next turn, exactly `/model`'s semantics.
  Startup default via `[persona].name` (absent → `egyptian_thoth`, byte-identical floor; unknown
  → falls back to default, surfaced honestly). Active persona in the status bar + `/state` +
  `/help`. `persona_role` name-conditional (default → "the Librarian", switched → avatara `desc`);
  the THOTH backronym stays the app's fixed naming. 1076 assertions (+14); 3-lens review found no
  code defects; live-verified (`/dry` shows the rebuilt archetype system prompt).
  **Identity split (decided 2026-07-07):** the **THOTH backronym is the
  application's naming** — a fixed purpose statement of the tool itself ("Thinks,
  Handles, Orchestrates, Transforms, Heals" reads as what the program *does*),
  never assigned to or presented as the active archetype's attribute. The **role
  follows the switch** — "the Librarian" remains thoth's own framing for the
  default Thoth archetype only; a switched persona's role is sourced from the
  profile's OWN avatara fields (desc / domain / tradition — exact sourcing settled
  in the design pass), never thoth-authored role prose per archetype (that would
  be authoring personality content, avatara's domain).
- **`0.22.1` — `/personas` discovery. DONE (2026-07-08).** Lists traditions
  (`all_traditions`, with per-tradition archetype counts), browses one (`by_tradition`,
  marking the active archetype `●`), and shows the active profile's card (name / tradition /
  desc + a word-bounded soul excerpt via `_persona_excerpt`). Discovery + display only —
  read-only, no new personality logic; the `/persona` refusal now hints `/personas`. 1078
  assertions (+2); 3-lens review clean (2 nits refuted); live-verified.
- **`0.22.2` — blends + shadow. DONE (2026-07-08).** `/persona blend <name>[:weight] …`
  (weighted multi-archetype blend via avatara's `compose`; optional integer weights, the
  dominant leads the voice, `"A + B"` composite name + merged tradition) and `/persona shadow
  [name]` (avatara's `shadow()` — inverted traits + its own shadow prose). Avatara-native verbs,
  pure consumption — thoth authors no persona prose (blend = the dominant's, shadow = avatara's).
  The composed profile is usable (compose carries the dominant's soul/spirit + name), so no
  prompt-budget issue and no dep bump. 1085 assertions (+7); 3-lens review clean; live-verified
  (`/dry` shows a blend in the dominant's voice).
- **`0.22.3` — role modality (long-term).** The second axis: an archetype is
  multi-faceted (Thoth alone is scribe / keeper of symbols / measurer / mediator),
  so long-term the user can switch WHICH ASPECT of the *active* archetype is leaned
  into — distinct from switching archetypes. Honest gating: aspect modeling is
  avatara's domain — its native modality verbs today are `shadow(p)` (the shadow
  aspect) and `compose()` (weighted emphasis); a first-class per-archetype
  role/aspect registry is an **avatara feature to request** when this slice becomes
  real. thoth never hand-authors aspect tables (the same bright line as 0.22.0's
  role sourcing).

### Polish backlog (gathers until it earns a sweep minor)

> Small, independent UX items are parked here as they surface. **Convention:** none
> is scheduled individually; when enough have gathered (or a natural gap opens
> between lines), a **polish minor** sweeps a vetted batch. Each item still gets the
> normal design/review/test discipline at promotion time, and is re-sized at vet
> time — an item that turns out line-sized gets its own line instead of riding the
> sweep.

- **Conversation resume** — opt-in `[session].file` persisting conversation history
  across restarts (distinct from `[history].file` keystrokes and the memory seam's
  durable facts). Likely the largest item here — may earn its own line at vet time
  (persistence + a secrets-on-disk surface, same class as 0.11.2).
- **Model picker palette** — an interactive fuzzy picker over hoosh's model list
  (the signature mid-session switch, made discoverable) instead of typing
  `/model <id>` verbatim. Natural rider on the 0.21.x line.
- **File-tree git badges** — `M`/`A`/`D` markers on tree rows from the
  already-probed sit status (content-blind surfacing, no new probe).
- **Transcript export** — `/save <file>` writes the session as markdown.
- **Terminal niceties** — OSC 0 window title (`thoth — <model>`), BEL on turn
  completion, a faint per-turn elapsed line after each reply.
- **`/reload`** — re-read `thoth.cyml` mid-session.

### Deferred / known limitations (captured so they're not lost)

> Not on an active line — each is gated on an external/substrate primitive or is
> low-priority hardening. **None is a correctness bug**; each degrades honestly today.
> Recorded here so it isn't lost in code comments.

- **`rainbow` theme** — a per-grapheme HSV render mode (a render mode, not a role table);
  needs the **anuenue** lib vendored. Announced not-yet-available, never faked.

- **Input-history file hardening (0.11.2 follow-ups).** The opt-in `[history].file` is
  best-effort-secured today (a fresh file is created `0600` on POSIX; degrade-closed —
  an unwritable path / mid-session write failure is announced). The residuals below are
  documented honestly in `thoth.cyml.example` + `src/inhist.cyr` and wait on portable
  substrate primitives:
  - **tighten a pre-existing / loosely-permissioned file to `0600`** — needs a portable
    `chmod`/`fchmod` wrapper. Today `sys_chmod` is **absent on Windows** and a
    **frozen-ABI no-op on AGNOS**, so calling it would fork the floor / break the `--win`
    lane; a fresh file gets `0600` on create but an existing looser file is left as-is
    (we never silently re-tighten — and never assert a mode we can't enforce). Lands if
    `lib/io.cyr` grows a portable file-mode wrapper.
  - **`O_NOFOLLOW` on the history-file open** — needs a portable no-follow bit (the AGNOS
    `AO_*` open bridge defines none). Defense-in-depth against a symlink redirect on a
    secret-bearing file; until then it's documented "keep it in an owner-only directory."
  - **`~`/`$HOME` path expansion + a `histfilesize`-style trim** — the path is used
    verbatim (no shell `~` expansion) and the file is bounded to the recall ring
    (128 lines). Minor polish, not blocking.

- **AGNOS substrate gap surfaced by 0.11.2 — `sys_open` carries no create-mode channel.**
  The agnos open bridge (`lib/io.cyr`, against the frozen 0-33 ABI) maps `O_*`→`AO_*` but
  has no permission-mode argument, so a file created on AGNOS lands at the kernel default,
  not `0600`. A documented floor gap (same class as the SIGHUP one); a **candidate to file
  against the agnos peer** if/when the ABI gains a mode channel. thoth already degrades
  honestly (never asserts a mode it can't enforce). **Not a v1.0 blocker.**

## Off the v1.0 path

- **T3 desktop — ceiling, off the v1.0 path.** thoth-in-**puka** (puka's
  own v3 command center names thoth as its consumer). No webview in the
  sovereign core.

## Out of scope (for v1.0)

The deliberate non-goals — these keep future contributors from forking
the spine or diluting the identity by accident.

- **Any OS-specific reimplementation, bundling, or substitute** for a
  domain AGNOS already owns — inference (hoosh), MCP protocol (bote), MCP
  security (t-ron), orchestration / tool host (daimon), or archetype
  (avatara). No "offline" / "embedded" forks that dodge the spine.
- **A bundled local inference path** to escape hoosh, a **hand-rolled MCP
  client** to escape bote, or an **ad-hoc auth shim** to escape t-ron.
  These are the precise failure modes the identity ADR exists to prevent.
- **A swappable-backend abstraction** that lets the spine be replaced with
  arbitrary alternative implementations — the capability seam binds to the
  **same contract** (native vs. reached-as-client), not to competing
  backends. thoth drives the AGNOS spine; it does not abstract it away.
- **Off-AGNOS feature parity.** Parity is an AGNOS-only promise;
  elsewhere thoth runs a faithful, capability-gated baseline.
- **Silent degradation** of any capability, especially security. Missing
  capabilities fail closed and are announced — never faked.
- **A separate per-OS agent UX or "AGNOS edition" fork.** One driver, one
  UX, many substrates.
- **Declaring a spine crate as a dep before its seam milestone wires it.**
  Each seam binds in its own milestone, not speculatively ahead of design:
  daimon / bote / t-ron land in M4, avatara in M5. (hoosh, wired in M3, is
  the exception that proves the rule — it is consumed as a *running HTTP
  gateway*, not a linked crate, so it never becomes a `cyrius.cyml`
  git-dep; the stdlib `sandhi` transport is what M3 declared.) The
  **off-AGNOS reach transport** — the native-vs-remote binding
  distinction — is deferred to a later ADR once that work is real.
