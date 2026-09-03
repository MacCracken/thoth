# thoth — Roadmap

> **Forward-facing only.** This file is the road *ahead*: the blocking gates to v1.0,
> the work that is scheduled against a version, and the known limitations thoth carries
> but has not yet fixed. Nothing that has shipped is narrated here.
>
> - **Shipped history** → [`../../CHANGELOG.md`](../../CHANGELOG.md)
> - **Live state snapshot** (version, surface area, consumers, dep gaps) → [`state.md`](state.md)
> - **Gaps that are NOT on this roadmap** → [`gap-review.md`](gap-review.md)
>
> **This file supersedes the gap review.** Anything scheduled or declared here is thoth's
> plan and is deliberately absent from `gap-review.md`, which carries only the candidate
> gaps that have *not* been committed to. If an item appears in both, this one wins.
>
> **Where we are:** see [`state.md`](state.md) for the version and what is in it. M0–M7 and
> the whole post-M7 feature arc have shipped; the four v1.0 gates below are the remaining
> blocking work, and everything else in this file is non-gating.

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

v1.0 is an **AGNOS gate**: the downstream-green criterion is satisfied **on AGNOS**, where
the whole spine is native. Everything thoth owns is shipping; the remaining v1.0 work is
dominated by AGNOS lighting up plus two process gates — **not** by presentation or
data-producer polish.

Four gates remain, in rough dependency order.

1. **AGNOS lane — BUILD cleared, runtime is gate 2.** The `--agnos` lane compiles a valid
   statically-linked x86_64-AGNOS ELF with **no unresolved symbol on any reachable path**, and
   zero thoth source change. The **runtime** half — the ELF targets the AGNOS syscall ABI and
   cannot be exercised on a Linux host — is gate 2. **Status: build ✓ · runtime → gate 2.**

   ⚠ Read the lane's output correctly before calling a regression: it prints three
   `undefined function` warnings (`load_signing_seed`, `sign_commit_body`,
   `verify_commit_body`) and two `duplicate fn` warnings (`chacha20_xor`, `cmd_reset`).
   The three sign symbols are **dead-path placeholders from the vendored sit read bundle**,
   documented as such in `scripts/sync-sit.sh`; they arrived when sit was first vendored at
   0.13.x, *after* this gate's build half cleared at 0.12.3. They are expected output, not a
   gate failure. Clearing them is the vendor-carve item below.

2. **At least one downstream consumer green on AGNOS (external verification gate).** The
   nearest advanceable gate: gate 1's build half is done, so this is unblocked to start. It
   needs a real AGNOS runner to exercise the `build/thoth_agnos` ELF with the spine native and
   a consumer green end to end. **Status: blocking · owner: external · needs an AGNOS host.**

3. **Security review pass (process gate) — RE-PINNED to its actual residual.** Two of this
   gate's three named areas were swept by the 0.39.0 P(-1) audit
   ([`../audit/2026-08-24-audit.md`](../audit/2026-08-24-audit.md) — six parallel auditors,
   each finding handed to an independent skeptic, 26 filed / 17 confirmed / 11 fixed, closing
   with a coverage table against the first-party standards checklist): the **fail-closed
   posture** and the **t-ron authorization choke point** are both covered there.

   ⭐ **0.44.3 CLOSED THE CONCURRENCY HALF.** The 0.44.3 sweep ran a dedicated concurrency dimension
   over `_agent_run_calls_par` and every seam it touches, and it was worth doing — four confirmed
   findings, all on the DEFAULT path (`[hoosh].parallel` is on):
   - **the 0.44.2 socket deadline was never threaded through `daimon_fetch_into`**, so a silent MCP
     host parked a worker thread forever with the main thread blocked behind it in `thread_join` and
     Esc unpolled — the identical unkillable hang 0.44.2 was written to fix, on the path it did not
     read;
   - **the tool NAME was gated in full and executed truncated** (the arguments already had exactly
     this protection);
   - **results over 128 KB were lost** and reported as "(tool returned no result)";
   - **the 0.44.1 wrong-tree correction was serial-only.**

   All four are fixed and the executor's slot allocations are now OOM-checked. This is the second
   time the parallel path has been found missing something the serial path had (0.43.1: the blocking
   `pre_tool` hook), which is the pattern worth naming: **the default path is the one that gets read
   least.**

   What remains of this gate is the external sign-off half — whatever "pass" is taken to mean by
   someone who is not the author. **Status: blocking · owner: TBD · the concurrency review is done;
   the sign-off is not.**

   ⚠ The 0.43.0 doc sweep is a live argument for this gate. Reading the parallel executor closely
   enough to document it surfaced that `hooks_pre_tool` and the tool events existed **only** in the
   serial executor — so with `[hoosh].parallel` on by DEFAULT, any round of two or more daimon tools
   silently skipped the operator's blocking deny. Fixed in 0.43.1, but it had been true since hooks
   shipped, and it is exactly the class of thing a concurrency review is for: the parallel path is
   the one that gets read least and defaults on.

