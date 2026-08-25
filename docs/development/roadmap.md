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

   What remains is genuinely untouched — an independent review of the **parallel-tool-execution
   concurrency model** (the audit's six dimensions did not include concurrency; the last pass
   over the parallel executor was 0.7.0), plus whatever external sign-off "pass" is taken to
   mean. **Status: blocking · owner: TBD · scope narrowed, not yet scheduled.**

4. **1.0 versioning scheme decided (deferred ADR).** thoth stays SemVer `0.x` through pre-1.0
   by design ([ADR-0004](../adr/0004-semver-pre-release.md)). Whether 1.0 adopts CalVer (the
   binary standard) or stays SemVer is deferred to a later ADR. **Status: deferred · owner:
   thoth · decide before the 1.0 tag.**

### v1.0 criteria checklist

**Satisfied on Linux** and **AGNOS-buildable** (gate 1); AGNOS-green pends gate 2. **Open:**

- [ ] **At least one downstream consumer green on AGNOS** — gate 2 (external)
- [ ] **Security review pass** — gate 3 (narrowed to the concurrency model + sign-off)
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
  it", which is no longer true. hoosh 2.6.3 already serves `GET /v1/health/providers` (provider,
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

  **This is warning hygiene, not headroom.** Measured at **0.42.0** with `CYRIUS_STATS=1`:
  `fn_table` **8467/32768 (26 %)**, identifiers **269459/524288 (51 %)**, `var_table`
  **4856/8192 (59 %)** — the tightest of the three. The static-data warning reads **1,001,720
  bytes (~1.0 MB)**; it is vendored sigil and unfixable from thoth. `CYRIUS_DCE` does not help.

  ⚠ **The real ceiling is elsewhere, and at 0.43.0 it BIT.** The binding constraint is cyrius's fixed
  **8 MB `preprocess_out`** arena slot. Adding 0.43.0's two features pushed `tests/thoth_core.tcyr` to
  **8,393,978 bytes — over the limit by 5,370** — a hard error with no flag or manifest key, which is
  precisely what the issue filed at 0.42.0 predicted would happen to "the next feature that needs a spine
  capability". It was cleared by dropping the GUI block that unit never tested (131 KB), not by shrinking
  the feature, so the headroom bought is one-off and the trajectory is unchanged. Filed upstream as
  `cyrius/docs/development/issues/2026-08-24-preprocess-out-8mb-ceiling.md`. Lean `[lib.X]` profiles are
  the shipped workaround (kavach `[lib.confine]`, agnosai `[lib.guard]`, sit `[lib.read]`, sankoch
  `[lib.zlib]`) and they buy features, not trajectory. **This is now the most likely thing to block the
  next feature**, and the sit carve below is the largest single win available thoth-side.

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
  - **A persistent `[ui].theme` config key** — the theme is per-session only; there is no way to
    start in a chosen theme, on any tier.
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

- ⛔ **The macOS build lane is BROKEN, and it is thoth's bug.** Not a degradation — the compile
  fails. `src/tui.cyr:1853` / `:1906` reference `TTY_SIGMASK_WINCH` and the file calls six `tty_*`
  functions (`tty_isatty`, `tty_winsize`, `tty_cooked`, `tty_raw`, `tty_open_signalfd`,
  `tty_close_signalfd`) with **no macOS guard** — but darshana gates its entire termios/winsize/
  signalfd half to `#ifdef CYRIUS_TARGET_LINUX`, because BSD termios is a different struct and is
  explicitly out of scope for darshana v1.0. So the T2 TUI cannot link off Linux. Re-tested at
  0.38.6 on real Apple Silicon with cyrius 6.5.35: a pristine `HEAD` baseline fails identically,
  so this is long-standing (last known-good lane was **0.6.4**), not a dep-refresh regression.
  **The fix is thoth-side and needs no dep bump**: gate the T2 TUI off non-Linux and fall back to
  the line tier — the same degradation already coded for AGNOS in `tui_events_init`. darshana's
  ANSI/cursor half is portable and unaffected. Sizing it properly means checking whether the GUI
  tier has the same exposure.

- ⛔ **sit's git read-mode status reports false positives** (upstream, sit — thoth is a pure
  consumer). Every tracked mode-`100755` file and every tracked zero-byte file comes back
  "modified" regardless of content: in this repo `/git` listed **63** files where `git status`
  listed **58**, the five extras being four unmodified `scripts/*.sh` and `docs/examples/.gitkeep`.
  Reproduced identically on sit **1.3.5** and **1.6.2**, so the 0.38.6 bump neither caused nor
  fixed it. `src/git.cyr`'s `git_probe` copies sit's `{path, kind}` vec and compares nothing, so
  the fix belongs in sit's comparator; it inflates `/git`, `/state`'s changed-file count and the
  file-tree badges. Note sit's CLI cannot reproduce it — `sit status` handles only `.sit/` repos;
  git read-mode is a library-only surface.

- **thoth asks hoosh for streaming token usage that hoosh never sends.** Every streaming request
  carries `stream_options.include_usage`, but hoosh 2.6.3's source contains no reference to either
  token and emits no trailing usage frame, so `_hoosh_account_usage` waits for something that never
  arrives on the streaming path. Either hoosh grows the frame or thoth stops claiming the field
  feeds its cost producer. Degrades quietly today rather than honestly — the token/cost row simply
  is not fed on that path.

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
