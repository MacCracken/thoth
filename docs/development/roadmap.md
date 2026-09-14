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
>
> **How the rest is cut (0.45.4):** **repairs batch into patch releases** — the defects thoth owns are
> grouped below into numbered repair batches, each pinned to the next patch of the current minor (`0.45.5`,
> `0.45.6`, `0.50.1`, …); **minors are held for
> feature arcs** — a new capability earns `0.46.0`, `0.47.0`, …, never a polish sweep. Defects owned
> upstream or by the floor wait, with the version to re-check, and re-vendor as their own patch when
> the dependency ships.

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

1. **AGNOS lane — BUILD cleared, and the ELF now RUNS. ✓** The `--agnos` lane compiles a valid
   statically-linked x86_64-AGNOS ELF with **no unresolved symbol on any reachable path**, and
   zero thoth source change. The **runtime** half is no longer open: `./scripts/agnos-run.sh`
   boots the real AGNOS kernel under QEMU and thoth loads and runs in ring 3.
   **Status: build ✓ · runtime ✓ (2026-09-04) · remaining end-to-end work is gate 2.**

   ⭐ **This gate said the ELF "cannot be exercised on a Linux host" and that was wrong.** It is
   true that a Linux *process* cannot run an AGNOS-ABI binary — but AGNOS ships a QEMU harness
   that boots the real kernel, and it has NAMED thoth since before this gate was written
   (`agnos/scripts/smoke/basestack-run-smoke.sh`: *"Reusable across aegis/bote/phylax/hoosh/thoth"*).
   Nothing in thoth's tree said so, so the claim was re-read for releases instead of re-run —
   the exact failure [`../doc-health.md`](../doc-health.md) lesson 1 exists to catch. Measured
   2026-09-04 on the ~5.4 MB `build/thoth_agnos`: gnoboot + OVMF boot the kernel, exec-from-disk
   streams the ELF off ext2, `elf_load` maps it, ring-3 code reaches `write(1)`, thoth's own version
   string appears on the serial console, `run: exit 0`, no fault. Verified non-vacuous by breaking
   it: a deliberately wrong expect-string makes the same harness FAIL. Re-run at every release —
   `scripts/agnos-run.sh` derives the expected string from `VERSION`, so it cannot pass on a stale
   binary.

   ⚠ Read the lane's output correctly before calling a regression: it prints three
   `undefined function` warnings (`load_signing_seed`, `sign_commit_body`,
   `verify_commit_body`) and one `duplicate fn` warning (`cmd_reset`).
   The three sign symbols are **dead-path placeholders from the vendored sit read bundle**,
   documented as such in `scripts/sync-sit.sh`; they arrived when sit was first vendored at
   0.13.x, *after* this gate's build half cleared at 0.12.3. They are expected output, not a
   gate failure. Clearing them is the vendor-carve item below.

2. **At least one downstream consumer green on AGNOS (end-to-end gate).** Read as three rungs,
   because collapsing them is what let this gate sit as "needs an AGNOS host" while a host was
   next door:

   - **Rung 1 — thoth loads and runs in ring 3. ✓ PROVEN 2026-09-04.** `./scripts/agnos-run.sh`
     (a wrapper around AGNOS's own `basestack-run-smoke.sh` — we shell out to it, we do not
     vendor it: a runner for AGNOS is AGNOS's domain). Reproducible in ~90s on any host with
     QEMU + OVMF + a built gnoboot.
   - **Rung 2 — a real turn against the spine, staged on the same image.** Open. Needs a
     current `hoosh_agnos` (the one on disk is 2.4.11, from 2026-07-01, against hoosh 2.6.10)
     and a daimon beside it. This is the rung that actually satisfies the gate's wording.
   - **Rung 3 — the interactive TUI over agnsh.** Open, and the least urgent.

   **Status: rung 1 ✓ · rungs 2–3 blocking · owner: thoth (NOT external).** The old status read
   *"owner: external · needs an AGNOS host"*; that assigned thoth's own work to nobody and
   sequenced the rest of v1.0 behind a blocker that did not exist.

3. **Security review pass (process gate) — RE-PINNED to its actual residual.** Two of this
   gate's three named areas were swept by the 0.39.0 P(-1) audit
   ([`../audit/2026-08-24-audit.md`](../audit/2026-08-24-audit.md) — six parallel auditors,
   each finding handed to an independent skeptic, 26 filed / 17 confirmed / 11 fixed, closing
   with a coverage table against the first-party standards checklist): the **fail-closed
   posture** and the **t-ron authorization choke point** are both covered there.
   ⚠ That audit predates the GUI's authorization path (0.44.3 — the `ask_user` modal answering
   `confirm`, [ADR-0020](../adr/0020-ask-user-the-tool-that-runs-toward-the-operator.md)), which grants
   authority; the sign-off should read it too.

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

