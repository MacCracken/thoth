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
> **Where we are (0.34.4):** M0–M7 and the **entire** post-M7 feature arc have shipped — the terminal-citizen
> front door, the rich TUI, the sovereign **T3 desktop GUI** (`thoth gui`) with tool-call cards + colored diff
> cards + a conversation sidebar, the model **`shell`** / **`edit`** / **`create_file`** tools (thoth now reads
> *and writes* code), the **memory arc** (consume mneme — `/remember`, semantic recall, citations, grounding,
> `/notes`), the **chat-management arc** (named multi-conversation store, persisted across restarts with each
> reply's model / cited sources / tool calls, `/search`), the **complete 0.34.x chat-UX arc** (message actions
> `/retry`+`/edit`; stop/interrupt in the TUI + GUI; `/bookmark` a reply into mneme + `/thumbs` feedback), the git /
> surface producers, the model picker, the persona + role modality, and the `.thoth/` config home.
> Per-version detail is in [CHANGELOG](../../CHANGELOG.md) / [state.md](state.md) — **this file is the road AHEAD
> only**. The **four v1.0 gates below are the remaining blocking work** (AGNOS-dominated); everything else here is
> non-gating.

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

1. **AGNOS lane — BUILD cleared, runtime is gate 2.** The `--agnos` lane compiles a valid
   statically-linked x86_64-AGNOS ELF with zero undefined symbols and zero thoth source change (the last
   build blocker was resolved upstream). The **runtime** half — the ELF targets the AGNOS syscall ABI and
   can't be exercised on a Linux host — is gate 2, below. **Status: build ✓ · runtime → gate 2.**

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

**Satisfied on Linux** (M0–M7 + the full post-M7 arc — see CHANGELOG/state.md) and **AGNOS-buildable**
(gate 1); AGNOS-green pends the gate-2 runtime verification. **Open:**

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

The **chat-surface inheritance** below is a *sequenced* near-term line of feature minors (still non-gating — the
four AGNOS gates keep priority); the rest of this section re-gathers unscheduled.

### Chat-surface inheritance — 0.34.x → 0.3x.x (sequenced)

> **Shipped so far (see CHANGELOG):** **0.32.x — Memory + RAG** (consume mneme: seam + `/remember`, the
> daimon→mneme host wiring, semantic recall, citations, grounding, GUI surfacing, `/notes`) and **0.33.x —
> Chat-management** (named multi-conversation store, commands, persistence, the richer persisted message schema —
> model / citations / tool calls — the GUI conversation sidebar, and cross-conversation `/search`). The remaining
> sequenced arcs are below.

