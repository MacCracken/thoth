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
> grouped below into numbered repair batches, each pinned to the next `0.45.x`; **minors are held for
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
- **Minors are feature arcs.** `0.46.0` is the first feature added after this cut, whichever is decided;
  a minor is never a sweep of small things — those are patches.
- **Upstream repairs re-vendor as their own patch** the release after the dependency ships, each with a
  line-anchored needle in `tests/cases/vendor.cyr` ([`../doc-health.md`](../doc-health.md) lesson 1: a
  documented residual is a claim with an expiry date — every waiting item below names the version it
  was last checked against, and a release re-checks them).

## Scheduled work

> Repair batches are pinned. Feature arcs are listed as candidates and stay unpinned until one is
> decided — the pin lands here with the decision. Everything *identified* but not committed lives in
> [`gap-review.md`](gap-review.md).

### Repair batch 1 → 0.45.5 (thoth-owned, no dependency)

In priority order. Each item's detail is in the registry below.

1. **File content prints raw on `/read`, the tree pane's Enter and `/git <path>`** — take the TEXT
   policy (newlines and tabs kept, other C0 and DEL as `?`) at the three sinks. The decision is what
   was missing; the policy and its sanitiser already exist (0.45.0). A cloned repository is untrusted
   and one Enter in the tree pane runs a file's escape in the operator's terminal — the only ⛔ in
   this batch. [registry → *content escapes*]
2. **The memory double read with no global `config.cyml`** — the MEMORY.md byte witness: compare
   `<root>/memory/MEMORY.md` against `$HOME/.thoth/memory/MEMORY.md` with `_cfg_same_bytes` as a
   second byte source in `_thoth_root_home_verdict` (same level rule, same `$PWD` veto, its own cap).
   Test on the tracked fixture home with `_cfg_gpath_c = 0`. [registry → *memory double read*]
3. **`rainbow` tints semantic roles inside the feed** — the t-ron DENY line and the `/reprobe` health
   notice cycle instead of staying red/green once they are role markers. Exempt semantic roles at
   marker expansion; directly painted chrome is already right. [registry → *rainbow*]
4. **Streaming token usage is requested and never sent** — thoth stops asking hoosh (2.6.10) for the
   `stream_options.include_usage` frame it does not emit, keeps `[budget]`'s announcement that the
   streaming path is unmetered, and files the frame against hoosh as the feature it is. [registry →
   *streaming usage*]
5. **Input-history polish** — `~`/`$HOME` expansion on `[history].file` and a `histfilesize`-style trim
   (the file is bounded to the 128-line ring today). [registry → *input-history hardening*]
6. **Owed verification: macOS at the pin** — install the pinned toolchain on the Mac (6.6.2 today; 6.6.3
   after batch 2's refresh) and re-run the native suite there (0.45.2's run used a scratch copy pinned to
   6.6.0). A release step, not code. [registry → *macOS*]
7. **Polish, batched:** the `rainbow` diagonal phase (a per-row hue offset, deterministic so
   `feed_repaint` never shimmers); settle the line-tier fenced-code asymmetry (highlighted at the line
   tier, tinted by the TUI painter) either way; the GUI's on-compositor rainbow re-confirm (headless
   pixel tests cover the rasterizer).

### Repair batch 2 → 0.45.6 (thoth-owned, needs a host or a dep refresh first)

1. **Hook event facts move from argv to the environment.** `[hooks]` prefixes `THOTH_EVENT` /
   `THOTH_TOOL` / `THOTH_ARGS` as quoted assignments to the `/bin/sh -c` string, so up to ~16 KB of
   the model's tool arguments sit in `/proc/<pid>/cmdline` for the hook's life. ⭐ **The "needs a
   portable spawn-with-environment primitive" claim was stale:** `src/exec.cyr` already hands
   `sys_execve` an (empty) `envp` on the POSIX path, and the AGNOS floor has `sys_spawn_path_env`.
   Build the facts into that `envp` (Windows inherits `wenv=0` and needs a built block — gate it to
   the lanes that can carry it, announce where one cannot). [registry → *hook event facts*]
2. **Dep refresh sweep** — the vendored darshana **1.0.0 → 1.1.2**, bote-core **3.3.7 → 3.3.9**, and
   the cyrius pin **6.6.2 → 6.6.3**; re-run every target and read every diff
   (the refresh gotchas: symbol + enum diff, build AND read each target, `cyrius build` rewrites
   `lib/`). A refresh has bitten before (0.38.2's max_tokens regression, 0.44.5's re-measured caps), which is
   why it ships as its own step in the batch — re-run and read, never re-read.
