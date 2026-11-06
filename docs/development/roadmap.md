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
> **Where we are:** [`state.md`](state.md) has the version and what is in it. The three open
> v1.0 gates below are the blocking work; everything else here is non-gating.

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
the whole spine is native. Everything thoth owns is shipping; what remains is AGNOS lighting
up plus two process gates. Every release re-runs the ring-3 smoke the gates build on:
`scripts/agnos-run.sh` shells out to AGNOS's own `basestack-run-smoke.sh` and derives the expected
string from `VERSION`, so it cannot pass on a stale binary.

Three gates remain, in dependency order.

1. **At least one downstream consumer green on AGNOS (end-to-end).** Two rungs remain above the
   ring-3 smoke, and both are scheduled as [0.55.x](#055x--a-real-turn-on-agnos):
   - **Rung 2 — a real turn against the spine, staged on the same image.** The rung that satisfies
     the gate's wording. hoosh and daimon both build `--agnos`; what is missing is a runner, because
     the smoke stages one `/bin/probe` and execs `--version`.
   - **Rung 3 — the interactive TUI over agnsh.** Least urgent, and gated on the floor: AGNOS has no
     raw terminal (no termios; every console fd reads the cooked line, which drops every key without
     an ASCII value), so the TUI takes the line REPL there.
   **Status: blocking · owner: thoth.**

2. **Security review pass (process gate) — the external sign-off.** What remains is whatever "pass"
   means to someone who is not the author. Its reading list: the fail-closed posture and the t-ron
   choke point (the internal audits of record are [`../audit/2026-08-24-audit.md`](../audit/2026-08-24-audit.md)
   and [`../audit/2026-11-05-audit.md`](../audit/2026-11-05-audit.md)),
   the parallel executor's concurrency, the GUI's authorization path — the `ask_user` modal answering
   `confirm` and the session grant it can record
   ([ADR-0020](../adr/0020-ask-user-the-tool-that-runs-toward-the-operator.md)) — and the durable
   tool-pin store ([ADR-0022](../adr/0022-tool-pins-are-durable-defended-without-a-secret.md)). It closes
   the 0.x line, after the last arc, so the reviewer reads what ships. **Status: blocking · owner: TBD.**

3. **1.0 versioning scheme decided (deferred ADR).** thoth stays SemVer `0.x` through pre-1.0
   by design ([ADR-0004](../adr/0004-semver-pre-release.md)). Whether 1.0 adopts CalVer (the
   binary standard) or stays SemVer is deferred to a later ADR. **Status: deferred · owner:
   thoth · decide before the 1.0 tag.**

### v1.0 criteria checklist

- [ ] **At least one downstream consumer green on AGNOS** — gate 1, rungs 2–3
- [ ] **Security review pass** — gate 2, the external sign-off
- [ ] **1.0 versioning scheme decided (SemVer vs CalVer)** — gate 3

## Versioning

thoth uses **SemVer `0.x`** through its pre-1.0 phase — see
[ADR-0004](../adr/0004-semver-pre-release.md). The 1.0 scheme is gate 3 above.

**Arc discipline:** a feature **arc** is ONE minor; the incremental cuts inside it are
**patches** (`X.Y.0` → `X.Y.1` → …). A new minor is for a genuinely new capability arc. When
unsure, patch.

**Batch discipline:**

- **Patches are repair batches.** Known defects, owed verifications, dep refreshes and polish are
  grouped into a numbered batch and shipped together as the next patch of the current minor. A
  batch is ordered by priority; the top of the next batch is the next thing to build. Nothing in
  a repair batch adds a capability.
- **Minors are feature arcs.** Each arc in the map below is one minor. A minor is never a sweep of small
  things — those are patches.
- **Upstream repairs re-vendor as their own patch** the release after the dependency ships, each
  with a line-anchored needle in `tests/cases/vendor.cyr` ([`../doc-health.md`](../doc-health.md)
  lesson 1: a documented residual is a claim with an expiry date — every waiting item below names
  the version it was last checked against, and a release re-checks them).

## Scheduled work

> **The order below is the plan.** Each minor is one arc and its cuts are patches. A pin is a place in the order, not a
> promise that a gate opens: when an arc's turn comes and its gate is still shut, the next open arc takes the number and the
> rest move up. Everything *identified* but not committed lives in [`gap-review.md`](gap-review.md).

| Version | Arc | Gate |
|---|---|---|
| 0.54.x | [**The live wait**](#054x--the-live-wait-then-the-audits-remainder), then the audit's remainder | none for the wait; rulings for the last batch |
| 0.55.x | [**A real turn on AGNOS**](#055x--a-real-turn-on-agnos): v1.0 gate 1 | a runner; the floor for rung 3 |
| 0.56.x | [**F8 — the AGNOS window**](#056x--f8-the-agnos-window) | a stable setu contract, a waitable channel |
| 0.57.x | [**F9 — untrusted reads through the subagent context**](#057x--f9-untrusted-reads-through-the-subagent-context) | ruling: gap-review question 2 |
| 0.58.x | [**F11 — git write operations through sit**](#058x--f11-git-write-operations-through-sit) | ruling: question 3 |
| 0.59.x | [**F10 — image input**](#059x--f10-image-input) | hoosh's content parts |
| 0.60.x | [**F12 — OS-enforced sandboxing and network egress**](#060x--f12-os-enforced-sandboxing-and-network-egress) | ruling: question 1, in kavach |
| 0.61.x | [**F13 — ACP server mode**](#061x--f13-acp-server-mode) | none |
| 0.62.x | [**F14 — OTLP export**](#062x--f14-otlp-export-of-the-audit-trail), then the v1.0 gates | none |

### 0.54.x — The live wait, then the audit's remainder

Batch 15 is split by size, so the largest item opens the minor. Its IDs are the
[2026-11-05 audit](../audit/2026-11-05-audit.md)'s. thoth is on cyrius **6.7.18**, the newest release, with every vendored bundle at its newest tag.

**0.54.0 — The window stays alive through a network wait** (G-6, M-9). The new capability this minor is named for. Today the window is
dead during a silent network wait, a streaming turn's first token included: no frames, Esc ignored, the compositor's ping unanswered, and
a hung gateway blocks the first frame. Measured: Esc at 1.5 s had no effect until the wait ended. It takes a transport that returns between
reads, for every POST. It also closes the network half of *What a stop cannot reach* below.

**0.54.1 — Repair batch 15: the terminal and the process**

1. **`git_probe` grows the heap on every turn** (P-10, M-3). On a 100k-file repository a session went from 37 MB to 515 MB in ten turns, 48 MB a
   turn with no ceiling, and each probe holds the main thread for 1.8 s. It is 0.58 s and 166 KB on this tree. sit allocates on the heap that never
   frees, so the probe needs a forked child or sit on an arena, and the TUI's startup probe moves after the first frame (1.2 s at 100k today). The rest
   is sit's: see the waiting table.
2. **SIGTERM leaves the terminal raw** (S-11). A handler or a signalfd in the input loop.
3. ⛔ **thoth calls darshana's private `_tty_apply_raw_flags`** (`src/intr.cyr:50`) and then sets VMIN and VTIME to 0 for its non-blocking
   Esc poll. darshana's ADR 0003 freezes only its public surface, so any darshana release may rename or reshape it, and the next
   `scripts/sync-darshana.sh` would carry that in. The public `tty_raw_nonblock(fd)` exists, restored by `tty_cooked()`. It is not a one-word
   swap: `intr_arm` keeps a private termios copy so it does not touch darshana's single raw slot, so the move means proving that bracket
   against the post-turn `tty_raw`, live.
4. **Ctrl-C in line-mode `/run` reaches thoth** (P-11). SIGINT and SIGQUIT ignored around the wait, with the child's default restored
   before exec.
5. **A gateway's error body is dropped on a streaming turn.** A 429 reading `token budget exceeded` shows as "error body not surfaced in stream mode;
   set [hoosh].stream=false to see it".
6. **CI and Release run a toolchain nothing here pins** (B-1, B-8). A fresh runner has no `cyrsign`, so `install.sh` trusts a sum from the tarball's own origin, in the job
   that holds `contents: write`. Pin the SHA-256 of `install.sh` and the tarball in a tree file keyed to the pin, download both, check them, and install with
   `CYRIUS_INSTALL_TARBALL`, which also closes a truncated `curl | sh`.
7. **Release rebuilds what CI tested** (P-8). Upload the CI binary and publish that one.
8. **A repository's daimon rows fill the operator's global pin store** (A-7). They never expire, and 11 runs reached the cap, after which the operator's own new tools lose the
   between-runs defence. Keep them session-scoped, or give each host a row quota.

**0.54.2 — Repair batch 16: long replies and the composer**

1. **Each window rebuild rescans every line of a long reply** (M-10). A sparse line index. 5.3 ms at 300 KB today.
2. **The composer has no long-line scroll and its caret is approximate** (G-9).
3. **The TUI paints a frame in hundreds of syscalls** (M-5). A batched frame; the prototype needed a darshana change, so that release
   comes first and re-vendors as its own patch.
4. **Picker rows clip by bytes, mid-character, with no mark** (A-14). Clip at a glyph boundary and draw a mark.

**0.54.3 — Repair batch 17: the rulings.** Each is small once ruled, and a row leaves if the ruling is no.

1. **A local `[hoosh].timeout_ms`** (gap-review question 4): `0` disables the stall deadline beside a repository-redirected gateway.
2. **A local `[log].level`** (question 7): a clone can quieten the operator's session log.
3. **The project map's role** (question 5): whether repository-controlled names belong in a `system` message. Measured with a real model, the map
   saved 27% of tokens over nine navigation tasks (108k against 147k), six searches and two `list_dir` calls.
4. **Pricing a turn from the gateway** (question 6): the picker shows the gateway's price and the tally ignores it, so `[budget].max_cost_micro`
   cannot fire on an unpriced model.
5. **What a refused pin store means** (question 8): today every tool is a first sight for that run, so a swapped definition is advertised, with one line said.

### 0.55.x — A real turn on AGNOS

v1.0 gate 1. thoth and hoosh both print their versions in ring 3; nothing else of the spine's has run there with thoth.

- **0.55.0 — Rung 2.** A runner that stages hoosh, daimon, a config and thoth on one image, starts the two services, gives hoosh a provider
  (a stub on the host, over QEMU's network) and drives `thoth -p` to a reply on the serial console. `basestack-run-smoke.sh` cannot do it:
  it stages one `/bin/probe`, and the selftest hook execs `--version`. A runner for AGNOS is AGNOS's domain, so it lands in `agnos/scripts/smoke/`
  and `scripts/agnos-run.sh` shells out to it, as it does today. `bote-mcp-smoke.sh` is the nearest pattern: a kernel hook preloading a
  ring-3 program. Whatever the first real turn finds, in thoth or the floor, is the arc's work.
- **0.55.1 — The AGNOS hostile pass.** With a turn running, the attacks the 2026-11-05 audit ran on Linux: the wire kit, the capture and the
  stores. It cannot start sooner, because `--version` reaches none of them.
- **0.55.2 — Rung 3.** **Gate:** the floor. A `#97` terminal channel now carries a window size, so an emulator's terminal end is worth reading as
  a route that does not need raw console reads.

### 0.56.x — F8: the AGNOS window

The GUI's half of "AGNOS canonical", and the last part of thoth that runs only on Linux. Scope: the window seam behind a backend contract
(the wait, the buffer, keys, pointer, configure, close), and an AGNOS backend over **setu** — aethersafha's client protocol, consumed as
`setu/dist/setu.cyr`, never re-implemented. The pattern exists: puka's `src/platform/setu/window_setu.cyr` fills the same `win_*` contract
thoth's seam mirrors. Off Linux `thoth gui` refuses before any call (`gwl_win_backend_select`, the seam's one switch); an AGNOS backend slots
in there, with `gwl_win_wait` as its wait.

**Gate — re-read from the source against setu 0.8.13, aethersafha 0.17.7 and agnos 1.57.17, not met:**

- **The contract is not declared stable.** There is no protocol version on the wire (`SETU_HELLO` is defined but aethersafha's handshake
  refuses anything before `CREATE_SURFACE`), and aethersafha names wire work still to come: modifier state on key events, damage rectangles on
  present, a per-surface opt-in for pointer motion.
- **The channel fd cannot be waited on.** `epoll_wait` takes a deadline now but watches signalfd, timerfd and TCP only, so the wait is a
  non-blocking poll and `sys_pause`, crab's way.

What the backend must honour — aethersafha's written client contract
([`001-setu-client-contract.md`](https://github.com/MacCracken/aethersafha/blob/main/docs/architecture/001-setu-client-contract.md)):
`/bin/thoth gui` is a launcher row when `/bin/thoth` exists and `--spawn NAME` starts a registered app at boot, with `HOME` and `PWD` inherited;
bare F2/F3 are the client's but Ctrl chords stay the compositor's, so thoth's pane toggles need non-chord routes on AGNOS; the largest surface a
client may attach is 960×540 (a buffer slot is 2 MB without a GPU carve-out), so thoth's 960×600 default does not fit.

### 0.57.x — F9: untrusted reads through the subagent context

Route `@file` / `read_file` / `web_fetch` results through the subagent child context so retrieved text cannot instruct the main thread (gap 3).
The machinery exists, and it is the largest safety delta thoth can deliver alone. **Gate:** gap-review question 2: a model round per `@file`, and a
laundered summary is arguably a more persuasive injection vector than raw text. Ships opt-in (`[guard].isolate`) if at all.

### 0.58.x — F11: git write operations through sit

Stage, commit, branch and worktree from the agent, through sit's write surface behind `thoth_git_write` in t-ron (gap 7). It moves the read-only
boundary. **Gate:** gap-review question 3. It goes ahead of F10 because this ruling is its only gate.

### 0.59.x — F10: image input

A screenshot or an image path as a content part; the GUI can produce one from its own frame (gap 5), which few agents can do. **Gate:** hoosh must
translate content parts per provider (the waiting table). thoth never translates provider shapes itself.

### 0.60.x — F12: OS-enforced sandboxing and network egress

`shell` and `edit` confined through kavach (gap 1), the largest safety delta overall; last of the safety arcs by blocker, not by value. **Gate:** gap-review
question 1, kavach's design decision. Its interpreter blocklist is lifted only for a sandbox with a rootfs, so a host shell without one is still refused:
either a host-exec confinement tier in kavach or a rootfs-shaped `shell` mode in thoth. `[lib.confine]` builds inside thoth. Network egress control (gap 2) is
decided with it: daimon's and kavach's seam.

### 0.61.x — F13: ACP server mode

Drive thoth from another editor over the Agent Client Protocol (gap 6); `--events` is the one-way half already. **Gate:** none architectural. Big: a second
front end's worth of surface, for distribution value.

### 0.62.x — F14: OTLP export of the audit trail

Emit the libro chain to a collector under the OpenTelemetry GenAI conventions (gap 4). **Gate:** none; low priority for an interactive TUI.

**Then the v1.0 gates**, on this minor's last patches: a final P(-1) sweep, the external security review (gate 2) and the versioning ADR (gate 3).

### No slot yet

Each waits on a domain that has not been ported, so there is nothing to order: the **bhava** mood loop (the waiting table); **voice / mic** — mic → speech-to-text and
read-back — by consuming an AGNOS audio/voice domain plus a portable audio-capture substrate, neither of which exists yet.

**Context for the chat arcs.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard — is being handed to thoth: thoth's TUI + native T3 GUI
become the canonical AGNOS-family chat/coding front-end. The rule is the same as the rest of the spine — **CONSUME already-built AGNOS domains (mneme, bhava, an
audio/voice domain), never reinvent them.** SY's enterprise guardrail stack (t-ron is thoth's answer), multi-platform group-chat bridges, and the web-dashboard admin
stay **out of scope**. Data fields follow **omit-until-present** ([ADR-0010](../adr/0010-data-producer-honest-omit.md)).

### Waiting on upstream or the floor (repairs owned elsewhere — re-vendor as their own patch)

Each row carries the version it was last checked against, and every row was re-read on 2026-11-05. A release re-checks the list; a closed item becomes a
re-vendor patch with a line-anchored needle in `tests/cases/vendor.cyr`. t-ron 2.2.4 was tested on bote-core 3.8.9; thoth vendors 3.8.15, and nothing thoth reaches
in t-ron calls into bote.

| Owner | What | Checked against | thoth's half |
|---|---|---|---|
| **hoosh** | an `--agnos` lane: nothing in its CI or scripts builds one, so the `hoosh_agnos` on disk is 2.4.11. `cyrius build --agnos src/main.cyr` makes a current one | hoosh **2.10.0** · daimon 2.5.3 | 0.55.0's runner builds its own |
| **daimon** | pin once for every consumer (ADR-0022's end state): a persisted registry, a `definition_sha256` + `pinned_at` per manifest element in `/v1/mcp/tools`, an audit event when a registration changes a definition, a per-consumer trust verb through t-ron; today `POST /v1/mcp/tools` takes no auth (`src/api_mcp.cyr:11`; daimon's roadmap puts caller auth at 2.6.x) and re-registering an external name overwrites it (`map_set`, `src/mcp.cyr:125`); manifest entries carry name, description and `inputSchema` only (`:133-140`) | daimon **2.5.3** | done — thoth's own pin store (ADR-0022) is the client-side floor; when the manifest carries a hash thoth compares its own to it (a mismatch = the two canonicalise differently, announced) |
| **hoosh** | multimodal content parts: `_build_anthropic_body_x` reads `content` as a string (`src/lib/provider.cyr:543`) and a plain `{role,content}` passes through verbatim, so an OpenAI-shaped `image_url` part is never translated to Anthropic `image` / Gemini `inline_data`; the per-model `vision` bit is there (the compiled table, and each live catalog entry's `capabilities.vision`) — the prerequisite for candidate F10 | hoosh **2.10.0** | none yet — thoth sends text only |
| **hoosh** | an OpenAI **Responses API** path: gpt-6-astra and gpt-6.1-sol take no function calling on Chat Completions (OpenAI serves their tools through `/v1/responses` only), and hoosh speaks Chat Completions — so an agentic thoth turn cannot drive them | hoosh **2.10.0** | none — pick another model for agentic turns; a plain turn (`[hoosh].tools = false`) works |
| **hoosh** | `reasoning_effort` on **Gemini and Ollama**: mapped to Anthropic thinking and forwarded to OpenAI-compatible reasoning models, but not to Gemini's `thinkingConfig` or Ollama's `think` | hoosh **2.10.0** | done — thoth sends `reasoning_effort`; the row lights up when hoosh maps it |
| **hoosh** | **cache tokens**: Anthropic's `cache_creation_input_tokens` / `cache_read_input_tokens` and every provider's cached-input rate are not modelled, so a cached prompt is costed at the full input rate | hoosh **2.10.0** | none — thoth prices from `[pricing]`, which has no cache rate either |
| **agnosai** | `agnosai_redact_email` rescans the run from every byte, `agnosai_output_redact` rebuilds the string per hit, and `_ssn` and `_email` rebuild with no match (M-1, M-2, M-6). A fix is proven against the shipped behaviour: 300,000 fuzz cases, 0 differences | agnosai-guard 2.2.3 | `REDACT_WINDOW` holds it at 2 KiB, and a secret straddling a hard split in an unbroken run is the residual; drop the window on the fix |
| **sit** | `_status_blob_differs` inflates every tracked blob, 84% of a probe in zlib; `.git/index` stat data would spare it. `sit_repo_close` returns nothing to the heap (P-10, M-3) | sit 1.13.0 | batch 15 moves what thoth can |
| **mneme** | `mneme_create_note` answers "Failed to create note" for a title it already holds, so `/remember` of a fact already saved reads as a failed write | mneme 1.1.4 | the message is true: nothing new was written |
| **cyrius** | `scripts/install.sh`, which thoth's CI and Release run. A first install verifies no signature, and its sum sidecar can name another file (B-1); it compiles `programs/dlopen-helper.c` from the caller's working directory, and under root installs the result where setuid consumers trust it (B-2); it deletes real `bin` and `lib` directories under `CYRIUS_HOME` (B-3); its Starship snippet prints a repository's bytes raw (B-4); a broken install reports success (B-5); activation is not atomic (B-6); a fetch failure falls through to an unverified clone (B-7); a cut `curl \| sh` exits 0 (B-8); a reinstall can exit 1 (B-9); no network timeouts (B-10). Scripts and repros: [`../audit/2026-11-05-not-verified-pass.md`](../audit/2026-11-05-not-verified-pass.md) | cyrius **6.7.18** | batch 15's pin. thoth selects no libssl, so B-2 does not reach it |
| **sakshi** | no mode parameter on its output file | cyrius 6.7.18 | `_log_open_safe` creates the file first |
| **bayan** | an unterminated array in a config swallows the lines after it | cyrius 6.7.18 | none: that direction fails closed |
| **sit + bote profiles** | the sit `[lib.read]` carve (drops the `cmd_reset` duplicate and the `undefined function` warnings — `load_signing_seed`, `sign_commit_body`, `verify_commit_body`, `commit_tree_hex` — every lane prints; expected output, not a regression) and a bote `[lib.jsonx]` micro-profile (233 fns → 7) — warning hygiene only | neither exists upstream: sit 1.13.0's `[lib.read]` still defines `cmd_reset` and leaves four unresolved (the three, and `commit_tree_hex`, all unreachable); bote 3.8.15 has `[lib]` and `[lib.core]` only | `sync-*.sh` re-vendor when they do |
| **darshana** | a BSD termios peer → the T2 TUI on macOS (`src/termios.cyr:80` keeps macOS out of scope; thoth's `term_raw` returns -1 there and the line tier is the degradation) | darshana **1.7.0** (vendored 1.7.0) | `src/term.cyr`'s macOS branch collapses into the forwarder when it lands |
| **t-ron / sit** | the Windows lane's blockers, every one in a vendored bundle and none reached by a thoth call: t-ron's `sighup_init` (`SIGHUP`, `SIG_BLOCK`, `SIG_SETMASK`), and POSIX-only paths sit 1.13.0 does not gate (`SYS_GETEUID`, `SYS_FCHMOD`, `SYS_GETCWD`, `O_CLOEXEC`, `O_NONBLOCK`, `sys_fstat`). Through sit 1.7.0 only t-ron's first two stood in the way, and a full PE linked with them defined | t-ron **2.2.4** · sit **1.13.0** | `scripts/build.sh` names them as `VENDOR_GAP`; `TTY_SIGMASK_WINCH` stays off every list as the tripwire. With those names defined a PE ran streaming and blocking turns, `read_file` and a `cmd.exe` capture with its deadline on Windows 11. Before anything ships on PE: a capture that carries an environment block (the PE capture inherits, so `[hooks]` reports "could not run" and a `pre_tool` denies; the floor's `_win_create_process` takes a block, `src/exec.cyr` passes 0), and the jail, which does not hold there: `..\x`, `sub\..\..\x`, `C:\x`, `C:/x`, `\\?\C:\x` and `\\127.0.0.1\C$\x` all read outside the project, and `CON` hangs `read_file` |
| **cyrius (floor)** | `lib/process_win.cyr:354`: `cmd.exe` is found by a search that takes in the cwd, so a planted one would run. The Windows lane is closed by the row above | cyrius 6.7.18 | none until the lane opens |
| **cyrius (floor)** | a portable `chmod`/`fchmod` (tighten a pre-existing history or pin store to `0600`; `sys_chmod` is a return-0 stub on Windows `syscalls_windows.cyr:610` and AGNOS `syscalls_x86_64_agnos.cyr:1048`; `file_write_atomic` keeps an existing mode on Linux and macOS but never tightens one) | cyrius **6.7.18** | never assert a mode thoth cannot enforce; documented in `.thoth/config.cyml.example` |
| **cyrius (floor)** | `dir_list_into` surfaces no `d_type` (`lib/fs.cyr:310`), so the map's dirs-first order probes every child (`_pmap_is_dir`, up to 256 × 256 opens a turn on a wide tree); an arm that did would make the walk one `getdents` per directory | cyrius **6.7.18** | the per-child probe is `O_NONBLOCK` + `getdents` so a FIFO cannot hang a turn |
| **agnos (floor)** | `sys_open(name, namelen, ao_flags)` carries no create-mode channel (`lib/io.cyr:108`; the kernel's `ext2_create` sets `0644`) — a file created on AGNOS lands at the kernel default, not `0600`; and `fsync` syncs the whole fs | agnos **1.57.17** | degrades honestly; a candidate filing if the ABI gains a mode channel |
| **gnoboot (AGNOS boot)** | `ExitBootServices` is called once and a failure is final (`src/main.cyr:1107`): the UEFI spec's answer to a stale map key (`EFI_INVALID_PARAMETER`) is to call `GetMemoryMap` again and retry. The map is refreshed just before the call, which narrows the window and does not close it | gnoboot **0.9.0** | done — `scripts/agnos-run.sh` classifies a boot that died before the kernel, retries it (announced) and SKIPs when none gets there; never a thoth FAIL |
| **bhava** | the sentiment→mood loop — bhava is **2.0.0** and still Rust; consume it when it is ported, never reimplement | bhava 2.0.0 | none |
| **secureyeoman** | its model choice, left until its port is further along, by the maintainer's call: spot fixes are not worth making first. It keeps its own catalog, pricing and context tables (TypeScript `model-registry.ts`, `cost-calculator.ts`, `context-compactor.ts`) plus Rust defaults in `sy-core`, its `HooshDelegate` falls back to `gpt-4o`, and about a dozen internal tasks hardcode `claude-haiku-3-5-20241022`, which is not an Anthropic id. The port should read hoosh's `/v1/models/catalog` the way thoth does. agnosai's B33 and agnostic's M9 model picker carry their halves on their own roadmaps | secureyeoman | none: its chat surface comes to thoth anyway |

**The Windows lane has no architectural half left to surface:** the raw socket path left `lib/sandhi.cyr` and the
epoll/futex set no longer appears; `scripts/build.sh`'s `ARCH_GAP` pattern keeps the permanent names as a tripwire.

## Carried defects and degradations (the registry)

> Each entry is a real defect thoth has not yet fixed (**⛔**, scheduled in a batch or waiting on its
> owner above) or an honest degradation gated on a primitive thoth does not have. Every entry names
> where it is scheduled. Recorded here so it is not lost in code comments.

**Scheduled above:** the 0.54.x batches, with the ⛔ darshana call in batch 15; the pointer path being Linux-Wayland only (F8). **Proofs:** the runs behind this table, and how to repeat them, are in [`../guides/verification-pass.md`](../guides/verification-pass.md).

**Degradations, by design or by the floor:**

- **The window renders at buffer scale 1** — on a scaled output the compositor upscales it, so at scale 2 (Hyprland,
  verified live) the text and the 12×19 arrow are soft rather than small. `wl_surface.set_buffer_scale` (or
  fractional scaling) would draw both crisp at the output's density; a feature if it earns a slot, not a repair.
- **What a stop cannot reach** — Esc stops a command only where a wait loop hands control back. A Windows
  capture is one blocking wait inside `lib/process_win.cyr` (it still ends at its deadline; the lane is closed
  anyway); line mode's streaming `/run` gives the child the terminal; and a blocking
  network call — `daimon_invoke`, a non-streaming round, `hoosh_health_probe` — is a socket read with no poll in it,
  so the window is not pumped during one (bounded by `[hoosh].timeout_ms`). 0.54.0 closes the network half.
- **The TUI prints `session_start`'s report to the primary screen** — main.cyr fires the hook
  (`:242`) before `tui_loop` raises the alt screen (`:244`), so a hook that printed is visible
  only after exit. Harmless; the window shows the same report as a card.
- **`/reload` does not rebind `[history]` / `[session]` / `[toolpin]` `file`** — a restart, named on
  `/reload`'s own "restart to change" line and in the config example. By design: a store bound
  mid-session would either lose or double what it holds.
- **Resumed summary cards are an honest subset** — the store keeps at most `MSG_TOOL_MAX` (8) calls
  per reply and no total (a summary cannot say "8 of 23"); the grounding verdict and the edit diff
  are not persisted. Omit-until-present; a bigger store is a patch if a reply ever needs it.
- **The question modal is keyboard-driven** (clicks under it are dropped); no drag / right button /
  double-click semantics; a click that arrives while the drawn frame is stale (a key or a resize in
  the same batch) is dropped rather than resolved against old geometry. Cuts of F8 if they earn one.
- **A pre-0.48.0 thoth reading a 0.48.0 store loads each `RSN` frame as a "user" record** — shown as
  the operator's words, re-sent to the model, a `SESS_HIST_MAX` slot each, cemented by that binary's
  first save. Downgrade only; a magic bump would be worse (an old thoth loads nothing from a
  `THOTH-SESSION-3` file and truncates it). The 0.48.0 loader skips unknown frames, so the NEXT
  frame is safe.
- **The project map** — a root with more than 256 entries maps to a one-line notice, not a partial
  map (`dir_list_into` errors past its caps, never a short read); the dirs-first order probes every
  child (the `d_type` floor row); every agentic round re-sends the map's bytes (the same bytes each
  round, which is what prefix caching wants).
- **Tool pins** — the ceiling is a same-uid editor or a deleted store (stated in ADR-0022 and the
  config example); two sessions writing at once are last-writer-wins, whether trusting or pinning a
  first sight; schema key order is part of the hash (a reordering server reads as changed — withheld, never
  allowed; canonicalise if a real one appears); the mode claim holds on POSIX only (AGNOS's create
  mode and Windows's ACL — the floor rows).
- **Memory double read — the last case** — a `~/.thoth/` reached by the root walk from below that
  holds fact files but **no `MEMORY.md`** and no `config.cyml` gives no bytes to recognise, so it is
  returned as the project root AND as the global layer: every fact injected twice. Kept over the
  other failure (a dropped global layer is silent; the double read is only waste); `$PWD` alone
  must never make the claim. Closes if the memory layer ever writes an index on first use.
- **Streaming usage needs hoosh >= 2.8.0** — every streaming request carries `stream_options.include_usage`, which hoosh
  answers from 2.8.0 on (from the provider's own counts); against an older hoosh a stream feeds no
  token/cost row and `[budget]` cannot be enforced on that path (`[hoosh].stream = false` is the way round there).
  A provider that reports no usage (most local OpenAI-compatible servers, unless they honour the option) still
  leaves the row unfed.
- **Input-history hardening** — a fresh `[history].file` is created `0600` on POSIX and opened
  with `O_NOFOLLOW`, so a symlinked file is refused rather than followed; a pre-existing looser file is
  still never re-tightened (the `chmod` floor row: never assert a mode thoth cannot enforce). The
  tool-pin store takes the same bit.
- **macOS** — builds, runs and passes its native suite at the pin; the T2 TUI does not run there:
  `term_raw` returns -1 (the darshana row), so thoth takes the line tier. When the BSD peer lands,
  `src/term.cyr`'s macOS branch collapses into the forwarder and nothing above it changes.
- **Windows lane** — blocked outside thoth's authored source, on nine **vendored** `VENDOR_GAP` names in t-ron and sit, and not
  safe to ship past them until its read jail is written (the waiting table). `scripts/build.sh` keeps the permanent **architectural** names as a tripwire; none surfaces.
  The PE capture inherits thoth's environment, so `[hooks]` reports "could not run" there and a
  `pre_tool` denies. `TTY_SIGMASK_WINCH` stays off **every** list on
  purpose — a new raw `tty_*` call in thoth source turns the lane red, the regression tripwire.
- **The `shell` deny/allow filter is a coarse pre-filter and says so** — a real sandbox is F12
  (kavach), a feature, not a repair.

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
- **A speculative spine dependency.** A spine crate joins the build only when a seam consumes it, as a
  vendored bundle in `src/vendor/` re-synced as its own patch; hoosh and daimon are *running services*
  reached over the stdlib `sandhi` transport, never `cyrius.cyml` deps. The **off-AGNOS reach
  transport** — the native-vs-remote binding distinction — is deferred to a later ADR once that work
  is real.