4. **1.0 versioning scheme decided (deferred ADR).** thoth stays SemVer `0.x` through pre-1.0
   by design ([ADR-0004](../adr/0004-semver-pre-release.md)). Whether 1.0 adopts CalVer (the
   binary standard) or stays SemVer is deferred to a later ADR. **Status: deferred · owner:
   thoth · decide before the 1.0 tag.**

### v1.0 criteria checklist

**Satisfied on Linux** and **AGNOS-buildable** (gate 1); AGNOS-green pends gate 2. **Open:**

- [ ] **At least one downstream consumer green on AGNOS** — gate 2 (external)
- [ ] **Security review pass** — gate 3 (the concurrency model was reviewed at 0.44.3; **only the
      external sign-off remains**)
- [ ] **1.0 versioning scheme decided (SemVer vs CalVer)** — gate 4
      (deferred ADR; see [ADR-0004](../adr/0004-semver-pre-release.md))

## Versioning

thoth uses **SemVer `0.x`** through its pre-1.0 phase — see
[ADR-0004](../adr/0004-semver-pre-release.md). This supersedes the earlier "CalVer at first
release" plan: a `0.x` number honestly signals that the surface is still moving. The 1.0
scheme is gate 4 above.

**Arc discipline:** a feature **arc** is ONE minor; the incremental cuts inside it are
**patches** (`X.Y.0` → `X.Y.1` → …). A new minor is for a genuinely new capability arc. When
unsure, patch.

## Scheduled work

> The only items here are ones with a version pin and a decision behind them. Everything else that has
> been *identified* but not committed lives in [`gap-review.md`](gap-review.md).

*Nothing is currently version-pinned.* The two items that were pinned to 0.43.0 — subagent delegation and
consuming MCP resources/prompts — **shipped in 0.43.0**; see the [CHANGELOG](../../CHANGELOG.md) and
[ADR-0018](../adr/0018-subagent-delegation-scoped-child-context.md). The next pinned item lands here when
one is decided.

## Remaining work (non-gating, no version pin)

> **None of this blocks v1.0** — the four gates take priority. Data fields follow
> **omit-until-present** ([ADR-0010](../adr/0010-data-producer-honest-omit.md)): a field
> surfaces only when its producer has real data, and announces absence in `/state` — never
> faked.

### Carried-forward chat-surface items

> **Context.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard —
> is being handed to thoth: thoth's TUI + native T3 GUI become the canonical AGNOS-family
> chat/coding front-end. The rule is the same as the rest of the spine — **CONSUME already-built
> AGNOS domains (mneme, bhava, an audio/voice domain), never reinvent them.** SY's enterprise
> guardrail stack (t-ron is thoth's answer), multi-platform group-chat bridges, and the
> web-dashboard admin stay **out of scope**.

- **GUI slash-command affordances** — surface `/retry`, `/edit`, `/bookmark`, `/thumbs` in the
  GUI. The GUI composer runs `cmd_task` directly, bypassing `dispatch`, so these are TUI/REPL-only
  today; needs the GUI to route slash-commands.

  ⚠ **0.44.3 raised the value of this item.** The GUI's authorization modal deliberately does NOT
  offer the "allow for the whole session" answer the terminal prompt does, because the two things
  that make a session grant safe — seeing that it is still acting, and revoking it — both live behind
  `/grants`, which the GUI cannot reach. Routing slash-commands is what lets that option come back.
- **GUI pointer plumbing** — mouse click-to-switch on the conversation sidebar (keyboard-only
  today), and re-rendering a resumed conversation's tool/citation data as live GUI feed cards
  (today it round-trips and shows in `/save`, but the live cards are session-local). Both gated
  on GUI pointer/event plumbing.
- **Reasoning across resume** — persist a turn's reasoning fold into the conversation store so it
  survives a restart (today the `reasonlog` is session-scoped, like the memory strip).
- **A lightweight project-map hint** in the system prompt, so the agent gets a cheap directory
  overview without a `list_dir` round-trip.
- **Model-picker health/pricing** — annotate the `Ctrl-P` picker with per-model reachability and
  pricing.

  ⚠ **Re-scoped: half of this is buildable today.** The old note said "*if* hoosh ever exposes
  it", which is no longer true. hoosh 2.6.4 already serves `GET /v1/health/providers` (provider,
  base_url, status, enabled, healthy per route), carries a pricing table, and serves
  `/v1/cost/estimate` + `/v1/costs`. **Reachability can be annotated now** by joining the
  catalog's `owned_by` against `/v1/health/providers`. What is still missing is per-MODEL data on
  the endpoint the picker actually reads: `/v1/models/catalog` emits only `{id, owned_by}`. So
  only per-model *pricing* waits on hoosh — and on a `/v1/cost/estimate` round-trip as the
  alternative.

