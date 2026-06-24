# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.7.0 (UNRELEASED — HELD)** — `/audit` tool-rounds + parallel-tool-calls floor
blockers filed, landed in-tree 2026-06-23. **The 0.7.0 release is held until parallel
tool calls also land** (gated on the filed sandhi + bayan reentrancy repairs); 0.7.0
will ship both together. Two agentic-loop follow-ups scoped. **Landed:** `/audit` now surfaces a
session-local trace of the agentic loop's tool **rounds** (new module
`src/roundlog.cyr`) — grouped by turn/round with `[allow|deny|noname] <tool> ok|err`
per call — alongside (and independent of) t-ron's canonical libro chain, so it
renders even when t-ron is absent. **Deferred:** real parallel tool execution is
blocked at the stdlib floor (sandhi dispatch globals + bayan parser global cursor,
both vendored `lib/`, both single-threaded by design); a 3-lens adversarial audit
confirmed UNSAFE, both gaps **filed upstream** (sandhi + bayan), and thoth's piece
is fully designed to drop in once the floor is repaired — no dead scaffolding
shipped. 221 assertions (+22, `test_roundlog`). Pin unchanged (6.2.37).
**0.6.7** — cross-target re-verification of the 6.2.37 floor + getrandom root cause,
2026-06-23: re-ran `./scripts/build.sh all` on x86_64 Linux. Two symbols the gated
lanes hit are **fixable upstream bugs, not capability gaps** (correcting an earlier
"known gap" misread): **Windows `SYS_GETRANDOM`** — Windows HAS ProcessPrng via the
`sys_getrandom()` wrapper; patra issued a raw Linux `syscall(SYS_GETRANDOM,…)`, **fixed
in patra v1.12.4**; and **AGNOS `SIGHUP`** — agnos signal infra is DONE
(`sigprocmask`#17/`signalfd`#18), the peer just omits the signal-number constants,
**filed**. AGNOS's old `SYS_LSEEK` blocker is RESOLVED (agnos peer now has it). aarch64
re-confirmed building; macOS not re-run (Mac host). `scripts/build.sh` gap set split
into `ARCH_GAP` (permanent: futex/epoll) vs `TRANSIENT_GAP` (getrandom/SIGHUP). No
thoth runtime source change; 199 assertions. Pin unchanged (6.2.37).
**0.6.6** — toolchain refresh to Cyrius 6.2.37, 2026-06-23: the source pin moves
6.2.15 → **6.2.37** (`lib/` re-synced via `cyrius lib sync` — 98 floor modules,
two new snapshot modules `protobuf`/`yantra`; no thoth source change), clearing the
drift warning. 199 assertions (unchanged); x86_64 Linux builds + ships as before.
Cross-target re-verification of the new floor landed in 0.6.7 (above).
**0.6.5** — M6 capability ladder (effect dimension), 2026-06-16: the seam registry
gains the **full / degraded / absent capability-effect** dimension on top of the
existing native/remote-client/absent **binding mode** — two orthogonal axes, the
second not inferable from the first. `seam_cap_state` derives the effect from live
binding status; **t-ron** is the defining case (binding `native→absent`, effect
`full→degraded` — the fail-closed confirm gate, never silent-allow). `/seams` now
renders both axes + the live effect line; computed, not narrated, so doc and binary
can't drift. New [architecture note 002](../architecture/002-capability-ladder.md).
199 assertions (+12). Pin unchanged (6.2.15).
**0.6.4** — toolchain refresh + aarch64 lane lights up, 2026-06-16: the source
pin moves 6.1.38 → **6.2.15** (`lib/` re-synced via `cyrius lib sync`, 97 floor
modules; no thoth source change), clearing the drift warning. The **aarch64 Linux**
target now **builds** (`build/thoth_aarch64`, a valid statically-linked ARM ELF) —
the cycc `#pure`/aarch64 pass-1 scanner gap that blocked it closed upstream in
Cyrius **v6.2.2**, so the lane lights up with zero thoth change. AGNOS stays blocked
on `SYS_LSEEK` — now **filed upstream**
(`agnos/.../2026-06-16-cyrius-patra-lseek-syscall-gap.md`), with a second gap
(`SYS_FUTEX`, patra's mutex) behind it. Windows now surfaces `SYS_FUTEX` first
(Win uses `WaitOnAddress`); `scripts/build.sh` recognizes it as a sanctioned
best-effort gap. 187 assertions (unchanged). Pin **6.2.15**.
**0.6.3** — multi-target builds (M6) + per-tool input schemas, 2026-06-12:
`scripts/build.sh` is the build driver that fans one source tree to targets
(`linux`|`agnos`|`all`); **x86_64 Linux ships** as a named target (`build/thoth`).
The **AGNOS** target is staged but blocked **upstream** — `patra` needs
`SYS_LSEEK`, absent from the AGNOS syscall floor (6.1.38→6.2.0); announced, never
faked. Also: daimon **1.2.7** emits `inputSchema` per MCP tool, so
`agent_format_tools` passes it through verbatim as the model's
`function.parameters` instead of a permissive `{"type":"object"}` guess — the
model now sees each tool's real argument shape (closing daimon issue
`2026-06-11-mcp-manifest-omits-tool-input-schema`; backward-compatible).
187 assertions. Pin 6.1.38 at the time. See [ADR-0008](../adr/0008-multi-target-builds.md).
NB superseded by 0.6.4: the cycc `#pure`/aarch64 pass-1 scanner fix landed in
Cyrius v6.2.2 and aarch64 now builds; macOS remains a Mac-host build.
**0.6.2** — model catalog, 2026-06-12: `/models` asks the hoosh gateway for its
catalog (GET `/v1/models`, OpenAI-compatible) and lists every model id, marking
the session's active routing target — the mid-session `/model` switch now has a
menu, not a guess. Catalog is hoosh's domain; thoth only asks. Seam absent →
honest degradation (like `/tools`). Pin unchanged (6.1.38). 186 assertions (+6);
bound + absent paths live-verified.
**0.6.1** — agentic streaming, 2026-06-11: the agentic loop streams via SSE when
`[hoosh].stream` is on — content live, `tool_calls` assembled from fragmented
deltas. Closes the 0.6.0 edge where wiring daimon disabled streaming. Pin
unchanged (6.1.38). 180 assertions; both stream/block paths live-verified.
**0.6.0** — agentic tool-calling loop, 2026-06-11: free-text turns become a loop —
thoth advertises daimon's MCP tools to hoosh, the model calls them, thoth executes
each through daimon (t-ron-gated), feeds results back, repeats until the model
answers. The M4 vision realized; unblocked by daimon 1.2.6. `[hoosh].tools`
(default on). Pin unchanged (6.1.38). 176 assertions; loop live-verified on the
happy and policy-deny paths.
**0.5.2** — structured logging, 2026-06-11 (unblocked polish): thoth logs its own
driver events (`event=… key=value` via the vendored sakshi logger) — turns,
authz verdicts, model switches, session start. Off by default (`[log]` opt-in);
operational, distinct from t-ron's `/audit` chain. Toolchain pin unchanged
(6.1.38). 163 assertions; logging live-verified to a file.
**0.5.1** — multi-turn context, 2026-06-11 (unblocked polish): free-text turns
carry prior exchanges so the model has conversation memory — a bounded,
byte-budgeted window (`/reset` clears it, `[hoosh].history=false` reverts to
stateless). Plus a routine toolchain refresh to Cyrius **6.1.38** (floor-only
`lib/` churn, no source change). 148 assertions; multi-turn live-verified.
**0.5.0** — streaming + audit, 2026-06-11 (unblocked polish, no milestone gate):
hoosh turns **stream the completion (SSE)** as it is generated — each delta
printed as the frames arrive, `[hoosh].stream=false` reverts to blocking; and
**`/audit`** surfaces t-ron's in-process, libro-backed audit chain (counts,
tamper-check, agent risk score, recent gated actions). Toolchain pin unchanged
(6.1.37). 131 assertions; both live-verified end-to-end. Multi-turn → 0.5.1.
**0.4.1** — toolchain refresh, 2026-06-11 (Cyrius 6.1.34 → 6.1.37; `lib/`
re-synced. Forced by a cycc 6.1.37 guarded-`include` behavior change that fired
the 6.1.34 sigil's redundant `src/sha_ni.cyr` include and broke the build; the
6.1.37 sigil drops it. No thoth source change; 105/105 still pass).
**0.4.0** — the avatara seam, 2026-06-11 (roadmap M5: avatara binds native via a
vendored dist bundle; the Thoth/Librarian persona is sourced from the archetype
(`egyptian_thoth()`) and threaded into the hoosh system prompt — **all five
spine seams now wired**).
**0.3.0** — the M4 tool spine, 2026-06-11 (daimon remote-client; bote + t-ron
native via vendored dist bundles; one fail-closed authorization choke point).
**0.2.1** — toolchain + hoosh refresh, 2026-06-11 (Cyrius 6.1.32 / the bayan
stdlib migration; seam re-verified against hoosh 2.4.5). **0.2.0** — the hoosh
seam, 2026-06-10 (roadmap M3: inference + mid-session model switch). First real
release was **0.1.0**, 2026-06-09 (M2: the driver core). Scaffolded 2026-06-08
via `cyrius init`.

