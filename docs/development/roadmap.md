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
> **Where we are (0.11.2):** **M0–M7 are done and shipping** (0.1.0 → 0.11.2; the log
> lives in [CHANGELOG](../../CHANGELOG.md)/[state.md](state.md)). The 0.10.x data-producer
> line is complete for the producers thoth owned (tokens, cost), and the **0.11.x
> terminal-citizen line is advancing** — `0.11.0` shipped its keystone (the one-shot/argv
> front-door), `0.11.1` the first pure-substrate win (composer input-history recall), and
> `0.11.2` its opt-in `[history].file` persistence. **What's left:** the rest of the
> **0.11.x** line (the vetted SecureYeoman-TUI-review backlog — substrate/floor ports and
> thin seam bindings, never a spine fork; that TUI is being reskinned onto thoth's, so
> thoth's front-end is the shared canonical surface), the **0.12.x git producer** (externally
> gated on sit), and the **four v1.0 gates** below — which are dominated by AGNOS lighting
> up, not by feature work in thoth.

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

Four gates remain, in rough dependency order:

1. **AGNOS lane lights up — `SIGHUP` floor gap (filed, upstream; no thoth
   work).** The AGNOS build lane is staged and re-verified; its last
   blocker is the agnos peer omitting the signal-number constants
   (`SIGHUP`). The signal infrastructure is already DONE upstream
   (`sigprocmask`#17 / `signalfd`#18); only the constants are missing.
   Filed: `agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md`.
   The lane clears with **zero thoth source change** once the peer ships
   the constants. **Status: blocking · owner: agnos (upstream) · filed.**

2. **At least one downstream consumer green on AGNOS (external
   verification gate).** Requires gate 1 first (the consumer runs the
   spine natively on AGNOS). **Status: blocking · owner: external · not
   started.**

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
capability ladder (M6), and a complete CHANGELOG. These are AGNOS-reachable, gated on gate 1.

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

## Remaining work — the post-M7 lines (post-release polish; NON-GATING)

> **None of this blocks v1.0** — the four v1.0 gates above take priority. These are
> substrate/UX ports plus honest-omit data fields layered onto the shipped T1/T2 surface.
> Data fields follow the **omit-until-present** policy
> ([ADR-0010](../adr/0010-data-producer-honest-omit.md)): a field surfaces only when its
> producer has real data, and announces absence in `/state` — never faked. The 0.11.x line
> is the vetted, adversarially-reviewed port backlog from the SecureYeoman TUI review;
> **every item is a substrate/floor port or a thin binding to an existing spine seam —
> never a spine fork** — because thoth's TUI is becoming the shared canonical front-end
> SecureYeoman reskins onto.

### 0.11.x — terminal citizen + TUI substrate (the SecureYeoman-review backlog)

> Ranked by the 2026-06-25 multi-agent review (each candidate adversarially verified
> against thoth's hard constraints — Cyrius language, consume-the-spine, degrade-closed,
> byte-identical floor).
>
> **Shipped on this line** (one-line pointers — detail in CHANGELOG/state.md): `0.11.0`
> the one-shot/argv front-door (the keystone — unlocked the JSON-envelope / `-o` tee /
> shell-completion riders below); `0.11.1` composer input-history recall (in-memory);
> `0.11.2` opt-in `[history].file` persistence (its `0600`/`chmod`/`O_NOFOLLOW` follow-ups
> are tracked under **Deferred** below).

**Remaining — pure-substrate TUI wins (no argv dependency — ship anytime):**
- **soft-wrap long feed lines** — painter-only reflow instead of today's truncate;
  declare the glyph-width (CJK/emoji) limitation honestly.
- **`[alias]` prompt macros** — resolve only in the `CMD_UNKNOWN_SLASH` gap,
  expand-then-redispatch, bounded recursion; reuse the bayan parser, no second
  config format.

**Remaining — introspection slot:**
- **dry-run / request-body preview (`/dry`)** — render thoth's OWN composed
  request buffer and skip the POST; **never** a hoosh `/preview` endpoint (that
  would creep toward forking the inference spine).
- **JSON-envelope output** — opt-in `{response, model, turns, tokens?, cost?,
  elapsed?}` per turn for jq/CI; **unblocked by 0.11.0** (the one-shot front-door is the
  clean-stdout seam it rides); mutes the human-progress stdout.

**Remaining — riders / conditional:**
- **`-o` file tee** — **unblocked by 0.11.0** (forces PT_PLAIN for clean bytes; the
  user's own redirection, so NOT t-ron-gated).
- **shell completion** — **unblocked by 0.11.0** (its argv command-table now exists);
  an argv-scoped completion script (the live palette already completes REPL slash
  commands, so this is for the non-interactive front door).
- **live spine-health** — traffic-outcome reachability + Ctrl-R refresh; defer the
  timerfd tick + active probe until idle-drop detection is actually wanted.
- **clipboard sink** — effort L; needs an upstream cyrius `process` stdin-feed
  primitive (Linux/macOS/Windows). **Architecturally impossible on AGNOS** (frozen
  0-33 ABI: no fork/exec/dup2) → degrades closed there, by ABI, announced.

### 0.12.x — git producer (omit-until-sit; sit-gated)

- **`0.12.0` — git. Omit-until-sit.** One faint `/state` honesty line
  (`git: absent — gated on sit`). **No faked branch/diff** — real `.git/` reads are
  gated on **sit**'s `.git/` read-mode (sit owns VCS and is not vendored; thoth
  never hand-rolls a `.git/` parser, which would fork sit's domain — ADR-0010). It is
  its own minor — unlike the tokens/cost producers, its producer is external — and it
  advances when sit ships `.git/` read-mode.

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