- **Vendor-carve cleanup** — tighten the **sit** `[lib.read]` carve (this is what drops the
  `cmd_reset` collision and the three `undefined function` warnings gate 1 documents) and adopt a
  **bote** `[lib.jsonx]` micro-profile (233 fns → 7). Both are upstream-profile + `sync-*.sh`
  re-vendor work, and neither profile exists upstream yet.

  **This is warning hygiene, not headroom.** Re-measured at **0.43.2** with `CYRIUS_STATS=1` (re-run,
  not re-read — the house rule in [`../doc-health.md`](../doc-health.md)): `fn_table` **8522/32768
  (26 %)**, identifiers **271744/524288 (52 %)**, `var_table` **4942/8192 (60 %)** — the tightest of the
  three. The static-data warning reads **1,002,408 bytes (~1.0 MB)**; it is vendored sigil and unfixable
  from thoth. `CYRIUS_DCE` does not help.

  ⚠ **The real ceiling is elsewhere: cyrius's fixed 8 MB `preprocess_out` arena slot**, a hard error with
  no flag and no manifest key. Filed upstream as
  `cyrius/docs/development/issues/2026-08-24-preprocess-out-8mb-ceiling.md`.

  **Read the number correctly.** 0.43.0 published "over the limit by 5,370 bytes" and that was a
  **misread, retracted at 0.43.1**: the compiler reports the size at which expansion *aborted*, not a
  total, so a larger probe file yields a larger number for the same tree. Headroom is measured by summing
  the include graph. Re-summed at **0.43.2**: `src/main.cyr` **≈4.79 MB** and `tests/thoth_core.tcyr`
  **≈4.94 MB** of project sources, against a `lib/` snapshot of ≈7.34 MB from which each unit pulls only
  its declared subset. So the binding unit sits in the **low-to-mid 60 % range** of the 8 MB slot, not the
  ~96 % the pre-retraction figure implied.

  That is real headroom, and it changes the *urgency* without changing the *direction*: the slot is fixed,
  the trajectory is one way, and 0.43.0 did hit it — cleared by dropping the GUI block that unit never
  tested (131 KB), not by shrinking the feature. Lean `[lib.X]` profiles are the shipped workaround
  (kavach `[lib.confine]`, agnosai `[lib.guard]`, sit `[lib.read]`, sankoch `[lib.zlib]`) and they buy
  features, not trajectory. The sit carve below remains the largest single win available thoth-side, but
  it is **no longer the most likely thing to block the next feature** — that claim was derived from the
  retracted number and is withdrawn with it.

> **Long-term GUI capability (spine-inherited, not scheduled): voice / mic.** thoth's T3 GUI will
> grow **voice input** (mic → speech-to-text) and **read-back** (text-to-speech) — but by
> **consuming an AGNOS audio/voice domain**, exactly like mneme/bhava, *never* by hand-rolling
> STT/TTS. Gated on that domain's Cyrius port + a portable audio-capture substrate. Recorded so
> it isn't lost; not on a numbered arc.

### Polish backlog (gathers until it earns a sweep minor)

> Small, independent UX items are parked here as they surface. **Convention:** none is scheduled
> individually; when enough have gathered, a **polish minor** sweeps a vetted batch. This section
> re-gathers from empty after each sweep.

