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
up plus two process gates. Gate 1 (the `--agnos` ELF builds, loads and runs in ring 3) closed at
0.44.4 and is re-run at every release — `scripts/agnos-run.sh` shells out to AGNOS's own
`basestack-run-smoke.sh` and derives the expected string from `VERSION`, so it cannot pass on a
stale binary. Last re-run 0.52.3 (2026-09-17): the 5.9 MB ELF printed `thoth 0.52.3` in ring 3 and
exited 0 under QEMU.

Three gates remain, in dependency order.

1. **At least one downstream consumer green on AGNOS (end-to-end).** Three rungs; rung 1
   (thoth runs in ring 3, ~90 s under QEMU + OVMF) is done.
   - **Rung 2 — a real turn against the spine, staged on the same image.** Open. Needs a
     current `hoosh_agnos` (the one on disk is 2.4.11, 2026-07-01, against hoosh 2.6.10) and a
     `daimon_agnos` beside it (none exists yet). This is the rung that satisfies the gate's
     wording. `scripts/agnos-run.sh` is ready to stage them.
   - **Rung 3 — the interactive TUI over agnsh.** Open, least urgent.
   **Status: blocking · owner: thoth.**

2. **Security review pass (process gate) — the external sign-off.** The fail-closed posture
   and the t-ron choke point were swept by the 0.39.0 audit
   ([`../audit/2026-08-24-audit.md`](../audit/2026-08-24-audit.md)); the concurrency review of
   the parallel executor was done at 0.44.3. What remains is whatever "pass" means to someone
   who is not the author. The sign-off should also read the GUI's authorization path — the
   `ask_user` modal answering `confirm` and the session grant it can record
   ([ADR-0020](../adr/0020-ask-user-the-tool-that-runs-toward-the-operator.md), 0.46.0) — and
   the durable tool-pin store ([ADR-0022](../adr/0022-tool-pins-are-durable-defended-without-a-secret.md)), both
   younger than the audit. **Status: blocking · owner: TBD.**

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
- **Minors are feature arcs.** Seven have shipped (F1–F7 — the CHANGELOG); the next decided
  feature earns `0.53.0`. A minor is never a sweep of small things — those are patches.
- **Upstream repairs re-vendor as their own patch** the release after the dependency ships, each
  with a line-anchored needle in `tests/cases/vendor.cyr` ([`../doc-health.md`](../doc-health.md)
  lesson 1: a documented residual is a claim with an expiry date — every waiting item below names
  the version it was last checked against, and a release re-checks them).

## Scheduled work

> Repair batches are pinned. Feature arcs are listed as candidates and stay unpinned until one is
> decided — the pin lands here with the decision. Everything *identified* but not committed lives in
> [`gap-review.md`](gap-review.md).

### Repair batch 9 → 0.52.4 (empty)

No thoth-owned defect is known. The next one found opens this batch; until then the next thing to build is the first
feature candidate below whose gate is open.

The window's checks run live: `scripts/gui-live.sh` starts a private headless Hyprland from any session (SSH
included) with a screenshot + input kit and a stub gateway (an aarch64 build runs under `qemu-aarch64` against it), and
`scripts/live/ptydrive.py` drives the TUI in a pty — a front-end change is verified running, not only by suite.

### Waiting on upstream or the floor (repairs owned elsewhere — re-vendor as their own patch)

Each carries the version it was last checked against (2026-09-17, at 0.52.1 — no row's dependency moved since
0.52.0). A release re-checks the list; a closed item becomes a re-vendor patch with a line-anchored needle in
`tests/cases/vendor.cyr`.

