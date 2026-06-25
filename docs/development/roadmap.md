# thoth — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.
>
> **Forward-facing only — what's left to v1.0.** Shipped history lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md) and the version log in
> [`state.md`](state.md); this file is just the road ahead.
>
> **Where we are:** **M0–M5 are done** — driver core, the hoosh seam (inference
> + mid-session model switch), the M4 tool spine (daimon remote; bote + t-ron
> native; one fail-closed authorization choke point), and the M5 avatara overlay
> are all live, so **all five spine seams are wired**, with the model-driven
> agentic tool-calling loop (0.6.0) running on top. **M6 is in progress** —
> multi-target builds began with the Linux target shipping (0.6.3), and **aarch64
> Linux joined as a building lane in 0.6.4** (on the Cyrius 6.2.15 refresh). AGNOS,
> Windows, and macOS remain staged, each gated on a named upstream floor gap. What
> remains below is **provisional**: ordering, version labels, and dep gates may
> still move. Treat the unshipped milestones as direction, not commitment.

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

## v1.0 criteria

_Provisional — to be ratified as the design settles. v1.0 is an **AGNOS
gate**: the downstream-green criterion is satisfied on AGNOS, where the
whole spine is native._

- [ ] Core driver loop (read → plan → edit → run → iterate) usable on
      AGNOS and at least one off-AGNOS target
- [x] Mid-session model switch routes turns through hoosh — M3 (0.2.0)
- [ ] MCP tool execution via daimon + bote, gated by t-ron on AGNOS
- [x] Off-AGNOS security **fails closed** — absent t-ron degrades to a
      conservative built-in deny/prompt, never silent allow; absence is
      announced, never faked — M2 posture, made fully real by M4 (0.3.0):
      wired t-ron denies by default; absent t-ron prompts deny-by-default
- [x] avatara Thoth/Librarian archetype overlay applied — M5 (0.4.0)
- [x] Capability ladder documented and honest (per dependency:
      native vs. remote-client vs. absent; full / degraded / absent
      semantics) — M6 (0.6.5); computed live from `src/seams.cyr`, see
      [architecture note 002](../architecture/002-capability-ladder.md)
- [ ] At least one downstream consumer green **on AGNOS**
- [ ] CHANGELOG complete from the first real release onward
- [ ] Security review pass
- [ ] 1.0 versioning scheme decided (SemVer vs CalVer) — see Versioning below
      and [ADR-0004](../adr/0004-semver-pre-release.md)

## Versioning

thoth uses **SemVer `0.x`** through its pre-1.0 phase — see
[ADR-0004](../adr/0004-semver-pre-release.md). This supersedes the earlier
"CalVer at first release" plan: a `0.x` number honestly signals that the
surface is still moving (commands and the seam interface still change release to
release). Whether thoth adopts CalVer (the binary standard) or stays SemVer at
1.0 is deferred to a later ADR.

## Milestones

> **Shipped (M0–M5, 0.1.0 → 0.4.0, plus the 0.5.x–0.6.x polish line):** the
> scaffold and identity ADRs, the driver core, the hoosh seam, the M4 tool spine,
> and the M5 avatara overlay — then streaming, multi-turn context, structured
> logging, the `/audit` / `/models` views, the model-driven agentic tool-calling
> loop, and per-tool input schemas. Per-release detail is in
> [`../../CHANGELOG.md`](../../CHANGELOG.md) and the version log in
> [`state.md`](state.md). The road ahead:

### M6 — OS-agnostic build targets + capability ladder (in progress)

Ratify the reach posture and make degradation explicit. The build driver
(`scripts/build.sh`) and [ADR-0008](../adr/0008-multi-target-builds.md) landed
with **0.6.3**; the rest is open.

- ✅ **x86_64 Linux** ships as a named target (0.6.3).
- ✅ **aarch64 Linux** builds (0.6.4) — the cycc `#pure`/aarch64 pass-1 scanner fix
  (filed `cyrius/.../2026-06-12-main-aarch64-pass1-missing-annotation-tokens-unexpected-enum`)
  landed upstream in **Cyrius v6.2.2**; the 0.6.4 pin bump picked it up with zero
  thoth change. Cross-built; running on real ARM hardware is a host-side step.