thoth uses **SemVer `0.x`** through its pre-1.0 phase
([ADR-0004](../adr/0004-semver-pre-release.md)) — this supersedes the earlier
"CalVer at first release" note. The post-1.0 scheme is deferred.

## Posture

thoth wires **all five seams** (since 0.4.0), and a free-text turn drives the
**model-driven agentic tool-calling loop** (0.6.0) on top of them. hoosh (M3) is
**remote-client**: turns route to a backing model and switch mid-session through
the inference gateway over sandhi. M4 adds the tool spine: **daimon remote-client** (the MCP
host — `/tools` lists its registry, `/call` invokes a tool), **bote native**
(the vendored bote-core bundle IS the MCP protocol, in-process), and **t-ron
native** (the vendored authorization engine gates `/run`, `/write`, and
`/call` through one choke point — deny is final, no policy means the
fail-closed confirm prompt). M5 adds **avatara native**: the vendored archetype
bundle (avatara 2.7.1) supplies the Thoth/Librarian persona in-process — sourced
from `egyptian_thoth()` via the `prof_*` accessors and threaded into the hoosh
`{role:system}` message so the precision-0.95 scribe archetype steers the turn,
not just the banner. Unconfigured capabilities (no hoosh/daimon url, no t-ron
policy) still degrade honestly; nothing is faked. See
[ADR-0006](../adr/0006-m4-tool-spine-daimon-bote-tron.md) and
[ADR-0007](../adr/0007-m5-avatara-seam-native-persona-system-prompt.md).