> **Context.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard — is being handed to
> thoth: thoth's TUI + native T3 GUI become the canonical AGNOS-family chat/coding front-end. The rule is the same
> as the rest of the spine — **CONSUME already-built AGNOS domains (mneme, bhava, an audio/voice domain), never
> reinvent them.** thoth already *leads* SY on the coding surface (colored diff cards, the `edit`/`create_file`
> write tools, tool-call cards, mid-session model+persona+role switching, the sovereign line→TUI→GUI ladder); these
> arcs close the *chat-management* and *memory* gaps. Each arc is ONE minor; cuts within it are patches. SY's
> enterprise guardrail stack (t-ron is thoth's answer), multi-platform group-chat bridges, and the web-dashboard
> admin stay **out of scope** (see below).

- **0.33.x chat-management follow-ups (non-gating).** The 0.33.x arc shipped (multi-conversation store → commands →
  persistence → richer message schema → GUI sidebar → cross-conversation `/search`; see CHANGELOG). Two deferred
  polish items ride later work: a **mouse click-to-switch** on the GUI sidebar (today keyboard-only — the GUI has no
  pointer plumbing yet), and **re-rendering resumed tool/citation data as GUI feed cards** (today it round-trips +
  surfaces in `/save`, but the live feed cards are session-local).
- **0.34.x — Message actions + interrupt (the most-felt chat-UX gaps). ✅ COMPLETE (.0–.4 shipped).** `/retry`/`/edit`
  message actions (`.0`); **stop/interrupt** — `.1` through the whole agentic loop in the TUI behind a
  front-end-agnostic **interrupt seam**, `.3` the **GUI stop affordance** (Esc aborts a GUI turn via a Wayland-fd
  stop-poll on the seam); `.2` a bug fix (an empty `inputSchema` on the `mneme_*` tools emptied every full-registry
  agentic turn); `.4` per-message **`/bookmark`** (save a reply into mneme) + **`/thumbs`** feedback
  (→ `mneme_search_feedback`). See CHANGELOG for per-cut detail. **Follow-up carried forward:** surface `/retry` +
  `/edit` (and `/bookmark`/`/thumbs`) as GUI affordances — the GUI composer runs `cmd_task` directly, bypassing
  `dispatch`, so slash-commands are TUI/REPL-only today (rides the 0.35.x GUI work).
  > **Ordering note (fixed):** an earlier draft listed the GUI stop under .1, ahead of any GUI event-loop pump — a
  > mis-ordered dependency (stdin `intr` doesn't reach the GUI, and the blocking turn can't handle a key mid-turn).
  > Corrected: .1 does the TUI/REPL interrupt + the seam; .2 adds the minimal GUI stop-poll pump the seam needs.
- **0.35.x — GUI + agentic streaming (architectural).** The GUI showed only a "working" frame then the final reply,
  and agentic turns are non-streaming; SY streams everything with live thinking + tool pills. **.0 shipped** — the
  GUI present loop now **paints mid-turn** (the 0.34.3 stop-poll grew into the throttled, ready-gated pump; the feed
  renders the growing `_hoosh_acc` partial live). **.1 shipped** — **live tool-call cards** during the round (the
  `gturn_active` feed branch renders the current turn's roundlog cards above the partial; a card grows a row as each
  tool returns, riding the pump). **.2 shipped** — a **reasoning-effort control** (`[hoosh].reasoning`, mapped to the
  provider's native effort by hoosh 2.5.0 — works today on Opus 4.8) **+ a live thinking fold** (both SSE paths parse
  `reasoning_content` into `_reason_acc`; `_gfeed_flow` renders a collapsible muted "thinking" block above the cards,
  Ctrl+R to toggle; inert on Opus 4.8, which keeps reasoning internal). **.3 shipped** — **persistent per-turn
  reasoning**: a `reasonlog` ring (keyed by turn, like `roundlog`/`memlog`) records each turn's final-round
  chain-of-thought at the reply-finalize sites, and `greason_build_turn` renders a LANDED turn's fold above its
  cards — so the fold survives the reply landing (was live-only). **.4 shipped** — a `/state` **reason** row: the
  `[hoosh].reasoning` effort + how many turns' reasoning were folded this session (`reasonlog_total`; 0 on a model
  that keeps reasoning internal). The GUI + agentic-streaming arc's planned scope is DONE. Optional follow-up: persist
  reasoning into the conversation store so a landed fold survives resume (today it is session-scoped like the memory
  strip) — carry into a later resume-focused cut if wanted.