- ◐ **macOS (arm64)** builds + runs natively (verified 0.6.4 on Apple Silicon):
  `./scripts/build.sh macos` → `build/thoth_macos`, REPL launches and exits clean.
  The basic driver path works; the **t-ron audit path is gated upstream** — cycc's
  `var SYS_*` Mach-O reroute miss (issue
  `cyrius/.../2026-06-16-var-syscall-number-defeats-macho-pe-reroute`) means patra's
  `lseek`/`futex` fault at runtime once a `[tron].policy` is set. Closes with that
  cycc fix, zero thoth change.
- ☐ **AGNOS, Windows** — staged in the driver (re-verified at the 6.2.37 floor,
  0.6.6). Two of the symbols the lanes hit are **fixable upstream bugs**, not
  capability gaps:
  - AGNOS's old `SYS_LSEEK` blocker is **RESOLVED** (6.2.37 agnos peer defines
    `SYS_LSEEK=58`/`SYS_GETRANDOM=45`; closes the filed lseek issue). It now gates
    on `SIGHUP` — agnos signal infra is DONE (`sigprocmask`#17/`signalfd`#18); the
    peer just omits the signal-number constants. **Filed**
    (`agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md`).
  - Windows `SYS_GETRANDOM` is **fixed** — Windows has ProcessPrng; the raw-syscall
    call was a patra bug, **fixed in patra v1.12.4**. thoth's lane clears on the
    toolchain re-bundle. The genuine, *architectural* Windows gaps are `SYS_FUTEX`
    (`WaitOnAddress`) + epoll (IOCP).
  Each lights up with zero thoth source change once its gap closes.
- ✅ **Capability-ladder / feature-gate matrix** (0.6.5): per dependency, the
  binding mode (native / remote-client / absent) **and** the orthogonal capability
  effect (**full / degraded / absent**), derived live from the seam status so it
  can't drift — t-ron degrades *closed* (the fail-closed gate), never to absent.
  `/seams` renders both axes; [architecture note 002](../architecture/002-capability-ladder.md)
  records the invariant.
- ☐ Confirm: identical agent UX everywhere; AGNOS is the only parity promise.

### Agentic loop — post-0.6.0 polish

The model-driven tool-calling loop (0.6.0, streaming 0.6.1, per-tool schemas 0.6.3)
gains incremental polish; these are not milestone-gating. **Both are bundled into a
single held 0.7.0 release: the `/audit` work has landed in-tree but 0.7.0 will not be
cut until parallel tool calls also land (gated on the filed sandhi + bayan repairs).**

- ◐ **Tool rounds in `/audit`** (landed in-tree, held for 0.7.0): `/audit` surfaces a
  session-local trace of the loop's tool **rounds** (`src/roundlog.cyr`), grouped by
  turn/round with each call's verdict + ok/err — the loop-structure view alongside
  t-ron's security chain. Done; awaiting the 0.7.0 cut.
- ☐ **Parallel tool calls** (the gate on the 0.7.0 cut) — blocked at the stdlib floor, **filed upstream**, NOT a
  thoth change. A 3-lens adversarial audit confirmed concurrent `daimon_invoke` is
  unsafe: **sandhi** stashes per-request dispatch state in module globals
  (`sandhi/docs/issues/2026-06-23-thoth-http-client-dispatch-globals-not-thread-safe.md`)
  and **bayan**'s JSON value parser uses a process-global cursor
  (`bayan/docs/.../2026-06-23-thoth-json-value-parser-global-cursor-not-thread-safe.md`).
  Once both lift their per-call state out of globals, thoth's piece (a reentrant
  `daimon_invoke_a` + a phased `snapshot → gate → execute → ordered-append`
  `_agent_run_calls` + the sigil `thread_create` fan-out — all designed) drops in
  with zero further restructuring. "Port the floor; never fork the spine."

### M7 — Presentation capability ladder (T0→T2)

> The front-end transformation toward the `Thoth.dc.html` look. Full rationale +
> scope in [ADR-0009](../adr/0009-presentation-capability-ladder.md). Presentation
> is a third capability axis (T0 plain → T1 ANSI → T2 rich-TUI → T3 desktop):
> terminal-first, consume AGNOS libs (never hand-roll the floor), degrade closed,
> `{(o> ` stays the T0 floor.

- **Render surface first** — `src/surface.cyr`: route every `emit`/`println`
  through tier-agnostic semantic intents (T0 renderer = today, byte-identical) +
  startup tier detection (isatty + `TERM`/`COLORTERM`; **mihi** for the GPU/T3
  gate), surfaced in `/seams`.