The hoosh seam binds only when `thoth.cyml` declares `[hoosh].url` — no endpoint
declared, no remote claim. Verified end-to-end against a live gateway (a turn
routed to a real provider; a mid-session `/model` switch re-routed Anthropic →
OpenAI in one session) — wired against hoosh 2.2.2, re-verified at **hoosh
2.4.5** (0.2.1); the `/v1/chat/completions` contract is unchanged across that
span. See [ADR-0005](../adr/0005-hoosh-seam-remote-over-sandhi.md).

The settled identity (recorded so code doesn't entrench the wrong shape):
thoth is OS-agnostic in its reach and AGNOS-sovereign in its spine, and the
two never collide because they govern different layers.

- **Substrate (OS-agnostic floor).** Below thoth sit syscalls, allocation,
  argv, process spawn, and terminal I/O. Cross-OS support here is already
  structurally present in the vendored Cyrius stdlib (see
  [Toolchain](#toolchain)) behind one stable interface — a posture thoth
  ratifies, not infrastructure it must invent. thoth writes against the
  portable interface and picks the target at build time; it never writes
  against a per-OS file.
- **Capability spine (AGNOS-sovereign ceiling).** Above thoth sits the
  capability spine — model routing / mid-session switching, agent
  orchestration + MCP tool execution + host registry, the MCP protocol,
  per-tool authorization, and the Thoth / Librarian archetype overlay.
  thoth owns **no domain logic of its own**; it owns its place in the stack
  precisely by **consuming** that spine rather than reimplementing any part
  of it.

The framing is "everywhere capable, AGNOS canonical": portability owns the
floor (it always runs), AGNOS owns the ceiling (it runs best — the whole
spine is native, co-resident, and sandboxed end to end), and the gap is an
explicit, documented contract. Off AGNOS, thoth runs the **same** spine
reached as a client over a portable transport, capability-gated; where a
service is unreachable the matching feature degrades honestly and is
announced to the user — never faked, never reimplemented in-tree. Security
degrades **closed** (absent per-tool authorization means a conservative
built-in deny/prompt, never a silent allow). The bright line: **port the
floor; never fork the spine.**

## Toolchain

- **Cyrius pin**: `6.2.37` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc`. **0.6.6** took 6.2.15 → 6.2.37 — a toolchain refresh:
  `cyrius lib sync` re-synced 98 floor modules (two new snapshot modules,
  `protobuf` and `yantra`); floor-only churn, no thoth source change, 199
  assertions unchanged. **0.6.4** took 6.1.38 → 6.2.15 — a toolchain refresh:
  `cyrius lib sync` re-synced 97 floor modules (incl. new `*_agnos` peer-splits and
  the expanded `tls_native_*` set from the 6.2.7 agnos-completeness pass); floor-only
  churn, no thoth source change, 187 assertions unchanged. This is the refresh that
  lit up aarch64 (the cycc `#pure`/pass-1 scanner fix landed in v6.2.2). History
  (each matching the then-installed `cycc`): 0.2.1 took 6.1.23 → 6.1.32 with the 6.1.25 bayan
  data-domain carve; 0.3.0 took 6.1.33 — dep-resolver CVE hardening; 0.4.0 was on
  6.1.34, no stdlib migration; **0.4.1** took 6.1.34 → 6.1.37 — forced by a cycc
  guarded-`include` behavior change that fired sigil's redundant `src/sha_ni.cyr`
  include; the 6.1.37 sigil drops it. The re-sync touched only the
  transport/crypto floor — `sigil`, `sandhi`, `tls`, `tls_native`, `ws`,
  `syscalls_{windows,x86_64_agnos}` — no stdlib API migration, no thoth source
  change. **0.5.1** took 6.1.37 → 6.1.38 — a routine refresh, floor-only churn
  (`alloc`, `alloc_agnos`, `atomic`, `str`), again no source change). M5 added
  the **`math`** stdlib dep (the vendored avatara bundle's
  `f64_le`/`f64_ge`) and re-synced `lib/` to the pin via `cyrius lib sync`
  (88 modules).
- **Multi-OS substrate present in the vendored stdlib** (`lib/`), behind one
  stable interface:
  - syscalls — `syscalls_x86_64_agnos`, `syscalls_x86_64_linux`,
    `syscalls_aarch64_linux`, `syscalls_macos`, `syscalls_windows`
    (plus `syscalls_linux_common`)
  - alloc — `alloc_agnos`, `alloc_macos`, `alloc_windows`
  - args — `args_agnos`, `args_macos`, `args_win`
  - process — `process_agnos`, `process_win` (the `/run` shell escape rides
    this portable surface)

  AGNOS is the primary target; Linux, macOS, and Windows are capability-gated
  reach targets.

## Targets (build matrix)

The one source tree fans out to targets at **build time** via the build driver
`scripts/build.sh` (`linux` | `win` | `aarch64` | `agnos` | `all`); no per-OS
source. Cross-target lanes re-verified at 0.6.6 (Cyrius 6.2.37) on this x86_64
Linux host; the macOS lane was last verified 0.6.4 (its native Mach-O build needs a
Mac host) — see [ADR-0008](../adr/0008-multi-target-builds.md):

| Target | Flag | Status | Output |
|---|---|---|---|
| x86_64 Linux | _(default)_ | **shipped** — built, tested (199), released | `build/thoth` |
| aarch64 Linux | `--aarch64` | **builds** (re-verified 0.6.6 / Cyrius 6.2.37) — valid static ARM ELF, not yet ARM-run-tested | `build/thoth_aarch64` |
| macOS (arm64) | `macos` _(Mac host)_ | **builds + runs** natively (verified 0.6.4 on Apple Silicon; not re-run at 6.2.37); audit path gated upstream | `build/thoth_macos` |
| AGNOS (x86_64) | `--agnos` | **staged** — old `SYS_LSEEK` blocker RESOLVED; now gated on `SIGHUP` (agnos signal infra DONE, peer just omits signal-number consts — **filed**, fixable) | `build/thoth_agnos` |
| Windows | `--win` | **staged** — `SYS_GETRANDOM` is **fixed** (patra v1.12.4, transient lag); genuine remaining gaps are `SYS_FUTEX` + epoll (Win32 architectural) | `build/thoth.exe` |

**aarch64 (unblocked since 0.6.4, re-verified 0.6.6):** `cyrius build --aarch64`
produces a valid statically-linked ARM ELF (`file` → `ELF 64-bit … ARM aarch64`;
exec-format error on the x86 host confirms it's genuinely cross). It had been
blocked on a cycc `#pure`/aarch64 pass-1 scanner bug (filed
`cyrius/.../2026-06-12-main-aarch64-pass1-missing-annotation-tokens-unexpected-enum`),
**resolved upstream in Cyrius v6.2.2**. Cross-built here; running it on real ARM
hardware is a host-side step.

**AGNOS block (upstream, not thoth) — the lseek gap RESOLVED at 6.2.37:** the
old blocker (`patra.cyr` → `SYS_LSEEK`, the filed
`agnos/.../2026-06-16-cyrius-patra-lseek-syscall-gap.md`) is **closed** — the 6.2.37
agnos peer `syscalls_x86_64_agnos.cyr` now defines `SYS_LSEEK = 58` (and
`SYS_GETRANDOM = 45`). `cyrius build --agnos` now advances past patra and fails
later, in vendored `src/vendor/t-ron.cyr:3436`, on **`SIGHUP`**. This is **not**
"AGNOS has no signals": the agnos peer already defines `SYS_SIGPROCMASK=17` /
`SYS_SIGNALFD=18` with wrappers (signal infra DONE per agnos `syscall-additions.md`),
and t-ron's `sighup_init` uses exactly those. The peer merely omits the signal-NUMBER
constants (`SIGHUP`, … — defined `SIGHUP=1 … SIGPWR=30` on the linux/macos/aarch64
peers), so the bare `SIGHUP` literal can't resolve. A **fixable floor gap, filed**:
`agnos/.../2026-06-23-cyrius-agnos-peer-missing-signal-number-constants.md` (the agnos
ABI owner should confirm the numbers rather than have it guessed). Behind it sit
`SYS_FUTEX`/epoll. The lane lights up once the agnos peer gains the signal enum.

**Windows: `SYS_GETRANDOM` was a patra bug (now fixed), NOT a Win32 gap.** Windows
has a CSPRNG — `bcryptprimitives!ProcessPrng`, wired as the `sys_getrandom()` peer
wrapper. patra's `_wal_gen_salts` drew its WAL salts via a raw
`syscall(SYS_GETRANDOM,…)` — a Linux-shaped call the Windows peer deliberately omits
the constant for — so `--win` failed to link. **Fixed in patra v1.12.4**
(`src/wal.cyr`, `#ifdef CYRIUS_TARGET_WIN` → `sys_getrandom()`; verified: patra builds
`--win`, 834 Linux tests still pass). thoth's `--win` lane clears the moment the
toolchain re-bundles patra ≥1.12.4. The genuine, **architectural** Windows gaps remain
`SYS_FUTEX` (patra's mutex; Win uses `WaitOnAddress`) and the sandhi/epoll set (IOCP) —
by-design Win32 differences with no raw-syscall equivalent. `scripts/build.sh` now
separates these `ARCH_GAP`s from the transient `SYS_GETRANDOM`/`SIGHUP` lag.

**macOS (builds + runs, audit path gated upstream):** built natively on an Apple
Silicon host (Cyrius emits Mach-O there; cross-emit from Linux is not the path),
`./scripts/build.sh macos` produces `build/thoth_macos` (Mach-O arm64) which
launches the REPL and exits cleanly — **verified 0.6.4** (not re-run at 6.2.37:
the native Mach-O build needs the Mac host, and the 0.6.6 cross-pass ran on
x86_64 Linux). cycc emits ~86 "syscall
not routed by the Mach-O ARM translation (ESYSXLAT/__got)" warnings: the
`var SYS_*; syscall(SYS_*,…)` first arg doesn't const-fold, so the reroute misses
(upstream cyrius issue `2026-06-16-var-syscall-number-defeats-macho-pe-reroute`).
The basic driver path is fine; patra's `lseek`/`futex` (t-ron's audit ledger) will
fault at runtime once a `[tron].policy` is configured, until that cycc fix lands.

## Source

The driver core (M2), the hoosh seam (M3), and the tool spine (M4):

- `src/main.cyr` — entry; includes the modules callee-first, runs
  `config_load` + `gate_init` then the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers (incl. M4's
  `/tools` and `/call`; **0.5.0:** `/audit`, `/state` shows the stream mode;
  **0.5.1:** `/reset`, `/state` shows the multi-turn context + count; **0.6.0:**
  free-text turns route to the agentic loop when `agent_enabled`, `/state` shows
  the agent mode; **0.6.2:** `/models` lists the hoosh gateway's catalog).
- `src/seams.cyr` — the capability-seam registry; statuses fully dynamic. **0.6.5
  (M6 ladder):** adds the **capability-effect** dimension (`CapState`
  full/degraded/absent) on top of the binding mode — `seam_cap_state` derives it
  from live status (t-ron degrades closed, never absent), `seam_cap_full` /
  `seam_cap_fallback` carry the prose; `cmd_seams` renders both axes. See
  [architecture note 002](../architecture/002-capability-ladder.md).
- `src/session.cyr` — session state (incl. the copy-on-set model) + the avatara
  persona overlay (**M5**: `persona_*` sourced from `egyptian_thoth()` via the
  `prof_*` accessors; `persona_system_prompt()` builds the soul+spirit+operating
  clause once). **0.5.1 (multi-turn):** the capped conversation history
  (`session_history_*` — append/accessors/pop/clear; stable content copies).
- `src/roundlog.cyr` — **0.7.0**: the session-local agentic tool-**round** trace
  `/audit` surfaces. A ring (last 16 rounds) of `{turn, round, calls[]}` with each
  call's verdict (`allow`/`deny`/`noname`) + ok/err; recorded by the agentic loop
  (`roundlog_open`/`roundlog_add_call`), rendered by `roundlog_report`, cleared by
  `/reset`. Display-only loop-structure view, orthogonal to and independent of
  t-ron's security chain — owns no security logic, never touches the libro chain.
- `src/config.cyr` — `thoth.cyml` runtime config (`[hoosh]`, **M4:**
  `[daimon]` url, `[tron]` policy/agent; **0.5.0:** `[hoosh].stream`
  bool via a `_cfg_bool` reader; **0.5.1:** `[hoosh].history`; **0.5.2:**
  `[log].file` / `[log].level`).
- `src/log.cyr` — **0.5.2**: structured driver-event logging over the vendored
  sakshi logger. `log_init` binds to `[log]` (off unless configured); the pure
  `event=… key=value` builder (`log_begin`/`log_kv_str`/`log_kv_int`/`log_message`)
  + `_log_parse_level` + the level-gated `log_commit`. Instruments `gate.cyr`
  (authz verdicts), `hoosh.cyr` (turn results), `commands.cyr` (model switch).
- `src/hoosh.cyr` — **M3**: the hoosh seam client (request build, sandhi POST,
  response/error extraction). **M5**: `hoosh_build_request` takes a `system`
  param; `hoosh_send` passes the avatara persona as a `{role:system}` message.
  **0.5.0:** SSE streaming — `hoosh_build_request` gained a `stream` param;
  `_hoosh_stream_turn` + `_hoosh_sse_cb` print `hoosh_extract_delta` deltas as
  the frames arrive (default on, `[hoosh].stream=false` reverts to blocking).
  **0.5.1 (multi-turn):** `hoosh_build_messages` + `_hoosh_history_start`
  serialize the byte-budgeted conversation tail; `_hoosh_blocking_turn` extracted;
  both turn paths leave the reply in `_hoosh_acc` for history; `HOOSH_REQ_CAP`
  raised to 256 KiB. **0.6.2 (catalog):** `hoosh_list_models` GETs `/v1/models`
  and prints the catalog (`_hoosh_models_url` builds the endpoint, pure
  `hoosh_extract_models` returns the `data` array).
- `src/daimon.cyr` — **M4**: the daimon seam client (MCP host registry list,
  tool call build/POST, MCP tool-result extraction). **0.6.0:** `daimon_invoke`
  (invoke + return result as a cstr) and `daimon_tools_value` (fetch the tool
  array) for the agentic loop.
- `src/agent.cyr` — **0.6.0**: the model-driven agentic tool-calling loop.
  Advertises daimon's tools to hoosh (`agent_format_tools`), parses `tool_calls`
  (`agent_tool_calls`/`agent_tc_*`/`_agent_raw_tool_calls`), assembles each
  request (system + budgeted history + ephemeral tool rounds + `tools`), and
  drives the loop (`agent_turn`) — each tool call t-ron-gated, results fed back as
  `{role:tool}`, capped at `AGENT_MAX_ITERS`. `agent_enabled` gates on
  daimon-wired + `[hoosh].tools`. **0.6.1:** streams via SSE when `[hoosh].stream`
  is on (content live; `tool_calls` assembled from fragmented deltas by index, via
  `_agent_accum_delta`/`_ag_build_array`); per-iteration split into
  `_agent_iter_stream`/`_agent_iter_block` with a shared outcome.
- `src/gate.cyr` — **M4**: the t-ron authorization choke point (`gate_init` /
  `gate_authorize`) + the fail-closed `confirm` fallback. **0.5.0:**
  `gate_audit_report` surfaces t-ron's libro-backed audit chain (counts,
  integrity, risk score, recent events) for the `/audit` command; the pure
  `audit_kind_str` verdict-label is thoth's only glue over it.
- `src/exec.cyr` — the portable local shell escape for `/run`.
- `src/util.cyr` — buffered stdin `read_line`, `emit`, small helpers.
- `src/vendor/` — committed spine dist bundles. **M4**: `bote-core.cyr`
  (bote 2.7.3, the MCP protocol), `t-ron.cyr` (t-ron 2.1.5, authorization),
  `libro.cyr` (libro 2.7.2, t-ron's audit chain). **M5**: `avatara.cyr`
  (avatara 2.7.1, the Thoth/Librarian archetype). Re-sync via
  `scripts/sync-{bote,tron,libro,avatara}.sh`; never hand-edit.

Binary: ~2.6 MB (`build/thoth`, x86_64-linux) — the sandhi/TLS transport
surface plus the four vendored spine bundles dominate (most of the avatara
bundle is DCE-unreachable).

## Tests

- `tests/thoth.tcyr` — **199 assertions** over the pure logic: M2's
  `classify_input`, `token_is` / `arg_after`, the seam registry, session state,
  `cstr_starts_with`; M3's JSON escaping, chat-request building,
  response/error extraction, config defaults, and the copy-on-set model
  switch; M4's daimon call building + MCP result extraction, t-ron verdicts
  through the real vendored engine (allow/deny globs, deny-by-default unknown
  agent/tool — doubling as the libro `chain_append` SIGILL canary), and the
  `[daimon]`/`[tron]` config defaults; M5's persona group (identity sourced from
  the avatara archetype, soul/spirit prose, the built system prompt) and the
  hoosh request-shape cases (no system preserves the prior shape, empty system
  omitted, non-empty system prepended as `{role:system}`); and **0.5.0's**
  audit group — three real `tron_check` calls then asserting the logged
  event/denial counts, the libro chain length + integrity, newest-first
  ordering, and the pure `audit_kind_str` label; and **0.5.0's** streaming
  group — the `stream:true` request shape, `hoosh_extract_delta` across
  content/role-only/finish/`[DONE]` frames, and the `[hoosh].stream` toggle
  through the real TOML parser; and **0.5.1's** multi-turn group — history
  append/accessors + the stable-copy guarantee, pop/clear, the drop-oldest cap,
  `_hoosh_history_start` budgeting, and the `hoosh_build_messages` shape; and
  **0.5.2's** logging group — the structured `event=… key=value` builder (incl.
  null-value `-` and negative ints), the `_log_parse_level` cases, and the
  `[log]` config defaults / `log_active`-off; and **0.6.0's** agentic group —
  tool advertisement formatting, `tool_calls` parsing (id/name/arguments + the
  no-calls case), the raw tool_calls extractor, the agentic request shape,
  `agent_enabled` gating, and (**0.6.1**) the streamed delta assembly (fragmented
  `arguments` reassembled, re-parsed through the same accessors); and **0.6.5's**
  capability-ladder group — the effect-state resolver (vendored seams full,
  hoosh/daimon absent unconfigured, t-ron degrades closed not absent), the
  `cap_state_label` cases, and the full/fallback prose semantics. Passes on
  `cyrius test`.
- `tests/thoth.bcyr` — benchmark stub (no-op).
- `tests/thoth.fcyr` — fuzz stub.

## Dependencies

**Current (declared in `cyrius.cyml`, all stdlib).** Driver core: `string`,
`fmt`, `alloc`, `io`, `vec`, `str`, `slice`, `syscalls`, `result`, `tagged`,
`process`, `assert`, `bench` (`result` / `tagged` / `process` back the
portable `/run` shell escape). Data formats: **`bayan`** — the Cyrius 6.1.25
data-domain carve (json / toml / cyml / base64 / bigint / u128 / csv in one
distlib fold); it carries both the `thoth.cyml` config surface (with `fs`)
and the JSON wire format, and must precede `sigil` (u256) and the transport.
Call sites use the canonical `bayan_*` names. M3 hoosh transport: **`sandhi`**
(the HTTP/TLS client, folded into stdlib as `lib/sandhi.cyr`) plus its full
transitive set — `net`, `http`, `tls`, `ws`, `sakshi`, `sigil`, `args`,
`hashmap`, `thread`, `thread_local`, `fnptr`, `async`, `atomic`, `chrono`,
`mmap`, `dynlib`, `fdlopen`, `freelist`, `ct`, `keccak`. (`sakshi` arrived as a
sandhi transitive; **0.5.2** consumes it directly for thoth's structured driver
log — `src/log.cyr`.) M4 vendored-bundle
surfaces: `regex` (t-ron's policy `glob_match`), `random` (sigil's ML-DSA /
AES-GCM refs), `patra` (libro's structured logging). M5 vendored-bundle surface:
`math` (the avatara bundle's `f64_le`/`f64_ge`; the other f64 ops are builtins).
**Ordering constraint
(M4):** `atomic`/`thread`/`thread_local`/`ct`/`keccak`/`random` must precede
`sigil`, or libro's `chain_append` SIGILLs (sigil's hash path self-installs a
per-thread scratch bank) — t-ron 2.1.5's documented note, now thoth's too.
Libs are opt-in and Cyrius does **not** resolve transitive deps, so the set
is declared by hand and ordered low-level-floor-first (see the `[deps]`
comment in `cyrius.cyml`).

**sandhi fix pending toolchain fold (2026-06-24).** The toolchain-bundled
sandhi **1.6.12** (cyrius 6.2.39) carries a critical client bug: the server and
client conn structs both defined `enum SandhiConnOff` with the symbol
`SANDHI_CONN_OFF_FD` at different offsets (client 8 / server 16). Under cyrius
last-definition-wins the client resolved it to 16, colliding with its own
`SANDHI_CONN_OFF_TLS_CTX` — `finalize` zeroed the socket fd, so every hoosh
request went to fd 0 (terminal echo / `CONNECT`) and the gateway saw nothing.
Fixed in **sandhi 1.6.13** (server offsets namespaced to `SANDHI_SRVCONN_OFF_*`;
see sandhi `docs/development/issues/2026-06-24-server-conn-off-fd-collision.md`).
thoth stays on the **stdlib** `"sandhi"` entry (pristine `lib/`); the temp
workaround — pin `[deps.sandhi]` `tag = "1.6.13"` `modules = ["dist/sandhi.cyr"]`
— is **held**: the sandhi 1.6.13 tag isn't pushed yet, and a `[deps.sandhi]`
block perturbs thoth's hand-ordered stdlib set (breaks `patra`'s `SK_WARN`
resolve). **Action at cyrius 6.2.40:** once 6.2.40 folds sandhi 1.6.13 into the
toolchain bundle, keep the stdlib `"sandhi"` style and drop any temp
`[deps.sandhi]` pin — i.e. revert dep-style → stdlib-style. Until then thoth
builds against the buggy 1.6.12 (hoosh roundtrip broken on a fresh build).

**Vendored (committed dist bundles in `src/vendor/`, not `[deps]` blocks):**
bote-core **2.7.3**, t-ron **2.1.5**, libro **2.7.2** (t-ron's audit chain;
keep in lockstep with t-ron's own `[deps.libro]` pin), avatara **2.7.1** (the
Thoth/Librarian archetype; needs the `math` stdlib dep, carries a benign
`ERR_NONE = 0` matching libro's and a self-contained `xalloc`). bote's and
t-ron's manifests declare git sub-deps that `cyrius deps` resolves
transitively into colliding compile sets, so the self-contained bundles are
consumed directly — the pattern hoosh established (avatara likewise ships a
`cyrius distlib` bundle, not a server). Re-sync via
`scripts/sync-{bote,tron,libro,avatara}.sh <tag>`.

**Spine seams.**

- **hoosh** — LLM inference gateway: **wired (remote-client over HTTP via
  sandhi)**. Consumed as a running gateway, not a linked crate (hoosh ships no
  distlib — it is a server). Re-verified at hoosh **2.4.5**; its 2.2.3–2.4.5
  growth (tool calling, batch, `/v1/tools/*` MCP endpoints, DLP, observability,
  17 providers, configurable routing strategy) is server-side or M4+ seam
  material — the chat contract thoth consumes is unchanged. See
  [ADR-0005](../adr/0005-hoosh-seam-remote-over-sandhi.md).
- **daimon** — agent orchestration + MCP tool execution + host registry:
  **wired (remote-client over HTTP via sandhi)** when `[daimon].url` is
  declared. `/tools` lists the registry, `/call` invokes. **Re-verified
  wire-compatible against daimon 1.2.6** (2026-06-11), which ships the fix for
  the registry-aliases-request-buffer bug thoth filed. 1.2.6's `GET
  /v1/mcp/tools` returns the manifest `{"tools":[{name,description}],"count":N}`
  (thoth parses, ignores `count`) and `POST /v1/mcp/call` passes the upstream MCP
  `result` through (`content[0].text` + `isError`); both match thoth's seam — no
  code change needed. Round-trip confirmed against a 1.2.6-faithful mock (real
  daimon's server binary won't run inside thoth's build sandbox — signal 16 — so
  full-stack live e2e is a host-side step).
- **bote** — the MCP protocol: **wired (native — vendored bote-core 2.7.3,
  in-process)**.
- **t-ron** — MCP per-tool authorization: **wired (native — vendored t-ron
  2.1.5 + libro 2.7.2, in-process)** when `[tron].policy` loads; otherwise
  absent with the fail-closed confirm gate standing in, announced. Deny is
  final; unknown agents/tools deny by default.
- **avatara** — personality / archetype overlay; the Thoth / Librarian persona:
  **wired (native — vendored avatara 2.7.1, in-process)**. The persona is sourced
  from `egyptian_thoth()` (the `prof_*` accessors) and threaded into the hoosh
  system prompt; native by construction (always available from the bundle). See
  [ADR-0007](../adr/0007-m5-avatara-seam-native-persona-system-prompt.md).

The off-AGNOS reach transport vs. the AGNOS-native binding distinction is
deferred to a later ADR.

## Known limitations (0.6.1)

- All five seams are wired; no seam is absent by milestone. The avatara persona
  is a fixed archetype (`egyptian_thoth`), not runtime-switchable, and reached
  only as the vendored bundle — the live/co-resident avatara binding is the same
  deferred reach-transport question as the other native seams.
- t-ron's bundle carries a benign `ERR_NONE = 0` shared with libro's identical
  constant (same value; last definition wins) — re-check on bundle bumps.
- **daimon registry bug — RESOLVED in daimon 1.2.6** (was 1.2.4): the MCP host
  registry aliased the transient request buffer, corrupting registrations as
  later requests arrived. Filed by thoth as
  `daimon/docs/development/issues/2026-06-11-mcp-registry-aliases-request-buffer.md`;
  fixed upstream (daimon commit `6af75a4`). thoth's seam is re-verified
  wire-compatible with 1.2.6 (see the daimon seam note above). Full-stack live
  e2e (thoth → t-ron → real daimon → bote MCP → back) is a host-side step —
  daimon's server binary won't run inside thoth's build sandbox (signal 16).
- thoth is **not** exposed to the cyrius address-taken-local-array static-overlap
  bug daimon hit in 1.2.6 (its `docs/.../cyrius-addr-taken-local-array-static-overlap`):
  that needs an 8-byte-slot `var a[N]` written at its last slot via `store64(&a…)`;
  thoth's address-taken locals (`tmp[24]`, `line[4096]`, `ans[64]`) are byte
  buffers written via `store8` within bounds. Re-check if a `store64(&local…)`
  is ever introduced.
- t-ron's bundle duplicates sigil's `chacha20_xor` (same signature and
  semantics; last definition wins) — benign per t-ron's own 2.1.5 notes, but
  worth re-checking on sigil bumps since sigil's TLS ChaCha20 path now runs
  t-ron's copy.
- t-ron authorization is per-tool name + payload scan; the model-driven turn
  (`free text` → hoosh) is not a gated action (it executes nothing locally).
- hoosh responses **stream by default** (**0.5.0**): SSE deltas print as
  they arrive (`[hoosh].stream=false` reverts to the blocking round-trip). One
  asymmetry: the streaming result exposes the HTTP status but not the body, so a
  non-2xx *error message* is only surfaced in blocking mode — streaming announces
  the status and points the user at `stream=false`.
- The hoosh request carries the avatara persona as a `{role:system}` message
  (M5) and (**0.5.1**) the multi-turn conversation tail (`[hoosh].history`,
  default on; `/reset` clears it). Remaining fixed bits: `max_tokens` 4096 and no
  other request tuning. Context is a byte-budgeted window (oldest turns drop) held
  in-process only — not persisted across runs. `[hoosh].history=false` reverts to
  the stateless single-turn shape.
- t-ron audit events live in its in-process libro ring; **0.5.0's** `/audit`
  surfaces them (counts, chain integrity, agent risk score, recent events). The
  audit view is read-only and session-scoped (the ring is in-process, not
  persisted across runs). **0.5.2** adds thoth's own **sakshi-structured driver
  log** (`[log]`, off by default; `event=… key=value` for turns, authz verdicts,
  model switches) — operational, distinct from t-ron's cryptographic chain. It
  covers the driver event spine but not yet every command (`/read`, `/tools`,
  `/call` results are not logged); broaden as needed.
- `/read` is read-only but unrestricted; sandboxing posture stays with t-ron,
  not an in-tree allowlist.
- `/write` takes single-line content; multi-line editing is future work.

## Consumers

_None yet._

## Next

See [`roadmap.md`](roadmap.md). All five seams are wired; the polish backlog
(streaming/audit/multi-turn/logging, 0.5.0–0.5.2) is cleared; and **0.6.0** lights
up the **model-driven agentic tool-calling loop** (daimon 1.2.6 unblocked it) —
the M4 vision realized: hoosh decides, t-ron gates, daimon executes, results loop
back. The current milestone is **M6** — OS-agnostic build targets and the honest
capability-ladder / feature-gate matrix. **x86_64 Linux ships** (0.6.3, via
`scripts/build.sh` + [ADR-0008](../adr/0008-multi-target-builds.md)); AGNOS,
macOS, Windows, and aarch64 are staged, each blocked on a named upstream gap
(AGNOS `SYS_LSEEK`; the cycc `#pure`/aarch64 pass-1 scanner fix, filed; a Windows
epoll equivalent) and lighting up with zero thoth change once its gap closes. The
per-capability ladder matrix is still owed. Smaller follow-ups on the agentic
loop: **streaming
landed in 0.6.1** (content live + tool_calls assembled from deltas); **richer
per-tool JSON Schemas landed in 0.6.3** — daimon **1.2.7** now emits `inputSchema`
per tool (its manifest gap, filed as daimon issue
`2026-06-11-mcp-manifest-omits-tool-input-schema`, is closed), and
`agent_format_tools` passes it through verbatim as `function.parameters` (tools
with none fall back to `{"type":"object"}`). Remaining — parallel tool calls and
surfacing tool rounds in `/audit`. Full-stack live e2e of the loop against **real** daimon
is a host-side step (daimon's server won't run in thoth's build sandbox — signal
16, confirmed repeatedly; thoth's seam is verified wire-compatible with 1.2.6's
actual code + responses, and the loop against faithful mocks of that wire).