- **`rainbow` polish.** All three tiers cycle per grapheme and are reachable. Remaining:
  - **Semantic roles inside the feed.** The painter tints every glyph in the ring, so chrome
    routed *into* the feed (the t-ron DENY line, the `/reprobe` health notice) cycles instead of
    staying red/green — once both are role markers the painter cannot tell a notice from prose.
    Exempting semantic roles at marker-expansion would fix it. Directly-painted chrome (status
    bar, tree, prompts) is already unaffected.
  - **A diagonal / animated phase** — the hue is a pure function of COLUMN, so every row shares
    one gradient; a per-row offset would give the classic lolcat diagonal, but must stay
    deterministic or `feed_repaint` shimmers.
  - **The GUI's on-compositor re-confirm** — headless pixel tests cover the rasterizer.
  - **Fenced code at the line tier** stays syntax-highlighted (the TUI painter tints it) — an
    asymmetry to settle either way.

## Known limitations (carried, not fixed)

> Each is either a real defect thoth has not yet fixed, or an honest degradation gated on an
> external/substrate primitive. Recorded here so they are not lost in code comments. **The first
> two are defects, not degradations, and are labelled as such.**

- **macOS builds and runs again — with a NEW floor gap behind it.** The lane's blocker was thoth's own
  (`src/tui.cyr` calling darshana's Linux-gated termios/signalfd half with no target guard), closed at
  0.44.3 by `src/term.cyr`. Verified natively on Apple Silicon (macOS 26.6.2): the Mach-O arm64 binary
  compiles with no undefined symbol and `thoth --version` / the line REPL run. ⚠ The toolchain there is
  **6.5.35**, not the pinned 6.5.43 — that version is not installed on the Mac and there is no package
  registry to install it from; the two `lib/` snapshots differ by **zero** removed, renamed or
  newly-private symbols (symbol-diffed both directions), so the lane's result is not toolchain-dependent,
  but a native 6.5.43 build there is still owed.

  ⛔ **What the unblocked lane exposed: `getenv` always returns 0 on macOS.** `lib/io.cyr`'s `getenv`
  reads `/proc/self/environ`, which Darwin does not have, and has a branch for AGNOS but none for macOS
  (Windows is served by the `GetEnvironmentVariableA` reroute). Measured on the Mac: `TERM` and `HOME`
  both come back null in a process where both are set. Consequences, both honest degradations rather
  than failures: **no colour** (`_ui_color_capable` needs `TERM`, so every macOS session resolves to
  PT_PLAIN — `NO_COLOR` is equally inert), and **no global config layer** (`~/.thoth/config.cyml` is
  found via `HOME`, so on macOS only the local layer exists). This is a cyrius floor gap, not thoth's to
  patch — porting the floor means fixing it where the floor lives. Filed upstream at
  `cyrius/docs/development/issues/2026-09-03-macos-getenv-always-null-no-proc.md` with a reproduction
  and two suggested implementations.

  ⚠ **The T2 TUI does not run on macOS and is not meant to yet.** `term_raw` returns -1 there (darshana
  has no BSD termios peer and 0.44.3 does not invent one — a stub pretending to work is worse than an
  honest refusal), so thoth takes the line tier, which is the already-coded degradation. A real BSD
  termios peer belongs to darshana v2; when it ships, `src/term.cyr`'s macOS branch collapses into the
  forwarder branch and nothing above it changes.

- **The Windows lane is now blocked purely outside thoth's authored source.** 0.44.3 took its reachable
  undefined functions from **11 to 1** and removed `TTY_SIGMASK_WINCH`, `EPOLL_CTL_ADD` and `EPOLLIN`
  from thoth's own code entirely. What is left is three upstream classes, and `scripts/build.sh` now
  names them separately instead of letting one mask the others:
  - **architectural** — `SYS_SOCKET` / `SYS_CONNECT` (ws2_32) and the epoll set (IOCP). Permanent by
    design; the lane gates closed, announced.
  - **vendored** (`VENDOR_GAP`, new at 0.44.3) — `SIGHUP` / `SIG_BLOCK` from `src/vendor/t-ron.cyr`'s
    SIGHUP-driven policy hot-reload, which thoth has **zero** callers of, and `sys_rmdir` from
    `src/vendor/sit-read.cyr` against a Windows floor that routes `DeleteFileW` and `MoveFileExW` but
    not `RemoveDirectoryW`. Upstream fixes: t-ron gating its signal half to Linux (or publishing a
    profile without it), and cyrius adding `sys_rmdir` to the Windows peer.
  - `TTY_SIGMASK_WINCH` stays off **every** list on purpose, so a new raw `tty_*` call in thoth source
    turns this lane red again — it is the regression tripwire for the defect just closed.

  ⚠ **The lane classifier itself was half-blind and is fixed.** It only ever collected `undefined
  variable`, never `undefined function` — the error cyrius actually refuses to emit on — so through
  0.44.2 eleven reachable undefined functions hid behind two undefined variables. It now collects both,
  reading the reachable set from the list cyrius prints AFTER its "N unreachable fns" note (the earlier
  bare list is mostly dead references; matching it instead reported the three documented sit dead-path
  placeholders as blockers, which have never blocked any lane).

- ⛔ **sit's git read-mode status reports false positives** (upstream, sit — thoth is a pure
  consumer). Every tracked mode-`100755` file and every tracked zero-byte file comes back
  "modified" regardless of content. **Re-reproduced at 0.43.0, and starker than the original
  report:** on a tree `git status` calls **completely clean (0 changed)**, `/git` reports **14
  changed** — 13 mode-`100755` `scripts/*.sh` (as `A`) plus the zero-byte `docs/examples/.gitkeep`
  (as `M`). Fourteen pure false positives isolating exactly the two predicted classes, with no true
  positives to muddy the signal. Reproduced on sit **1.3.5** and **1.6.2**, so the 0.38.6 bump
  neither caused nor fixed it. `src/git.cyr`'s `git_probe` copies sit's `{path, kind}` vec and compares nothing, so
  the fix belongs in sit's comparator; it inflates `/git`, `/state`'s changed-file count and the
  file-tree badges. Note sit's CLI cannot reproduce it — `sit status` handles only `.sit/` repos;
  git read-mode is a library-only surface.