3. **`src/exec.cyr`'s Windows capture takes the exclusive create** — cyrius 6.4.58's reroute honours
   `O_CREAT|O_EXCL`, so the POSIX path's exclusive create + retry loop can be shared; needs the
   Windows host (cass) to run it. [registry → *Windows lane*]

### Waiting on upstream or the floor (repairs owned elsewhere — re-vendor as their own patch)

Each carries the version it was last checked against. A release re-checks the list; a closed item
becomes a re-vendor patch with a line-anchored needle in `tests/cases/vendor.cyr`.

| Owner | What | Checked against | thoth's half |
|---|---|---|---|
| **sit** | ⛔ git read-mode status false positives: every tracked `100755` file and every zero-byte file reads "modified" (14 on a clean tree) | sit **1.6.2** (vendored 1.6.2) | none — `git_probe` copies sit's vec; fix is sit's comparator |
| **hoosh** | ⛔ SSE frames dropped on the Anthropic streaming path: a tool call's `content_block_start` can be lost while its `input_json_delta` fragments still arrive (reproducible from one captured body) | hoosh **2.6.10** | done — 0.44.2 drops and announces such a call |
| **hoosh** | the streaming usage frame (`stream_options.include_usage` / `message_delta.usage` decode — hoosh's own follow-up note) | hoosh **2.6.10** | batch 1 item 4 stops requesting it meanwhile |
| **t-ron** | `_audit_export_event` splices `agent`/`tool`/`reason` unescaped and sizes the buffer flat (`n * 512 + 32`) — a 4000-byte tool name writes past the allocation | t-ron **2.1.10** (vendored 2.1.10) | done — both executors refuse a name over `AGENT_NAME_MAX` before the gate |
| **sit + bote profiles** | the sit `[lib.read]` carve (drops the `cmd_reset` collision and the three `undefined function` warnings every lane prints) and a bote `[lib.jsonx]` micro-profile (233 fns → 7) — warning hygiene only; every capacity argument was retired by measurement at 0.44.5 | neither profile exists upstream | `sync-*.sh` re-vendor when they do |
| **darshana** | a BSD termios peer → the T2 TUI on macOS (`term_raw` honestly returns -1 there today; the line tier is the degradation) | darshana **1.1.2** — macOS still out of its scope | `src/term.cyr`'s macOS branch collapses into the forwarder when it lands |
| **t-ron / sit / cyrius** | the Windows lane's vendored gaps: t-ron's SIGHUP policy hot-reload (`SIGHUP` / `SIG_BLOCK`, zero thoth callers) and sit's `sit_rmdir` against a floor with no `RemoveDirectoryW` route (`xrmdir` is in the floor since cyrius 6.5.2) | t-ron 2.1.10 · sit 1.6.2 · cyrius 6.6.3 | `scripts/build.sh` names them as `VENDOR_GAP`; `TTY_SIGMASK_WINCH` stays off every list as the tripwire |
| **cyrius (floor)** | a portable `chmod`/`fchmod` (tighten a pre-existing history file to `0600`; `sys_chmod` is a return-0 stub on Windows and AGNOS) and a portable no-follow open bit (`O_NOFOLLOW` on the history file) | cyrius **6.6.3** | never assert a mode thoth cannot enforce; documented in `.thoth/config.cyml.example` |
| **agnos (floor)** | `sys_open` carries no create-mode channel — a file created on AGNOS lands at the kernel default, not `0600` | the frozen 0–33 ABI | degrades honestly; a candidate filing if the ABI gains a mode channel |
| **cyrius (floor)** | `is_symlink` returns 0 on Windows, so the jail's symlink walk (audit A-1) is a no-op there — **the PE lane must not ship without revisiting it** | cyrius **6.6.3** | the lane is closed anyway (architectural, below) |
| **AGNOS spine builds** | a current `hoosh_agnos` (on disk: 2.4.11, 2026-07-01, against hoosh 2.6.10) and a `daimon_agnos` beside it — gate 2 rung 2 | hoosh 2.6.10 · daimon 2.1.3 | `scripts/agnos-run.sh` is ready to stage them |

**Permanent by design (not waiting):** the Windows lane's architectural half — `SYS_SOCKET` /
`SYS_CONNECT` (ws2_32) and the epoll set (IOCP). The lane gates closed, announced.

### Feature arcs → minors (0.46.0 and on) — candidates, unpinned until decided

> **Context.** SecureYeoman's chat surface — its TUI *and* the chat pane of its web dashboard — is
> being handed to thoth: thoth's TUI + native T3 GUI become the canonical AGNOS-family chat/coding
> front-end. The rule is the same as the rest of the spine — **CONSUME already-built AGNOS domains
> (mneme, bhava, an audio/voice domain), never reinvent them.** SY's enterprise guardrail stack (t-ron
> is thoth's answer), multi-platform group-chat bridges, and the web-dashboard admin stay **out of
> scope**. Data fields follow **omit-until-present** ([ADR-0010](../adr/0010-data-producer-honest-omit.md)).

- **F1 — GUI slash-command routing** (recommended first: it restores a safety option). Surface
  `/retry`, `/edit`, `/bookmark`, `/thumbs` in the GUI, whose composer runs `cmd_task` directly and
  bypasses `dispatch`. ⚠ 0.44.3 raised its value: the GUI's authorization modal deliberately does NOT
  offer "allow for the whole session", because seeing that a grant is still acting and revoking it
  both live behind `/grants`, which the GUI cannot reach. Routing slash-commands is what lets that
  option come back.
- **F2 — Model-picker reachability, then pricing.** hoosh serves `GET /v1/health/providers`
  (provider, base_url, status, enabled, healthy per route), so reachability can be annotated **now**
  by joining the catalog's `owned_by` against it. Per-model *pricing* still waits on hoosh:
  `/v1/models/catalog` emits only `{id, owned_by}` (a `/v1/cost/estimate` round-trip is the
  alternative).
- **F3 — Reasoning across resume.** Persist a turn's reasoning fold into the conversation store so
  it survives a restart (the `reasonlog` is session-scoped today, like the memory strip).
- **F4 — GUI pointer plumbing.** Mouse click-to-switch on the conversation sidebar (keyboard-only
  today) and re-rendering a resumed conversation's tool/citation data as live feed cards (today it
  round-trips and shows in `/save`; the live cards are session-local).
