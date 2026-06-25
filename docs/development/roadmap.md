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
> **Where we are (0.11.0):** **M0–M7 are done**, the **0.10.x data-producer line is
> complete for the producers thoth owned** (`0.10.2` tokens, `0.10.3` cost), and the
> **0.11.x terminal-citizen line has opened** — `0.11.0` shipped the keystone one-shot /
> argv front-door (`git diff | thoth 'review'`), unlocking the JSON-envelope, `-o` tee,
> and completion riders. The git producer is **externally gated on sit** (not vendored),
> so it lives in its own **0.12.x** minor. The 0.11.x line is the vetted,
> adversarially-reviewed port backlog from the SecureYeoman TUI review (SecureYeoman's TUI
> is being reskinned onto thoth's, so thoth's front-end is the shared canonical surface).
> The driver core,
> the hoosh seam (inference + mid-session model switch), the M4 tool spine (daimon
> remote; bote + t-ron native; one fail-closed authorization choke point), the M5
> avatara overlay, the model-driven agentic tool-calling loop with parallel tool
> execution, the M6 multi-target build ladder, and the M7 presentation ladder
> (T0 plain → T1 ANSI → T2 rich-TUI) have all shipped (0.1.0 → 0.10.3). What's left
> is the **0.11.x composability / TUI-substrate line**, the **0.12.x git producer**
> (sit-gated), and the **four v1.0 gates** below — which are dominated by AGNOS
> lighting up, not by feature work in thoth.

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

- [x] Core driver loop (read → plan → edit → run → iterate) usable on at
      least one off-AGNOS target — **Linux ships**; AGNOS reachable,
      gated on gate 1 above
- [x] Mid-session model switch routes turns through hoosh — M3 (0.2.0)
- [x] MCP tool execution via daimon + bote, gated by t-ron — **works on
      Linux**; AGNOS reachable, gated on gate 1 above
- [x] Off-AGNOS security **fails closed** — absent t-ron degrades to a
      conservative built-in deny/prompt, never silent allow; absence is
      announced, never faked — M2 posture, made fully real by M4 (0.3.0)
- [x] avatara Thoth/Librarian archetype overlay applied — M5 (0.4.0)
- [x] Capability ladder documented and honest (per dependency: native vs.
      remote-client vs. absent; full / degraded / absent semantics) —
      M6 (0.6.5); computed live from `src/seams.cyr`, see
      [architecture note 002](../architecture/002-capability-ladder.md)
- [ ] **At least one downstream consumer green on AGNOS** — gate 2 (external)
- [x] CHANGELOG complete from the first real release onward
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

> **None of this blocks v1.0** — the four v1.0 gates above take priority.
> These are honest-omit data fields plus substrate/UX ports layered onto the
> shipped T1/T2 surface. Data fields follow the **omit-until-present** policy
> ([ADR-0010](../adr/0010-data-producer-honest-omit.md)): a field surfaces only
> when its producer has real data, and announces absence in `/state` — never
> faked. The 0.11.x line is the vetted, adversarially-reviewed port backlog from
> the SecureYeoman TUI review; **every item is a substrate/floor port or a thin
> binding to an existing spine seam — never a spine fork** — because thoth's TUI
> is becoming the shared canonical front-end SecureYeoman reskins onto.

### 0.10.x — data producers (the producers thoth owned) ✅

- **`0.10.2` — tokens. ✅ DONE (2026-06-25).** Extracts hoosh `usage.total_tokens`
  → a `tok <n>` status field that **omits until usage arrives** (status bar + a
  `/state` row). Both paths: the blocking completion's `usage`, and the streaming
  usage frame via `stream_options:{include_usage:true}`. See CHANGELOG / state.md.
- **`0.10.3` — cost. ✅ DONE (2026-06-25).** Opt-in `[pricing.<model>]` rates
  (integer micro-USD per 1K tokens) × hoosh's token usage → a `$d.cc` session
  cost, priced **at accumulate** (each response costed with the model active at
  that moment, so mid-session `/model` switches are correct). Status-bar field +
  `/state` row, **omitted until a priced response** (and a half-declared rate
  degrades to unpriced+noted, never `$0`). See CHANGELOG / state.md.