- **thoth asks hoosh for streaming token usage that hoosh never sends.** Every streaming request
  carries `stream_options.include_usage`, but hoosh **2.6.4**'s source contains no reference to either
  token and emits no trailing usage frame, so `_hoosh_account_usage` waits for something that never
  arrives on the streaming path. Either hoosh grows the frame or thoth stops claiming the field
  feeds its cost producer. Degrades quietly today rather than honestly — the token/cost row simply
  is not fed on that path.

- ⛔ **hoosh drops SSE frames on the Anthropic streaming path, and launders provider errors into an
  empty 200 stream** (upstream, hoosh 2.6.4 — surfaced and captured off the wire at 0.44.2). Two
  distinct defects in `_remote_stream_cb` / `handle_chat_stream` (`src/lib/handlers.cyr`):
  1. `_emit_anthropic_tool_delta` silently `return 0`s when it cannot pull `id`+`name` out of a
     `content_block_start`, so a tool call's OPENING frame can be dropped while its
     `input_json_delta` fragments are still forwarded — the client receives arguments belonging to
     a call with no name and no id. Observed intermittently; the same shape also loses a fragment
     mid-`arguments`, producing a call whose JSON is cut. thoth 0.44.2 now drops and announces such
     a call instead of letting it poison the conversation, but the frames are still lost.
  2. When the provider returns a permanent 4xx, hoosh logs `provider: permanent error, not retrying`
     to its **own** log, discards the provider's error body, and sends the client a well-formed
     HTTP 200 SSE stream containing one `finish_reason:"stop"` frame and nothing else. An error
     laundered into a silent success. thoth 0.44.2 reports an all-empty 200 stream as a gateway
     fault rather than a model failure, but cannot say WHY — only hoosh knows.
  Reproduced deterministically by replaying one captured request body; not fixable from thoth.

- **t-ron's audit export is unescaped and flat-sized** (upstream, t-ron — surfaced by 0.42.0's
  `/audit export`). `_audit_export_event` splices `reason` into JSON with no escaping, and sizes
  the whole buffer at a flat 512 bytes/event against a reason whose length it does not bound. Both
  are safe **today** only because every reason t-ron emits is a short fixed label. A reason
  carrying a quote, backslash or control byte would make thoth's export invalid JSON; a long one
  would overrun the buffer. Not fixable from thoth without re-deriving the serializer.

- **bhava — the sentiment→mood loop** (a backlogged seam, gated on bhava's Cyrius port).
  SecureYeoman feeds a turn's response sentiment back into the active persona's mood; that loop is
  **bhava**'s domain. Already a backlogged thoth integration — **consume bhava** (the same pattern
  mneme cleared) once it is Cyrius-ported; never reimplement sentiment/mood analysis in thoth. Not
  on a numbered arc until bhava lands.