**Satisfied on Linux**; **AGNOS-buildable AND AGNOS-runnable** (gate 1, both halves ✓ — the ELF
loads and runs in ring 3, `./scripts/agnos-run.sh`). AGNOS-*green* pends gate 2's rungs 2–3. **Open:**

- [ ] **At least one downstream consumer green on AGNOS** — gate 2, rungs 2–3 (owner: thoth;
      rung 1 — thoth runs in ring 3 — is ✓ as of 2026-09-04)
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

**Batch discipline (0.45.4):**

- **Patches are repair batches.** Known defects, owed verifications, dep refreshes and polish are
  grouped into a numbered batch and shipped together as the next `0.45.x`. A batch is ordered by
  priority; the top of the next batch is the next thing to build. Nothing in a repair batch adds a
  capability.
- **Minors are feature arcs.** `0.46.0` was the first (F1, the GUI's slash-command routing), `0.47.0`
  the second (F2, the picker's provider health + pricing), `0.48.0` the third (F3, reasoning across resume),
  `0.49.0` the fourth (F4, GUI pointer plumbing + resumed cards), `0.50.0` the fifth (F5, the project-map
  hint); `0.51.0` is decided (F6, durable tool-definition pins). A minor is never a sweep of small things — those
  are patches.
- **Upstream repairs re-vendor as their own patch** the release after the dependency ships, each with a
  line-anchored needle in `tests/cases/vendor.cyr` ([`../doc-health.md`](../doc-health.md) lesson 1: a
  documented residual is a claim with an expiry date — every waiting item below names the version it
  was last checked against, and a release re-checks them).

## Scheduled work

> Repair batches are pinned. Feature arcs are listed as candidates and stay unpinned until one is
> decided — the pin lands here with the decision. Everything *identified* but not committed lives in
> [`gap-review.md`](gap-review.md).

### Repair batch 1 → shipped as 0.45.5

Items 1–7 shipped (see the [CHANGELOG](../../CHANGELOG.md)); the one residual each left is in the registry:
the double read still stays for a store with no `MEMORY.md`; item 4 was decided the OTHER way (thoth keeps
requesting the usage frame — see *streaming usage* below); the GUI's on-compositor rainbow confirm is the
operator's (no display in the harness). **Up next: batch 2.**

### Repair batch 2 → shipped as 0.45.6

Items 1–3 shipped (see the [CHANGELOG](../../CHANGELOG.md)): hook facts in the environment block (the PE lane
reports "could not run" until its capture can carry one), darshana 1.1.2 / bote-core 3.3.9 / cyrius 6.6.3 with
`lib/` at the pin, the Windows exclusive create verified on cass.

### Repair batch 3 → shipped as 0.50.1

The `thoth gui` dispatch-order gap closed (see the [CHANGELOG](../../CHANGELOG.md)): the window binds
`[history].file` + `.size` and saves its submits, the greeting box's `input history` row on both surfaces, the
session hooks fire for the window (a card only when the hook printed), git re-probed after a turn, no OSC-0 title
escape from the window, `/reload` applies `[history].size`, `/history` names the bound path cleaned. **The next
batch gathers from the registry below as repairs surface; nothing thoth-owned is pinned at the moment.**

### Waiting on upstream or the floor (repairs owned elsewhere — re-vendor as their own patch)

Each carries the version it was last checked against. A release re-checks the list; a closed item
becomes a re-vendor patch with a line-anchored needle in `tests/cases/vendor.cyr`.

| Owner | What | Checked against | thoth's half |
|---|---|---|---|
| **sit** | ⛔ git read-mode status false positives: every tracked `100755` file and every zero-byte file reads "modified" (14 on a clean tree) | sit **1.6.2** (vendored 1.6.2) | none — `git_probe` copies sit's vec; fix is sit's comparator |
| **hoosh** | ⛔ SSE frames dropped on the Anthropic streaming path: a tool call's `content_block_start` can be lost while its `input_json_delta` fragments still arrive (reproducible from one captured body) | hoosh **2.6.10** | done — 0.44.2 drops and announces such a call |
| **hoosh** | three asks from F2: the serving ROUTE per catalog entry (a `base_url` or route index beside `owned_by` in `/v1/models/catalog`, so a model joins to ITS route's health instead of its kind's fold); a pricing-table dump (a `GET` that lists `pricing_lookup` for every catalog key) so the picker / `/models` rows can price from hoosh's numbers instead of the operator's `[pricing.<model>]`; and `/v1/health/providers` emitting `base_url` unescaped (`handlers.cyr`, the raw `add_cstr`) | hoosh **2.6.10** | done — 0.47.0 folds per kind (`degraded` when routes disagree), prices from the operator's table, and treats an unparseable health body as "unavailable" |
| **hoosh** | the streaming usage frame (`stream_options.include_usage` / `message_delta.usage` decode — hoosh's own follow-up note; the issue text to file is in the 0.45.5 CHANGELOG entry) | hoosh **2.6.10** | thoth keeps requesting it and already decodes it (0.45.5 decided) — the row lights up when hoosh ships the frame |
| **t-ron** | `_audit_export_event` splices `agent`/`tool`/`reason` unescaped and sizes the buffer flat (`n * 512 + 32`) — a 4000-byte tool name writes past the allocation | t-ron **2.1.10** (vendored 2.1.10) | done — both executors refuse a name over `AGENT_NAME_MAX` before the gate |
| **sit + bote profiles** | the sit `[lib.read]` carve (drops the `cmd_reset` collision and the three `undefined function` warnings every lane prints) and a bote `[lib.jsonx]` micro-profile (233 fns → 7) — warning hygiene only; every capacity argument was retired by measurement at 0.44.5 | neither profile exists upstream | `sync-*.sh` re-vendor when they do |
| **darshana** | a BSD termios peer → the T2 TUI on macOS (`term_raw` honestly returns -1 there today; the line tier is the degradation) | darshana **1.1.2** (vendored 1.1.2 at 0.45.6) — macOS still out of its scope | `src/term.cyr`'s macOS branch collapses into the forwarder when it lands |
| **t-ron / sit / cyrius** | the Windows lane's vendored gaps: t-ron's SIGHUP policy hot-reload (`SIGHUP` / `SIG_BLOCK`, zero thoth callers) and sit's `sit_rmdir` against a floor with no `RemoveDirectoryW` route (`xrmdir` is in the floor since cyrius 6.5.2); and, since 0.45.6, a spawn that carries an environment BLOCK (the PE capture inherits; `[hooks]` reports "could not run" there) | t-ron 2.1.10 · sit 1.6.2 · cyrius 6.6.3 | `scripts/build.sh` names them as `VENDOR_GAP`; `TTY_SIGMASK_WINCH` stays off every list as the tripwire |
| **cyrius (floor)** | a portable `chmod`/`fchmod` (tighten a pre-existing history file to `0600`; `sys_chmod` is a return-0 stub on Windows and AGNOS) and a portable no-follow open bit (`O_NOFOLLOW` on the history file) | cyrius **6.6.3** | never assert a mode thoth cannot enforce; documented in `.thoth/config.cyml.example` |
| **agnos (floor)** | `sys_open` carries no create-mode channel — a file created on AGNOS lands at the kernel default, not `0600` | the frozen 0–33 ABI | degrades honestly; a candidate filing if the ABI gains a mode channel |
| **cyrius (floor)** | `is_symlink` returns 0 on Windows, so the jail's symlink walk (audit A-1) is a no-op there — **the PE lane must not ship without revisiting it** | cyrius **6.6.3** | the lane is closed anyway (architectural, below) |
| **AGNOS spine builds** | a current `hoosh_agnos` (on disk: 2.4.11, 2026-07-01, against hoosh 2.6.10) and a `daimon_agnos` beside it — gate 2 rung 2 | hoosh 2.6.10 · daimon 2.1.3 | `scripts/agnos-run.sh` is ready to stage them |

**Permanent by design (not waiting):** the Windows lane's architectural half — `SYS_SOCKET` /
`SYS_CONNECT` (ws2_32) and the epoll set (IOCP). The lane gates closed, announced.

### Feature arcs → minors (0.51.0 and on) — candidates, unpinned until decided

> **Context.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard — is
> being handed to thoth: thoth's TUI + native T3 GUI become the canonical AGNOS-family chat/coding
> front-end. The rule is the same as the rest of the spine — **CONSUME already-built AGNOS domains
> (mneme, bhava, an audio/voice domain), never reinvent them.** SY's enterprise guardrail stack (t-ron
> is thoth's answer), multi-platform group-chat bridges, and the web-dashboard admin stay **out of
> scope**. Data fields follow **omit-until-present** ([ADR-0010](../adr/0010-data-producer-honest-omit.md)).

- **F1 — GUI slash-command routing — shipped as 0.46.0.** The window routes every slash line through the
  command hub (cards in the feed; `/retry` and `/edit` as turns), the modal offers "yes, for this session"
  again, and `grants N` rides every status bar. Residual: on the PE lane `[hooks]` cannot carry an
  environment block (the waiting table).
- **F2 — Model-picker reachability + pricing — shipped as 0.47.0.** The picker's rows, `/models` and
  `/models <provider>` carry each provider's health as hoosh's prober reports it (`GET /v1/health/providers`,
  the catalog's `owned_by` joined against the route table, folded per KIND: healthy / unhealthy only when every
  enabled route agrees, `degraded (h/n routes healthy)` when they do not, unknown when none was measured) and a
  model's `[pricing.<model>]` rate. Pricing came from the operator's own table — the one thoth has priced costs
  from since 0.10.3 — because hoosh (2.6.10) serves no pricing table (`POST /v1/cost/estimate` answers one model
  per call); when hoosh dumps its table, the rows switch source (the waiting table). Residuals: the catalog names
  a model's provider KIND, not its serving ROUTE, so a kind with partitioned routes reads `degraded` for every
  model of it (the waiting table asks hoosh for the route); hoosh's health `base_url` is emitted unescaped (a
  quote in a route's url breaks the body; thoth then reads "health unavailable"); a remote route's "healthy" is a
  TCP connect, not a valid key.
- **F3 — Reasoning across resume — shipped as 0.48.0.** A reply's reasoning lives ON the message
  (session.cyr `+48`, an `RSN` frame in the store, read by index — the 0.35.3 turn-keyed ring retired), so the
  GUI's thinking fold survives a restart; `thoth gui` binds `[session].file` at last (it never had — the
  window neither loaded nor wrote the store); the greeting box carries the resume row on both surfaces;
  `/save` carries the reasoning (`--json` key, markdown `_thinking:_`). Residuals: the GUI still does not
  bind `[history].file` (composer recall stays in-memory there — a follow-up patch, the registry below);
  a pre-0.48.0 thoth reading a 0.48.0 store loads each `RSN` frame as a "user" record — shown as the operator's
  words, re-sent to the model as a user turn, costing a `SESS_HIST_MAX` slot each, and cemented by that
  binary's first save (downgrade only; a `THOTH-SESSION-3` magic would be worse — an old thoth loads nothing
  and truncates the store on its first save; the 0.48.0 loader skips unknown frames, so the NEXT frame is
  safe).
- **F4 — GUI pointer plumbing — shipped as 0.49.0.** The window binds `wl_pointer` (a sovereign shm arrow
  cursor, click + wheel; motion never queued), the frame records its rectangles so `gframe_hit` resolves a
  click by the numbers it was drawn with: a sidebar row switches the conversation, a tree row selects (a second
  click acts as Enter), the feed/composer take focus, the wheel scrolls the feed. A resumed reply's tool calls
  and cited sources draw as an honest SUMMARY card / row from the message's own persisted set (name, verdict,
  args / titles — no round grouping, ms, diff or grounding verdict, none of which the store holds), and the same
  summary takes over for a live reply once its rounds age out of the roundlog. Residuals: the store keeps at most
  `MSG_TOOL_MAX` (8) calls per reply and no total (a summary cannot say "8 of 23"); the grounding verdict and the
  edit diff are not persisted; the question modal stays keyboard-driven (clicks under it are dropped); no drag /
  right button / double-click semantics; clicks that arrive while the drawn frame is stale (a key or a resize in
  the same batch) are dropped rather than resolved against old geometry; the pointer path is Linux-Wayland
  (aethersafha refused Wayland — the AGNOS window backend is still to come).