- **0.36.x — Rendering + context polish.** **.0 shipped** — **structural markdown in the GUI** (ATX headings, bold,
  inline + fenced code, lists, blockquotes) via a new shared facts-not-bytes model (`src/mdmodel.cyr`, the reply-render
  analogue of `surface.cyr`); the GUI feed is the first leaf that lowers it, and `mdhl` (line/TUI) is left untouched.
  **.1 shipped** — **pipe tables** in the GUI: the shared model parses rows/delimiter/alignment
  (`md_row_split`/`md_is_delim_row`/`md_cell_align`, surface-agnostic), and the GUI feed leaf lays out an aligned grid
  (`_gfeed_md_table`); line/TUI tables come with the `.2` migration (no bespoke `mdhl` table path). Remaining:
  **.2 shipped** — **one markdown classifier**: `mdhl`'s prose + inline classification now drives from the shared
  model (`md_classify` + `md_inline_scan`), removing the six duplicated predicates; byte-identical for line/TUI (the
  fenced-code path stays bespoke for now). **.3 shipped** — line/TUI **table rendering**: `mdhl` emits an aligned monospace grid via the model's
  parser, riding the 0.18.3 live-card trick (a delimiter under a matching header drops the header's sealed feed row
  and re-emits the table as a grid) — so tables now render on EVERY surface, with the line/`PT_PLAIN` floor keeping
  raw-pipe bytes. **.4 shipped** — **history overflow made honest + optionally summarized**: `/state` now distinguishes the
  framer's harmless skip from the cap's REAL destruction (which was silent), and `[hoosh].summarize` (opt-in) recaps
  the skipped range via a cached, incrementally-folded side-call so long sessions keep fidelity. (The roadmap's
  premise was off: the byte budget bites first and is non-destructive; mneme was rejected — recall keys on the
  prompt, which carries no signal for "keep going with that".) Remaining: **.5** export formats (`/save` gains JSON/plain) + model-picker health/pricing if hoosh
  exposes it.

> **Long-term GUI capability (spine-inherited, not scheduled): voice / mic.** thoth's T3 GUI will grow **voice
> input** (mic → speech-to-text) and **read-back** (text-to-speech) as a first-class thoth capability — but by
> **consuming an AGNOS audio/voice domain**, exactly like mneme/bhava, *never* by hand-rolling STT/TTS. Gated on
> that domain's Cyrius port + a portable audio-capture substrate. Recorded so it isn't lost; not on a numbered arc yet.

### Later / speculative (not scheduled)

- A `grep`/glob project **search tool** — a jailed read-side companion to `read_file` /
  `list_dir` (project awareness, [ADR-0015](../adr/0015-project-read-tools-jailed-default-on.md)).
- A lightweight **project-map hint** in the system prompt, so the agent gets a cheap directory
  overview without a `list_dir` round-trip.
  (Full mneme binding **shipped** in the 0.32.x memory arc — see CHANGELOG.)

### Polish backlog (gathers until it earns a sweep minor)

> Small, independent UX items are parked here as they surface. **Convention:** none
> is scheduled individually; when enough have gathered (or a natural gap opens
> between lines), a **polish minor** sweeps a vetted batch. (The last batches shipped across
> the 0.22.x–0.24.x polish sweeps — see [CHANGELOG](../../CHANGELOG.md). This section
> re-gathers from empty.)

### Deferred / known limitations (captured so they're not lost)

> Not on an active line — each is gated on an external/substrate primitive or is
> low-priority hardening. **None is a correctness bug**; each degrades honestly today.
> Recorded here so it isn't lost in code comments.

- **`rainbow` theme** — a per-grapheme HSV render mode (a render mode, not a role table);
  needs the **anuenue** lib vendored. Announced not-yet-available, never faked.

- **bhava — the sentiment→mood loop (a backlogged seam, gated on bhava's Cyrius port).** SecureYeoman feeds a
  turn's response sentiment back into the active persona's mood; that loop is **bhava**'s domain. Already a
  backlogged thoth integration — **consume bhava** (the same pattern mneme just cleared) once it is Cyrius-ported;
  never reimplement sentiment/mood analysis in thoth. Not on a numbered arc until bhava lands.

- **Input-history file hardening (0.11.2 follow-ups).** The opt-in `[history].file` is
  best-effort-secured today (a fresh file is created `0600` on POSIX; degrade-closed —
  an unwritable path / mid-session write failure is announced). The residuals below are
  documented honestly in `.thoth/config.cyml.example` + `src/inhist.cyr` and wait on portable
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
