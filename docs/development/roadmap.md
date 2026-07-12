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
> **Where we are (0.30.12):** M0–M7 are done and shipping, and the entire post-M7 feature arc
> has landed — the terminal-citizen front door, memory + git producers, the model `shell`
> tool, input completeness, the re-renderable feed, session visibility, shell/agent hardening,
> composer intelligence, the active persona + role modality, project awareness, the model
> picker, and the `.thoth/` config home. **0.27.0** refreshes the toolchain (cyrius 6.4.46 + vendored
> dists) and opens the **simple↔rich consistency line** — parity fixes so features that are *not* rich-TUI
> blockers (`/reprobe`, `/save`, `[history].file`) work at BOTH tiers. **0.28.0** opened Stage B — the
> tier-agnostic **view surface** (`src/surface.cyr`): a facts-not-bytes status view-model that the TUI status
> bar + `/state` now both render from (ADR-0009's semantic layer, realized for the status fields; GUI-ready by
> construction). **0.29.0** started the **T3 GUI** (Phase 1, headless): a draw-command IR + kashi CPU
> rasterizer + a status-strip view-builder over the 0.28.0 view-model (the view-model now drives THREE
> renderers — line / TUI / GUI). **0.30.0** made it RUNNABLE: a sovereign Wayland present shell
> (`src/gui/gwindow.cyr`, vendored+renamed from jalwa's puka-forked client) + a present loop
> (`src/gui/gpresent.cyr`) + a **`thoth gui`** subcommand, now in the SHIPPING binary (cyrius 6.4.49 gave the
> headroom). Degrades honestly with no compositor; LIVE-CONFIRMED on a real one. **0.30.1** added the
> conversation feed (word-wrapped) and **0.30.2** made it interactive (evdev keymap + composer → type, Enter
> runs a turn, the reply renders). **0.30.3** made the feed follow the conversation — a bottom-anchored
> auto-scroll so the newest reply is always visible (older messages clip off the top). **0.30.4** added turn
> feedback — a "thoth is working…" indicator on send (echoing the pending message) plus an honest transient
> notice when a turn doesn't complete (a failed turn pops the user message, and the window renders only
> history, so it would otherwise vanish silently). **0.30.5** added the file-tree pane (`src/gui/gtree.cyr`, a
> view-builder over `ftree_*` + git badges, responsive left column). **0.30.6** refreshed the toolchain
> (cyrius 6.4.49 → 6.4.51, which raised the emitted-binary output cap 16 MiB → 1 GiB on Linux — resolving
> thoth's filed issue) and restored the full file-tree tests the cap had forced lean. **0.30.7** split the
> 4,095-line `tests/thoth.tcyr` into a thin driver + topical `tests/cases/*.cyr` files (one binary,
> behavior-identical). **0.30.8** decoupled the lower layers from the TUI (dependency inversion: `intr_*`
> extracted to `src/intr.cyr`; `util → feed`, `gate → confirm`, `hoosh → mdhl/feed_stream` behind registered
> sinks). **0.30.9** cashed that in: the one-binary test suite became curated per-domain `tests/*.tcyr`
> (`thoth_gui`/`thoth_render` lean, `thoth_core` the full integration bucket). **0.30.10** made the GUI
> file-tree pane interactive — Tab focus + arrow nav + expand/collapse (`gkey`/`gtree_key`/`gfocus`). **0.30.11**
> gave the GUI its signature `{(o>` owl prompt and a throbbing owl-eye status indicator (health-coloured,
> leak-free via a cached frame). Still ahead (0.30.x patches): Enter-on-a-file → `@path` into the composer,
> tool-call cards + colored diffs in the feed (needs a tool-round producer), feed scrollback, composer history.
> thoth as its
> own sovereign Cyrius Wayland app (jalwa-style
> draw-IR → kashi raster → wl_shm → puka-forked present shell, `Thoth.dc.html` as the spec; revises 0009's
> "thoth-in-puka" stance). Per-version detail is in
> [CHANGELOG](../../CHANGELOG.md)/[state.md](state.md). The **four v1.0 gates below are
> unchanged** (AGNOS-dominated); the remaining non-gating work is small — see the
> later/speculative note and the polish backlog.

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

The post-M7 feature arc (0.11.x → 0.30.2, including the T3 desktop GUI) has **shipped in full** — see
[`../../CHANGELOG.md`](../../CHANGELOG.md) for per-version detail and [`state.md`](state.md)
for the current surface. What remains here is non-gating and unscheduled:

### Later / speculative (not scheduled)

- A `grep`/glob project **search tool** — a jailed read-side companion to `read_file` /
  `list_dir` (project awareness, [ADR-0015](../adr/0015-project-read-tools-jailed-default-on.md)).
- A lightweight **project-map hint** in the system prompt, so the agent gets a cheap directory
  overview without a `list_dir` round-trip.
- **Full mneme binding.** When mneme is Cyrius-ported, the memory seam upgrades from the local
  `.thoth/memory` reader (degraded) to semantic recall (full) — omit-until-mneme,
  [ADR-0012](../adr/0012-memory-seam-omit-until-mneme.md).

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

## Off the v1.0 path

- **T3 desktop GUI — SHIPPED (0.29.0 → 0.30.2); off the v1.0 GATE, not future.** thoth
  now runs as its OWN sovereign Cyrius Wayland app (`thoth gui`): a draw-command IR +
  kashi CPU rasterizer + view-builders over the Stage-B view-models + a puka-forked
  Wayland present shell — NOT thoth-in-puka (see the ADR-0009 addendum). It has a status
  strip, a conversation feed, and an interactive composer, and it's in the shipping
  binary. It is off the v1.0 GATE path only because v1.0 is an AGNOS-runtime gate, not a
  presentation-tier gate. No webview in the sovereign core.

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