- **F5 — A lightweight project-map hint — shipped as 0.50.0.** Every turn's system prompt carries a map of
  the launch root (the top two levels: directories first in byte order, each top-level directory with up to
  a dozen children and `+N more`; search's junk directories, dot-directories and symlinks named but not walked;
  thoth's own files omitted; ≤ 2 KiB with a marker; `[project].map`, default on, a preference), rebuilt at each
  turn, reused by a delegated child, shown by `/dry` and `/state`. Residuals: the effect on `list_dir`
  round-trips was NOT measured live (no model here; the 0.44.1 lesson says measure prose before trusting it —
  count `list_dir` calls per turn in `--logs` with the map on vs off); a root with more than 256 entries maps
  to a notice, not a partial map; the dirs-first order needs one probe per child of every walked directory (up
  to 256 × 256 opens a turn on a wide tree — `dir_list_into` does not surface `d_type`; a stdlib arm that did
  would make the walk one `getdents` per directory); every agentic round re-sends the map's bytes (the same
  bytes each round, which is what provider prefix caching wants).
- **F6 — Durable tool-definition pins — DECIDED for 0.51.0 (gap 3, the maintainer's call at 0.50.1).** The
  0.42.0 pins are session-scoped by design: a definition swapped DURING a session (or across `/reprobe`) is
  withheld and refused; one swapped BETWEEN two runs is accepted as first sight. The arc closes that: pins
  persist in a store thoth writes and must then defend (a security-relevant file — tamper, replace,
  symlink-redirect; an authority key under ADR-0021, global-only), so the next run compares against the last
  one's pins and withholds a changed tool until `/tools trust`. The design pass answers where the store lives,
  what it carries (name → hash, the daimon host, when pinned), how it is verified on load, and what the greeting
  / `/state` / `/tools` say about it; the daimon-owned alternative (pin once for every consumer) is recorded
  as the spine's eventual home, with thoth's store the client-side floor until daimon pins.
- **Gated on another domain's Cyrius port (recorded, not on a numbered arc):** the **bhava**
  sentiment→mood loop (bhava is **2.0.0** and still Rust — consume it when it is ported, never
  reimplement sentiment/mood analysis); **voice / mic** — mic → speech-to-text and read-back — by
  consuming an AGNOS audio/voice domain plus a portable audio-capture substrate.
- **From the gap review, if adopted:** durable tool-definition pins (gap 3, created by 0.42.0's
  session-scoped TOFU), OS-enforced sandboxing of `shell`/`edit` via kavach (gap 1 — the largest
  safety delta; kavach is 3.12.5), network egress control (gap 2), ACP server mode (gap 7), OTLP
  export of the audit trail (gap 5), image input (gap 6), git write operations (gap 8). Each moves
  here with a decision and a pin.

## Carried defects and degradations (the registry)

> The detail behind the batches above. Each entry is either a real defect thoth has not yet fixed
> (**⛔**, all scheduled in a repair batch or waiting on its owner above) or an honest degradation
> gated on an external / substrate primitive. Recorded here so it is not lost in code comments.

- **The compositor is not pumped while a hook or `shell` waits** (recorded at 0.50.1) — `exec.cyr`'s wait loop
  pumps only `_exec_wait_tick` (the TUI's spinner; a no-op off the TUI), never `_gstop_poll`, so for the duration of
  a `pre_tool` / `post_tool` / (since 0.50.1) `session_start` hook or a `shell` tool call the window services no
  Wayland event: Esc and the compositor's close are ignored until the wait ends (bounded by `[hooks].timeout_ms` /
  the shell timeout). A real fix rebinds the wait tick to the GUI's stop-poll — behaviour, not repair: a
  candidate, since `_gstop_poll` raises the interrupt and repaints from inside a foreign wait loop.

- **`gate_init` / `log_init` failure lines are discarded on the `thoth gui` path** (recorded at 0.50.1) —
  main.cyr runs one-shot dispatch under `OUT_NULL` and `thoth gui` is a one-shot mode, so "t-ron: policy … unreadable
  — seam stays absent" and "log: cannot open … — structured logging disabled" (both `emit`) never reach the
  operator; the seams degrade closed and `/state` names both. Switching them to `note_*` would put them on every
  `thoth -p` run's stderr too — a cross-surface decision, deferred.

- **The TUI prints `session_start`'s report to the primary screen** (recorded at 0.50.1) — main.cyr fires the hook
  before `tui_loop` raises the alt screen, so a hook that printed is visible only after exit. A quirk of the fire
  order, harmless; the window shows the same report as a card.

- **The pointer on a live compositor** (residual of 0.49.0) — the decoder, the hit-test, the row resolvers and
  the click/wheel semantics are pinned headless (wire-shaped bytes into `gwl_wl__ptr_decode`; `gframe_build` then
  `gpointer_click`); what no test in the harness can do is move a real mouse over the window: the cursor image
  (a role-less-until-`set_cursor` surface; the arrow is 12×19 unscaled — small on a HiDPI output, like the
  window itself), a click landing on the row it looks like it lands on, and a touchpad's two-finger scroll
  feeling right at `GPTR_WHEEL_GAIN` 4. The operator's eyes close this one (`thoth gui`, Ctrl+K, click).

- **The GUI thinking fold on a live compositor** (residual of 0.48.0) — the fold's survival across a restart is
  pinned by the GUI suite's write → drop → reload → measure/draw test; what no test in the harness can do is open
  the window on a compositor and see the resumed folds drawn. The operator's eyes close this one (`thoth gui`
  with `[session].file` bound, a reasoning model, a restart).