- **F5 — A lightweight project-map hint** in the system prompt, so the agent gets a cheap directory
  overview without a `list_dir` round-trip.
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

- **Content escapes** (batch 1, item 1) — ⛔ **A file's CONTENT prints raw on `/read`, the tree pane's
  Enter, and `/git <path>` diffs.** 0.45.0 sanitised every PATH these print and `src/commands.cyr`
  records the content as deliberately left alone — it is the file's own text. But the repository is
  not trusted: a cloned repo's file holding an OSC 52 or screen-clearing escape runs in the operator's
  terminal on one Enter in the tree pane. The TEXT policy (newlines and tabs kept, other C0 as `?`)
  closes it, at the cost of showing a file's deliberate escapes as `?`.

- **Memory double read** (batch 1, item 2) — **stays when there is no global `config.cyml`.** 0.45.3
  tells `$HOME/.thoth`, reached by the root walk from below (`~/Repos/<x>` with no project `.thoth/` →
  `../../.thoth`), from a project `.thoth/` by the level at which the config walk met the global file's
  BYTES, with `$PWD`'s depth under `$HOME` as a veto only (`_thoth_root_home_verdict`,
  `src/config.cyr`). With no `~/.thoth/config.cyml` — or one at `_cfg_same_bytes`'s 32 KiB cap — there
  are no bytes, so a `~/.thoth/` holding only `memory/` is still returned as the project root AND
  reported by `memory_global_dir()` as the global layer: every fact injected twice. Kept deliberately
  over the other failure — a dropped global layer is silent, the double read is only waste — and `$PWD`
  alone must never make the claim (display-grade; tested against). Reproduce: the fake-`$HOME` pty run
  in the 0.45.3 CHANGELOG entry with the global config removed and `[memory]` enabled from a legacy
  `./thoth.cyml` — `/dry` sends the fact 2×.

  **Closure — the memory INDEX bytes.** The identity question is the memory store's own, so its own
  file can answer it: identical `MEMORY.md` bytes are the same file seen from below or a verbatim
  copy, and for the INDEX the copy case is exactly the waste the flag exists to prevent — the same
  bytes injected twice — whereas a copied config says nothing about the stores beneath it. Residuals
  to state, not hide: a store with fact files but no `MEMORY.md` gives no signal (the double read
  stays there); a copied index over DIFFERENT fact files would fold two stores into one and lose the
  global's facts, which is what the `$PWD` veto is for; and the index needs its own byte cap (it can
  outgrow the config's 32 KiB while `MEMORY_SYS_CAP` only ever injects its first 4 KiB). One more
  read pair at root resolution, no new primitive.