- **Hook event facts sit in the child's argv.** `[hooks]` passes event facts (`THOTH_EVENT`,
  `THOTH_TOOL`, `THOTH_ARGS`) as quoted `VAR='...'` assignments prefixed to the `/bin/sh -c` string.
  The quoting is correct — no tool argument can close it and append a command — but the assignments
  are part of the child's **argv**, so on Linux up to ~16 KB of the model's tool arguments are
  readable through `/proc/<pid>/cmdline` for the life of the hook. `src/hooks.cyr` used to claim event
  facts were "never interpolated into the command", which was true about injection and wrong about
  exposure; corrected in the source at 0.44.3. Closing it needs a portable spawn-with-environment
  primitive `src/exec.cyr` does not have (the floor's `execve` shapes differ per target). Not a new
  risk class — a hook is already an unsandboxed command the operator chose — but a real one.

- **Input-history file hardening.** The opt-in `[history].file` is best-effort-secured today (a
  fresh file is created `0600` on POSIX; degrade-closed — an unwritable path or mid-session write
  failure is announced). The residuals are documented in `.thoth/config.cyml.example` +
  `src/inhist.cyr` and wait on portable substrate primitives:
  - **tighten a pre-existing / loosely-permissioned file to `0600`** — needs a portable
    `chmod`/`fchmod` wrapper. Today `sys_chmod` is **absent on Windows** and a **frozen-ABI no-op
    on AGNOS**, so calling it would fork the floor / break the `--win` lane; a fresh file gets
    `0600` on create but an existing looser file is left as-is (never silently re-tighten, never
    assert a mode we cannot enforce). Lands if `lib/io.cyr` grows a portable file-mode wrapper.
  - **`O_NOFOLLOW` on the history-file open** — needs a portable no-follow bit (the AGNOS `AO_*`
    open bridge defines none). Defense-in-depth against a symlink redirect on a secret-bearing
    file; until then it is documented "keep it in an owner-only directory."
  - **`~`/`$HOME` path expansion + a `histfilesize`-style trim** — the path is used verbatim (no
    shell `~` expansion) and the file is bounded to the recall ring (128 lines). Minor polish.

- **AGNOS substrate gap — `sys_open` carries no create-mode channel.** The agnos open bridge
  (`lib/io.cyr`, against the frozen 0-33 ABI) maps `O_*`→`AO_*` but has no permission-mode
  argument, so a file created on AGNOS lands at the kernel default, not `0600`. A documented floor
  gap (same class as the SIGHUP one); a **candidate to file against the agnos peer** if/when the
  ABI gains a mode channel. thoth already degrades honestly (never asserts a mode it cannot
  enforce). **Not a v1.0 blocker.**

## Out of scope (for v1.0)

The deliberate non-goals — these keep future contributors from forking the spine or diluting the
identity by accident.

- **Any OS-specific reimplementation, bundling, or substitute** for a domain AGNOS already owns —
  inference (hoosh), MCP protocol (bote), MCP security (t-ron), orchestration / tool host
  (daimon), or archetype (avatara). No "offline" / "embedded" forks that dodge the spine.
- **A bundled local inference path** to escape hoosh, a **hand-rolled MCP client** to escape bote,
  or an **ad-hoc auth shim** to escape t-ron. These are the precise failure modes the identity ADR
  exists to prevent.
- **A swappable-backend abstraction** that lets the spine be replaced with arbitrary alternative
  implementations — the capability seam binds to the **same contract** (native vs.
  reached-as-client), not to competing backends. thoth drives the AGNOS spine; it does not abstract
  it away.
- **Off-AGNOS feature parity.** Parity is an AGNOS-only promise; elsewhere thoth runs a faithful,
  capability-gated baseline.
- **Silent degradation** of any capability, especially security. Missing capabilities fail closed
  and are announced — never faked.
- **A separate per-OS agent UX or "AGNOS edition" fork.** One driver, one UX, many substrates.
- **Declaring a spine crate as a dep before its seam milestone wires it.** Each seam binds in its
  own milestone, not speculatively ahead of design: daimon / bote / t-ron land in M4, avatara in
  M5. (hoosh, wired in M3, is the exception that proves the rule — it is consumed as a *running
  HTTP gateway*, not a linked crate, so it never becomes a `cyrius.cyml` git-dep; the stdlib
  `sandhi` transport is what M3 declared.) The **off-AGNOS reach transport** — the
  native-vs-remote binding distinction — is deferred to a later ADR once that work is real.