- **Memory double read — the last case** (residual of 0.45.5) — the root walk reaching `$HOME/.thoth` from
  below (`~/Repos/<x>` with no project `.thoth/`) is recognised by the config file's bytes (0.45.3) or the memory
  INDEX's bytes (0.45.5), each at the root's level and under the `$PWD` veto. A `~/.thoth/` holding fact files but
  **no `MEMORY.md`** and no `config.cyml` gives no bytes to recognise, so it is still returned as the project root
  AND reported by `memory_global_dir()` as the global layer: every fact injected twice. Kept deliberately over the
  other failure — a dropped global layer is silent, the double read is only waste — and `$PWD` alone must never
  make the claim (display-grade; tested against). A store without an index is also a store `/remember` never
  wrote to, so the case is rare; it closes if the memory layer ever writes an index on first use.

- **`rainbow` — the on-compositor confirm** (residual of 0.45.5) — the painter keeps semantic spans their
  colour and runs the gradient diagonally (0.45.5); both are pinned by the painter's and the raster's headless
  pixel tests. What no test in the harness can do is watch the GUI on a live compositor; the operator's eyes
  close this one (`thoth gui`, `/theme rainbow`).

- **Streaming usage** (hoosh row above) — **thoth asks hoosh for streaming token usage that hoosh does not
  send yet.** Every streaming request carries `stream_options.include_usage`; hoosh (2.6.10) meters a stream by
  the reservation and names the decode as its own follow-up, so `_hoosh_account_usage` waits on the streaming
  path and the token/cost row is not fed there. `[budget]` says so (it cannot be enforced there; `[hoosh].stream
  = false` is the way round). 0.45.5 decided the request STAYS — it is what hoosh's follow-up will honour and
  thoth's decode is in place and tested — so the row lights up the release hoosh ships the frame, with no thoth
  change. The issue text to file against hoosh is in the 0.45.5 CHANGELOG entry.