- **`rainbow`** (batch 1, items 3 and 7) — all three tiers cycle per grapheme and are reachable.
  Remaining: the painter tints every glyph in the ring, so chrome routed *into* the feed (the t-ron
  DENY line, the `/reprobe` health notice) cycles instead of staying red/green — once both are role
  markers the painter cannot tell a notice from prose; exempting semantic roles at marker expansion
  fixes it (directly painted chrome — status bar, tree, prompts — is unaffected). Polish: the hue is a
  pure function of COLUMN, so every row shares one gradient — a per-row offset gives the classic
  diagonal, but must stay deterministic or `feed_repaint` shimmers; the GUI's on-compositor
  re-confirm; fenced code at the line tier stays syntax-highlighted (the TUI painter tints it), an
  asymmetry to settle either way.

- **Streaming usage** (batch 1, item 4; hoosh row above) — **thoth asks hoosh for streaming token
  usage that hoosh never sends.** Every streaming request carries `stream_options.include_usage`, but
  hoosh (2.6.10) emits no trailing usage frame — its own changelog names the decode as follow-up work —
  so `_hoosh_account_usage` waits for something that never arrives on the streaming path. `[budget]`
  says so (it cannot be enforced there; `[hoosh].stream = false` is the way round), but the token/cost
  row is still not fed while streaming.

- **Input-history hardening** (batch 1, item 5; the floor rows above) — the opt-in `[history].file`
  is best-effort-secured today (a fresh file is created `0600` on POSIX; degrade-closed — an unwritable
  path or a mid-session write failure is announced). Residuals, documented in
  `.thoth/config.cyml.example` + `src/inhist.cyr`: tightening a pre-existing, looser file to `0600`
  needs a portable `chmod`/`fchmod` wrapper (never silently re-tighten, never assert a mode thoth
  cannot enforce); `O_NOFOLLOW` on the open needs a portable no-follow bit (the AGNOS `AO_*` bridge
  defines none) — until then, "keep it in an owner-only directory"; `~`/`$HOME` expansion and a
  `histfilesize`-style trim are thoth's own (batch 1).

- **macOS** (batch 1, item 6; darshana row above) — **builds and runs, and its native test suite is
  green** (Apple Silicon, macOS 26.6.2, at 0.45.2: the Mach-O arm64 binary builds with no undefined
  symbol and `cyrius test` passes in full there — `shell`, `[hooks]` and `[verify]` included). ⚠ Owed:
  a native run AT the pin — the Mac has the **6.6.0** toolchain against a **6.6.2** pin. The build
  prints 26 "syscall not routed by the Mach-O ARM translation" warnings, none from a raw syscall in
  thoth's own `src/` (swept at 0.45.2). **The T2 TUI does not run on macOS and is not meant to yet:**
  `term_raw` returns -1 there (darshana has no BSD termios peer and 0.44.3 does not invent one — a stub
  pretending to work is worse than an honest refusal), so thoth takes the line tier, the already-coded
  degradation. When darshana ships the peer, `src/term.cyr`'s macOS branch collapses into the
  forwarder branch and nothing above it changes.

- **Hook event facts** (batch 2, item 1) — **sit in the child's argv.** `[hooks]` passes `THOTH_EVENT`,
  `THOTH_TOOL`, `THOTH_ARGS` as quoted `VAR='...'` assignments prefixed to the `/bin/sh -c` string.
  The quoting is correct — no tool argument can close it and append a command — but the assignments
  are part of the child's **argv**, so on Linux up to ~16 KB of the model's tool arguments are
  readable through `/proc/<pid>/cmdline` for the life of the hook. Not a new risk class — a hook is
  already an unsandboxed command the operator chose — but a real one. The envp channel is already in
  `src/exec.cyr` (see batch 2).

- **Windows lane** (batch 2, item 3; the vendored-gap row above) — **blocked purely outside thoth's
  authored source.** 0.44.3 took its reachable undefined functions from 11 to 1 and removed
  `TTY_SIGMASK_WINCH`, `EPOLL_CTL_ADD` and `EPOLLIN` from thoth's own code entirely; `scripts/build.sh`
  names the three remaining classes separately instead of letting one mask the others —
  **architectural** (`SYS_SOCKET` / `SYS_CONNECT`, the epoll set; permanent, the lane gates closed,
  announced), **vendored** (`VENDOR_GAP`: t-ron's signal half, sit's `sit_rmdir`), and thoth's own
  exclusive create in `exec.cyr` (batch 2). `TTY_SIGMASK_WINCH` stays off **every** list on purpose,
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