- The **git** producer was `0.10.4` on this line; because its producer is
  **external** (sit, not vendored) — unlike tokens/cost, which thoth owned — it is
  relocated to its own **`0.12.x`** minor (below) rather than gate the line on sit.
- **`rainbow` theme — deferred.** A per-grapheme HSV render mode (needs
  **anuenue** vendored); announced not-yet-available, never faked. A separate
  effort, not on a data-producer line.

### 0.11.x — terminal citizen + TUI substrate (the SecureYeoman-review backlog)

> Ranked by the 2026-06-25 multi-agent review (each candidate adversarially
> verified against thoth's hard constraints — Cyrius language, consume-the-spine,
> degrade-closed, byte-identical floor). `0.11.0` is the **keystone**: thoth parses
> no argv today, so a one-shot/argv front-door unlocks the JSON-envelope, `-o` tee,
> and shell-completion riders.

- **`0.11.0` — one-shot / argv front-door (keystone). ✅ DONE (2026-06-25).**
  `thoth 'task'`, `git diff | thoth 'review'`, `thoth -p < f`, `thoth --version|--help`
  run ONE turn through the EXISTING `cmd_task → hoosh_send / agent_turn` seam and exit —
  no new spine path. Gated on **explicit argv intent** (NOT `isTTY==false`); stdin slurped
  as the payload; **clean stdout** via an `OUT_NULL` discard sink (chrome suppressed; only
  the reply accumulator printed to fd 1; diagnostics → stderr); **degrade-closed** nonzero
  exit + the t-ron confirm denies in one-shot. New `src/oneshot.cyr`;
  [ADR-0011](../adr/0011-one-shot-argv-front-door.md). See CHANGELOG / state.md.
- **Pure-substrate TUI wins (no argv dependency — ship anytime):**
  - **composer input-history recall** — Up/Down recall submitted lines; persistence
    **OFF by default**, `0600` when enabled; recall gated on palette-closed.
  - **soft-wrap long feed lines** — painter-only reflow instead of today's truncate;
    declare the glyph-width (CJK/emoji) limitation honestly.
  - **`[alias]` prompt macros** — resolve only in the `CMD_UNKNOWN_SLASH` gap,
    expand-then-redispatch, bounded recursion; reuse the bayan parser, no second
    config format.
- **Introspection slot:**
  - **dry-run / request-body preview (`/dry`)** — render thoth's OWN composed
    request buffer and skip the POST; **never** a hoosh `/preview` endpoint (that
    would creep toward forking the inference spine).
  - **JSON-envelope output** — opt-in `{response, model, turns, tokens?, cost?,
    elapsed?}` per turn for jq/CI; rides 0.11.0; mutes the human-progress stdout.
- **Riders / conditional:**
  - **`-o` file tee** — rides 0.11.0 (forces PT_PLAIN for clean bytes; the user's
    own redirection, so NOT t-ron-gated).
  - **live spine-health** — traffic-outcome reachability + Ctrl-R refresh; defer the
    timerfd tick + active probe until idle-drop detection is actually wanted.
  - **clipboard sink** — effort L; needs an upstream cyrius `process` stdin-feed
    primitive (Linux/macOS/Windows). **Architecturally impossible on AGNOS** (frozen
    0-33 ABI: no fork/exec/dup2) → degrades closed there, by ABI, announced.
  - **shell completion** — deferred until 0.11.0's argv command-table exists (an
    argv-scoped script can't complete REPL slash commands; the live palette already does).

### 0.12.x — git producer (omit-until-sit; sit-gated)

- **`0.12.0` — git. Omit-until-sit.** One faint `/state` honesty line
  (`git: absent — gated on sit`). **No faked branch/diff** — real `.git/` reads are
  gated on **sit**'s `.git/` read-mode (sit owns VCS and is not vendored; thoth
  never hand-rolls a `.git/` parser, which would fork sit's domain — ADR-0010).
  Relocated off the 0.10.x line because, unlike tokens/cost, its producer is
  external; it advances when sit ships `.git/` read-mode.

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