- **Input-history hardening** (the floor rows above) — the opt-in `[history].file` is best-effort-secured
  today (a fresh file is created `0600` on POSIX; degrade-closed — an unwritable path or a mid-session write
  failure is announced; `~/` expands and `[history].size` trims since 0.45.5). Residuals, documented in
  `.thoth/config.cyml.example` + `src/inhist.cyr`: tightening a pre-existing, looser file to `0600` needs a
  portable `chmod`/`fchmod` wrapper (never silently re-tighten, never assert a mode thoth cannot enforce);
  `O_NOFOLLOW` on the open needs a portable no-follow bit (the AGNOS `AO_*` bridge defines none) — until then,
  "keep it in an owner-only directory".

- **macOS** (darshana row above) — **builds and runs, and its native test suite is green at the pin**
  (Apple Silicon, macOS 26.6.2; at 0.45.5 with the 6.6.2 toolchain installed there: the Mach-O arm64 binary
  builds with no undefined symbol and `cyrius test` passes in full — `shell`, `[hooks]` and `[verify]`
  included). The build prints its "syscall not routed by the Mach-O ARM translation" warnings, none from a raw
  syscall in thoth's own `src/` (swept at 0.45.2). ⚠ `cyrius test` there exports no `$PWD`, so a test golden
  that assumes a repo lead is wrong on the Mac — the 0.45.5 lesson. **The T2 TUI does not run on macOS and is
  not meant to yet:**
  `term_raw` returns -1 there (darshana has no BSD termios peer and 0.44.3 does not invent one — a stub
  pretending to work is worse than an honest refusal), so thoth takes the line tier, the already-coded
  degradation. When darshana ships the peer, `src/term.cyr`'s macOS branch collapses into the
  forwarder branch and nothing above it changes.