| Owner | What | Checked against | thoth's half |
|---|---|---|---|
| **AGNOS spine builds** | a current `hoosh_agnos` (on disk: 2.4.11, 2026-07-01) and a `daimon_agnos` (none exists: daimon's `--agnos` build fails with 53 errors — measured upstream as a cyrius `cbt` sidecar-leaf resolution pulling `lib/syscalls_linux_common.cyr` in through bote's `dist/bote.deps`, plus 3 in daimon's own `src/agent.cyr`; filed in daimon's `docs/development/issues/2026-09-14-daimon-does-not-build-for-agnos.md`) — gate 1 rung 2 | hoosh 2.6.10 · daimon **2.1.4** | `scripts/agnos-run.sh` is ready to stage them |
| **daimon** | pin once for every consumer (ADR-0022's end state): a persisted registry, a `definition_sha256` + `pinned_at` per manifest element in `/v1/mcp/tools`, an audit event when a registration changes a definition, a per-consumer trust verb through t-ron; today `POST /v1/mcp/tools` takes no auth (`src/api_mcp.cyr:47`) and overwrites on the same name | daimon **2.1.4** (a toolchain bump; unchanged) | done — 0.51.0's store is the client-side floor; when the manifest carries a hash thoth compares its own to it (a mismatch = the two canonicalise differently, announced) |
| **sit** | ⛔ git read-mode status false positives: every tracked `100755` file and every zero-byte file reads "modified" (16 on a clean tree at 0.51.0 — the fifteen executable `scripts/*.sh` and the zero-byte `docs/examples/.gitkeep`; `_blob_differs_from_file` calls an unreadable side "differs", `src/api.cyr:146`) | sit **1.6.2** (vendored 1.6.2) | none — `git_probe` copies sit's vec; fix is sit's comparator |
| **hoosh** | ⛔ SSE frames dropped on the Anthropic streaming path: `_emit_anthropic_tool_delta` returns 0 when a `content_block_start` lacks `id`+`name` (`src/lib/handlers.cyr:1542`) while the `input_json_delta` fragments still arrive | hoosh **2.6.10** | done — 0.44.2 drops and announces such a call |
| **hoosh** | the streaming usage frame (`stream_options.include_usage` / `message_delta.usage` decode — named as hoosh's own follow-up at `handlers.cyr:2516`; the issue text to file is in the 0.45.5 CHANGELOG entry) | hoosh **2.6.10** | thoth keeps requesting it and already decodes it — the row lights up when hoosh ships the frame |
| **hoosh** | three asks from the picker: the serving ROUTE per catalog entry (a `base_url` or route index beside `owned_by` in `/v1/models/catalog`, so a model joins to ITS route's health instead of its kind's fold — a kind with partitioned routes reads `degraded` for every model of it today); a pricing-table dump (a `GET` listing `pricing_lookup` for every catalog key — `/v1/cost/estimate` answers one model per call); `/v1/health/providers` emitting `base_url` unescaped (`handlers.cyr:641`, a raw `add_cstr` — a quote in a route url breaks the body and thoth reads "health unavailable"). And a remote route's `healthy` is a TCP connect (`health.cyr:16`), never a valid key | hoosh **2.6.10** | done — 0.47.0 folds per kind, prices from the operator's table, treats an unparseable health body as unavailable |
| **hoosh** | multimodal content parts: `content` is read as a string (`src/lib/provider.cyr:445`) and a plain message passes through verbatim (`:461`), so an OpenAI-shaped `image_url` part is never translated to Anthropic `image` / Gemini `inline_data`; `metadata.cyr` already carries a per-model `vision` bit — the prerequisite for candidate F10 | hoosh **2.6.10** | none yet — thoth sends text only |
| **t-ron** | `_audit_export_event` splices `agent`/`tool`/`reason` unescaped (`src/audit.cyr:194`, `:196`, `:202`) and sizes the buffer flat (`n * 512 + 32`, `:216`) — a 4000-byte tool name writes past the allocation; the artifact is a SECURITY record | t-ron **2.1.10** (vendored 2.1.10) | done — both executors refuse a name over `AGENT_NAME_MAX` before the gate |
| **sit + bote profiles** | the sit `[lib.read]` carve (drops the `cmd_reset` duplicate and the three `undefined function` warnings — `load_signing_seed`, `sign_commit_body`, `verify_commit_body` — every lane prints; expected output, not a regression) and a bote `[lib.jsonx]` micro-profile (233 fns → 7) — warning hygiene only | neither profile exists upstream (sit 1.6.2 · bote 3.3.9) | `sync-*.sh` re-vendor when they do |
| **darshana** | a BSD termios peer → the T2 TUI on macOS (`src/termios.cyr:80` keeps macOS out of scope; thoth's `term_raw` returns -1 there and the line tier is the degradation) | darshana **1.1.2** (vendored 1.1.2) | `src/term.cyr`'s macOS branch collapses into the forwarder when it lands |
| **t-ron / sit / cyrius** | the Windows lane's vendored gaps: t-ron's SIGHUP policy hot-reload (`SIGHUP` / `SIG_BLOCK`, zero thoth callers), sit's `sit_rmdir` against a floor with no `RemoveDirectoryW` route (`lib/io.cyr:142`), and a spawn that carries an environment BLOCK (the PE capture inherits; `[hooks]` reports "could not run" and a `pre_tool` denies) | t-ron 2.1.10 · sit 1.6.2 · cyrius **6.6.4** | `scripts/build.sh` names them as `VENDOR_GAP`; `TTY_SIGMASK_WINCH` stays off every list as the tripwire |
| **cyrius (floor)** | a portable `chmod`/`fchmod` (tighten a pre-existing history or pin store to `0600`; `sys_chmod` is a return-0 stub on Windows `syscalls_windows.cyr:238` and AGNOS `syscalls_x86_64_agnos.cyr:685`) | cyrius **6.6.4** | never assert a mode thoth cannot enforce; documented in `.thoth/config.cyml.example` |
| **cyrius (floor)** | `dir_list_into` surfaces no `d_type` (`lib/fs.cyr:248`), so the map's dirs-first order probes every child (`_pmap_is_dir`, up to 256 × 256 opens a turn on a wide tree); an arm that did would make the walk one `getdents` per directory | cyrius **6.6.4** | the per-child probe is `O_NONBLOCK` + `getdents` so a FIFO cannot hang a turn |
| **cyrius (floor)** | `is_symlink` returns 0 on Windows (`lib/fs.cyr:433`), so the jail's symlink walk (audit A-1) and the toolpin store's link refusal are no-ops there — **the PE lane must not ship without revisiting it** | cyrius **6.6.4** | the lane is closed anyway (architectural, below) |
| **agnos (floor)** | `sys_open(name, namelen, ao_flags)` carries no create-mode channel (`lib/io.cyr:92`) — a file created on AGNOS lands at the kernel default, not `0600`; and `fsync` syncs the whole fs | the 0–33 ABI (agnos 1.57.4) | degrades honestly; a candidate filing if the ABI gains a mode channel |
| **gnoboot (AGNOS boot)** | `ExitBootServices` is called once and a failure is final (`src/main.cyr:989`): the UEFI spec's answer to a stale map key (`EFI_INVALID_PARAMETER`) is to call `GetMemoryMap` again and retry, and firmware events between the two calls make it intermittent — the AGNOS smoke died before the kernel in 2 of 3 boots at 0.52.1 (and in 1 of 2 with the passing 0.52.0 ELF padded). The smoke also stages BOOTX64.EFI built 2026-05-16 (v0.7.1) | gnoboot **0.7.2** | done — `scripts/agnos-run.sh` (0.52.2) classifies a boot that died before the kernel, retries it (announced) and SKIPs when none gets there; never a thoth FAIL |
| **cyrius (stdlib)** | `memfd_create`, `ftruncate` and `sendmsg` have no `SYS_*` name in either syscall table, so ESYSXLAT cannot renumber them for aarch64 and an x86_64 number passes through silently (319 unknown, 77 → `tee`, 46 → `ftruncate`); filed as cyrius `docs/development/issues/2026-09-17-thoth-memfd-ftruncate-sendmsg-unnamed-pass-through-on-aarch64.md`. ⚠ The stopgap has one hazard: named later, the regenerated table renumbers thoth's aarch64 literal 46 (native `ftruncate`) as x86 `sendmsg` | cyrius **6.6.4** | done — `src/gui/gwindow.cyr` writes the aarch64 numbers under `#ifdef CYRIUS_ARCH_AARCH64`, and `test_gui_shm_calls` runs all three for real (natively, and as an aarch64 binary under `qemu-aarch64`); switch to the names the release they ship |
| **bhava** | the sentiment→mood loop — bhava is **2.0.0** and still Rust; consume it when it is ported, never reimplement | bhava 2.0.0 | none |

**Permanent by design (not waiting):** the Windows lane's architectural half — the raw socket path
(`SYS_SOCKET` / `SYS_CONNECT` in `lib/sandhi.cyr`, ws2_32). At cyrius 6.6.3 the epoll/futex set no longer
surfaces (the PE floor routes IOCP); `scripts/build.sh`'s `ARCH_GAP` pattern still lists it as the tripwire.
The lane gates closed, announced.

### Feature arcs → minors (0.52.0 and on) — candidates, unpinned until decided

> **Context.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard — is
> being handed to thoth: thoth's TUI + native T3 GUI become the canonical AGNOS-family chat/coding
> front-end. The rule is the same as the rest of the spine — **CONSUME already-built AGNOS domains
> (mneme, bhava, an audio/voice domain), never reinvent them.** SY's enterprise guardrail stack (t-ron
> is thoth's answer), multi-platform group-chat bridges, and the web-dashboard admin stay **out of
> scope**. Data fields follow **omit-until-present** ([ADR-0010](../adr/0010-data-producer-honest-omit.md)).

Recommended order, with the reason for the place. Each is ONE minor; its cuts are patches.

- **F8 — The AGNOS window backend for the GUI.** Scope: the window seam behind a backend contract (the wait, the
  buffer, keys, pointer, configure, close), and an AGNOS backend over **setu** — aethersafha's client protocol, consumed
  as `setu/dist/setu.cyr` (0.8.9), never re-implemented. The pattern exists: puka's `src/platform/setu/window_setu.cyr`
  fills the same `win_*` contract thoth's seam mirrors. **Gate — read from the source 2026-09-17, not met:**
  - **The contract is not declared stable.** There is no protocol version on the wire (`SETU_HELLO` is defined but
    aethersafha's handshake refuses anything before `CREATE_SURFACE`), `ATTACH` went from five arguments to six at
    setu 0.8.8, and aethersafha names wire work still to come: modifier state on key events, damage rectangles on
    present, a per-surface opt-in for pointer motion.
  - **thoth cannot be launched as a window.** On AGNOS a client does not dial: aethersafha spawns it with its end of a
    channel in `AGNOS_CHAN`, and its launcher registers only `/bin/puka` and `/bin/crab`
    (`aethersafha/src/main.cyr:1097`). A spawned client gets no `HOME`.
  - **Every GUI chord would be dead.** Any key pressed with Ctrl held never reaches a client
    (`aethersafha/src/main.cyr:1318`; aethersafha's issue `2026-09-13-claimed-keys-never-reach-a-client.md`), which
    is Ctrl+B/S/K/R/T — and F2/F3 are claimed too.
  - **The floor:** a buffer slot is 2 MB without a GPU carve-out (QEMU), so the 960×600 default does not fit; a
    channel fd cannot be waited on (`epoll_wait` reports signalfd/timerfd/TCP only — the wait is a non-blocking poll
    and `sys_pause`, crab's way).
  - **Gate 1 rung 3 cannot be reached:** AGNOS has no raw terminal (no termios; console stdin is cooked and drops
    every key without an ASCII value), so the TUI takes the line REPL there.
  Off Linux `thoth gui` refuses before any call (`gwl_win_backend_select`, the seam's one switch); an AGNOS backend
  slots in there, with `gwl_win_wait` as its wait. **The next step is upstream, filed as aethersafha's `docs/development/issues/2026-09-17-a-setu-client-outside-the-registry-cannot-start.md`:**
  a way to start a setu client that is not puka or crab, HOME/PWD for a spawned client, the keys a client can count on
  (the 0.16.25 ruling made Ctrl chords chrome — thoth accepts it and needs non-chord routes to its pane toggles on
  AGNOS), and the largest surface a client may attach. **First** in the order still: it is
  the GUI's half of "AGNOS canonical" and the last part of thoth that runs only on Linux.
- **F9 — Untrusted reads through the subagent context (gap 4).** Route `@file` / `read_file` /
  `web_fetch` results through the 0.43.0 child context so retrieved text cannot instruct the main
  thread. **Gate:** the maintainer's decision (gap review question 3) — a model round per `@file`, and a
  laundered summary is arguably a more persuasive injection vector than raw text; ships opt-in
  (`[guard].isolate`) if at all. **Third** because the machinery exists and it is the largest safety
  delta thoth can deliver alone; kept behind a decision, not a wiring job.
- **F10 — Image input (gap 6).** A screenshot or an image path as a content part; the GUI can
  produce one from its own frame. **Gate:** hoosh must translate content parts per provider (the
  waiting row — `provider.cyr` reads `content` as a string; the `vision` bit in `metadata.cyr` is
  there). **Fourth**: real value (the GUI is one of the few agents that can both take and read a
  screenshot) but hoosh first — thoth never translates provider shapes itself.
- **F11 — Git write operations through sit (gap 8).** Stage, commit, branch, worktree, from the
  agent, through sit's write surface behind `thoth_git_write` in t-ron. **Gate:** the maintainer's
  yes (gap review question 4) and sit's status comparator fix (a writer over a reader that reports
  16 phantom changes is not honest). **Fifth**: high value, but it moves the read-only boundary and
  needs two decisions outside thoth.
- **F12 — OS-enforced sandboxing of `shell` / `edit` via kavach (gap 1).** **Gate:** kavach's
  design decision — its interpreter blocklist became conditional on a rootfs at 3.12.1, so a host
  shell without one is still refused; either a host-exec confinement tier in kavach or a
  rootfs-shaped `shell` mode in thoth. Kavach is 3.12.5; `[lib.confine]` builds inside thoth.
  Network egress control (gap 2) is decided with it — daimon's and kavach's seam. **Sixth** by
  blocker, not by value: it is the largest safety delta, and it cannot start until kavach's owner
  answers.
- **F13 — ACP server mode (gap 7).** Drive thoth from another editor over the Agent Client
  Protocol; `--events` is the one-way half already. **Gate:** none architectural; big (a second
  front end's worth of surface). **Seventh** — distribution value, after the safety and AGNOS work.
- **F14 — OTLP export of the audit trail (gap 5).** Emit the libro chain to a collector under the
  OpenTelemetry GenAI conventions. **Gate:** none; low priority for an interactive TUI. Last.
- **Measure, not build:** the project map's effect on `list_dir` round-trips was never measured
  live (no model in the harness). Count `list_dir` calls per turn in `--logs` with `[project].map`
  on vs off against a real gateway — the 0.44.1 lesson says measure prose before trusting it. A
  session's task, not a release's.
- **Gated on another domain's port (recorded, not on a numbered arc):** the **bhava** mood loop
  (the waiting row); **voice / mic** — mic → speech-to-text and read-back — by consuming an AGNOS
  audio/voice domain plus a portable audio-capture substrate, neither of which exists yet.

## Carried defects and degradations (the registry)

> Each entry is a real defect thoth has not yet fixed (**⛔**, scheduled in a batch or waiting on its
> owner above) or an honest degradation gated on a primitive thoth does not have. Every entry names
> where it is scheduled. Recorded here so it is not lost in code comments.

**Scheduled above:** nothing — repair batch 9 is empty.

**Candidates above:** the pointer path Linux-Wayland only (F8).

**Degradations, by design or by the floor:**

- **The window renders at buffer scale 1** — on a scaled output the compositor upscales it, so at scale 2 (Hyprland,
  verified live at 0.52.1) the text and the 12×19 arrow are soft rather than small. `wl_surface.set_buffer_scale` (or
  fractional scaling) would draw both crisp at the output's density; a feature if it earns a slot, not a repair.

- **`gate_init` / `log_init` failure lines are discarded on the `thoth gui` path** — main.cyr runs
  one-shot dispatch under `OUT_NULL` (`src/main.cyr:146`) and `thoth gui` is a one-shot mode, so
  "t-ron: policy … unreadable — seam stays absent" and "log: cannot open … — structured logging
  disabled" never reach the operator; the seams degrade closed and `/state` names both. Switching
  them to `note_*` puts them on every `thoth -p` run's stderr too — a cross-surface decision,
  deferred (the window's notice row could carry them — a cut of the F7 arc if decided).
- **What a stop cannot reach (0.52.0)** — Esc stops a command only where a wait loop hands control back. A Windows
  capture is one blocking wait inside `lib/process_win.cyr` (it still ends at its deadline; the lane is closed
  anyway); line mode's streaming `/run` gives the child the terminal (unchanged since before F7); and a blocking
  network call — `daimon_invoke`, a non-streaming round, `hoosh_health_probe` — is a socket read with no poll in it,
  so the window is not pumped during one (bounded by `[hoosh].timeout_ms`). A pumped network wait needs the
  transport to return between reads.
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
  config example); two sessions trusting the same host at once are last-writer-wins on that host's
  rows; schema key order is part of the hash (a reordering server reads as changed — withheld, never
  allowed; canonicalise if a real one appears); the mode claim holds on POSIX only (AGNOS's create
  mode and Windows's ACL — the floor rows).
- **Memory double read — the last case** — a `~/.thoth/` reached by the root walk from below that
  holds fact files but **no `MEMORY.md`** and no `config.cyml` gives no bytes to recognise, so it is
  returned as the project root AND as the global layer: every fact injected twice. Kept over the
  other failure (a dropped global layer is silent; the double read is only waste); `$PWD` alone
  must never make the claim. Closes if the memory layer ever writes an index on first use.
- **Streaming usage** — every streaming request carries `stream_options.include_usage`; hoosh
  2.6.10 meters a stream by the reservation, so the token/cost row is not fed there and `[budget]`
  cannot be enforced on that path (`[hoosh].stream = false` is the way round). The request STAYS
  (decided 0.45.5): thoth's decode is in place, and the row lights up the release hoosh ships the
  frame — the hoosh row above.
- **Input-history hardening** — a fresh `[history].file` is created `0600` on POSIX and (0.51.3) opened
  with `O_NOFOLLOW`, so a symlinked file is refused rather than followed; a pre-existing looser file is
  still never re-tightened (the `chmod` floor row: never assert a mode thoth cannot enforce). The
  tool-pin store takes the same bit.
- **macOS** — builds, runs and passes its native suite at the pin; the T2 TUI does not run there:
  `term_raw` returns -1 (the darshana row), so thoth takes the line tier. When the BSD peer lands,
  `src/term.cyr`'s macOS branch collapses into the forwarder and nothing above it changes.
- **Windows lane** — blocked outside thoth's authored source. `scripts/build.sh` names two classes
  separately: **architectural** (`SYS_SOCKET` / `SYS_CONNECT` — permanent; the epoll set is in the
  pattern but no longer surfaces at 6.6.3; the lane gates closed, announced) and **vendored** (`VENDOR_GAP`: t-ron's signal half, sit's `sit_rmdir`).
  The PE capture inherits thoth's environment, so `[hooks]` reports "could not run" there and a
  `pre_tool` denies. `is_symlink` is a no-op on Windows, so the jail's symlink walk and the toolpin
  store's link refusal are too (the floor row). `TTY_SIGMASK_WINCH` stays off **every** list on
  purpose — a new raw `tty_*` call in thoth source turns the lane red, the regression tripwire.
- **The `shell` deny/allow filter is a coarse pre-filter and says so** — a real sandbox is F12
  (kavach), a feature, not a repair. `cyrius fmt --check`'s 12 complaints are one deliberate
  convention (aligned trailing-comment continuations) — advisory in thoth, not reformatted.

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