- **T1 ANSI — the MVP (cheap; no new substrate)** — semantic amber palette
  (truecolor→256→16→none); colored + **vyakarana**-highlighted diffs; a one-line
  status (model/mode/cwd via a getcwd wrapper); `/tree`; **bnrmr+anuenue** banner.
  Rich-by-default on a TTY, auto-`plain` when piped/CI.
- **T2 rich-TUI — `0.9.0` LANDED; vendor darshana** — the interactive alt-screen
  layout: raw-mode composer (line editing + horizontal scroll), slash-command palette,
  a **Ctrl-G-togglable status bar**, scrolling feed, keybinding hints, clean exits
  (Ctrl-X / Ctrl-D / Ctrl-C / /quit). Activates at PT_RICH on a real tty
  (`THOTH_TIER=rich`); the line REPL is the fallback.
- **`0.9.1` — the self-managed feed-redraw model (LANDED)** — the feed left the
  terminal-scroll trick (DECSTBM) for a thoth-owned redraw: dispatch output is captured
  into a line ring (`src/feed.cyr`) via a surface-routed output sink (`src/util.cyr`'s
  `_out_mode`/`emit_raw`/`oprintln`/`ofmt_int`) and painted each frame, with an
  escape-aware clip and the t-ron confirm bracketed back to the live screen. fd-1
  redirection was rejected (AGNOS has no `sys_dup2` → floor-forking; breaks the
  confirm). The floor stays byte-identical (capture armed only inside `dispatch()`).
  This is the prerequisite the next two phases build on.
- **`0.9.2` — instant SIGWINCH resize + the working spinner + incremental streaming
  paint (LANDED)** — the bare blocking key-read became an **epoll multiplex** of stdin +
  a SIGWINCH signalfd (`tty_open_signalfd(TTY_SIGMASK_WINCH)` + `sys_epoll_*`), so a
  resize wakes the idle loop instantly (pure recompute+repaint). `feed_repaint` renders
  the unsealed pending line, and `feed_stream_tick` (pinged from the hoosh/agent SSE
  callbacks) repaints it per chunk so a streamed turn renders as it arrives. The braille
  spinner animates per chunk while streaming, holds still on a blocking turn (honest —
  the loop is blocked inside `dispatch()`), and suspends across the gate confirm. Also
  closed the 0.9.0 SIGINT-signalfd teardown leak.
- **`0.9.3` — the togglable left-column file-tree pane (LANDED)** — a keyboard-navigated
  (no-mouse) inline expand/collapse tree of `$PWD` (`src/ftree.cyr` via `lib/fs.cyr`
  `dir_list`/`is_dir`) as a left column; the feed paints into the narrowed right column
  via the 0.9.1 escape-aware clip. Ctrl-B toggles, Tab focuses, ↑/↓ move, →/← expand/
  collapse, Enter reads a file (keeping tree focus). The pure geometry + flattened-tree
  model are unit-tested; the paint + listing are live-verified. Hidden by default →
  byte-identical floor.
- **`/theme` (0.9.x)** — a theme switch, almost free given the semantic role surface
  (`src/ui.cyr`): a theme is just a different role→color table. `/theme dark` (today's
  amber default) · `/theme light` (the mockup's warm-light palette) · `/theme rainbow`
  (vendor **anuenue** — its HSV grapheme-cycle, same one-file consume pattern as
  vyakarana/darshana — and route the surface through its tinter). The active theme
  shows in the TUI status bar. (The mockup's ⌃T toggle is the dark/light shape.) 🌈
- **Data producers (parallel; honest-omit until present)** — hoosh `usage` →
  tokens; opt-in `[pricing]` → cost; git branch + diff via **sit** (`.sit/` repos
  today). **Real `.git/` repos are GATED on sit's `.git/` read-mode** (filed on
  sit's roadmap) — until it lands, the branch field + real-git diffs omit, never
  fake.
- **T3 desktop — ceiling, off the v1.0 path** — thoth-in-**puka** (puka's own v3
  command center names thoth as its consumer). No webview in the sovereign core.

### M8 — Release readiness (provisional)

- Satisfy the v1.0 criteria above (AGNOS downstream-green gate)
- Security review pass
- CalVer cutover at the first real tag

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
  daimon / bote / t-ron land in M4, avatara in M5. (hoosh, wired in M3, is the
  exception that proves the rule — it is consumed as a *running HTTP gateway*,
  not a linked crate, so it never becomes a `cyrius.cyml` git-dep; the stdlib
  `sandhi` transport is what M3 declared.) The **off-AGNOS reach transport** —
  the native-vs-remote binding distinction — is deferred to a later ADR once
  that work is real.