- **Windows lane** (the vendored-gap row above) — **blocked purely outside thoth's authored source.**
  0.44.3 took its reachable undefined functions from 11 to 1 and removed `TTY_SIGMASK_WINCH`,
  `EPOLL_CTL_ADD` and `EPOLLIN` from thoth's own code entirely; `scripts/build.sh` names the remaining
  classes separately instead of letting one mask the others — **architectural** (`SYS_SOCKET` /
  `SYS_CONNECT`, the epoll set; permanent, the lane gates closed, announced) and **vendored** (`VENDOR_GAP`:
  t-ron's signal half, sit's `sit_rmdir`). thoth's own half is done: the capture's exclusive create shipped
  at 0.45.6, verified on cass. What the lane cannot carry yet is an environment block for `[hooks]` (the PE
  capture inherits thoth's environment), so a hook there reports "could not run" and a `pre_tool` denies.
  `TTY_SIGMASK_WINCH` stays off **every** list on purpose,
  so a new raw `tty_*` call in thoth source turns this lane red again — the regression tripwire.
  The classifier collects `undefined function` as well as `undefined variable` (the error cyrius
  actually refuses to emit on), reading the reachable set from the list cyrius prints AFTER its
  "N unreachable fns" note. Audit A-1's residual rides with this lane: `is_symlink` is a no-op on
  Windows, so the jail's symlink walk is too.

- **sit's git read-mode status** (sit row above) — ⛔ **reports false positives** (upstream; thoth is a
  pure consumer). Every tracked mode-`100755` file and every tracked zero-byte file comes back
  "modified" regardless of content: on a tree `git status` calls completely clean, `/git` reports 14
  changed — 13 mode-`100755` `scripts/*.sh` (as `A`) plus the zero-byte `docs/examples/.gitkeep` (as
  `M`), exactly the two predicted classes and no true positives. Reproduced on sit 1.3.5 and 1.6.2.
  `src/git.cyr`'s `git_probe` copies sit's `{path, kind}` vec and compares nothing, so the fix belongs
  in sit's comparator; it inflates `/git`, `/state`'s changed-file count and the file-tree badges.
  sit's CLI cannot reproduce it — `sit status` handles only `.sit/` repos; git read-mode is a
  library-only surface.

- **hoosh drops SSE frames on the Anthropic streaming path** (hoosh row above) — ⛔ upstream, surfaced
  and captured off the wire at 0.44.2: `_emit_anthropic_tool_delta` silently `return 0`s when it cannot
  pull `id`+`name` out of a `content_block_start`, so a tool call's OPENING frame can be dropped while
  its `input_json_delta` fragments are still forwarded — the client receives arguments belonging to a
  call with no name and no id; the same shape also loses a fragment mid-`arguments`. Reproduced
  deterministically by replaying one captured request body; still open at hoosh 2.6.10. thoth drops
  and announces such a call instead of letting it poison the conversation, but the frames are lost.
  (The companion defect — provider errors laundered into an empty 200 stream — is closed on both
  sides: hoosh 2.6.5–2.6.8 forwards them in-stream, thoth shows them since 0.44.4.)

- **t-ron's audit export is unescaped and flat-sized** (t-ron row above) — upstream, surfaced by
  0.42.0's `/audit export`. `_audit_export_event` splices `agent`, `tool` AND `reason` into JSON with
  no escaping (`src/audit.cyr:194`, `:196`, `:202`, unchanged at t-ron 2.1.10) and sizes the whole
  buffer at a flat `n * 512 + 32` (`:216`). The DEFAULT unknown-tool path interpolates the tool name
  into the reason, and `tron_is_safe_identifier` accepts every printable ASCII byte — `"` and `\` pass.
  Measured: a tool named `read"file` makes `/audit export` emit JSON that fails to parse; a 4000-byte
  name writes **3598 bytes past** the allocation. The name is the model's own `function.name`, so this
  is reachable from untrusted model output, and the artifact it corrupts is a SECURITY record. thoth's
  half is done (0.44.4: both executors refuse a name over `AGENT_NAME_MAX` before `gate_authorize`);
  the escaper and length-derived sizing belong in t-ron's next release, then a re-vendor plus a
  line-anchored needle in `tests/cases/vendor.cyr`.

- **AGNOS substrate gap — `sys_open` carries no create-mode channel** (agnos row above). The agnos
  open bridge (`lib/io.cyr`, against the frozen 0–33 ABI) maps `O_*`→`AO_*` but has no permission-mode
  argument, so a file created on AGNOS lands at the kernel default, not `0600`. thoth degrades honestly
  (never asserts a mode it cannot enforce). **Not a v1.0 blocker.**

- **Audit residuals carried from [2026-08-24](../audit/2026-08-24-audit.md)** (all 11 findings fixed
  at 0.39.0): A-1's Windows `is_symlink` no-op (the Windows lane entry); the `shell` deny/allow filter
  is a coarse pre-filter and says so — a real sandbox is gap 1 (kavach), a feature, not a repair; and
  `cyrius fmt --check`'s 12 complaints are one deliberate convention (aligned trailing-comment
  continuations) — advisory in thoth, not reformatted, so the next sweep does not re-litigate it.

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
