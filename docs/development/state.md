# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

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

thoth 0.4.0 wires **all five seams**. hoosh (M3) is **remote-client**:
turns route to a backing model and switch mid-session through the inference
gateway over sandhi. M4 adds the tool spine: **daimon remote-client** (the MCP
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

- **Cyrius pin**: `6.1.38` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc` (0.2.1 took 6.1.23 → 6.1.32 with the 6.1.25 bayan
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
- `src/seams.cyr` — the capability-seam registry; statuses fully dynamic.
- `src/session.cyr` — session state (incl. the copy-on-set model) + the avatara
  persona overlay (**M5**: `persona_*` sourced from `egyptian_thoth()` via the
  `prof_*` accessors; `persona_system_prompt()` builds the soul+spirit+operating
  clause once). **0.5.1 (multi-turn):** the capped conversation history
  (`session_history_*` — append/accessors/pop/clear; stable content copies).
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

- `tests/thoth.tcyr` — **180 assertions** over the pure logic: M2's
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
  `arguments` reassembled, re-parsed through the same accessors). Passes on
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
back. The next milestone is **M6** — OS-agnostic build targets and the honest
capability-ladder / feature-gate matrix. The M6 doc half (the reach-transport ADR
+ the ladder) is design-ready; the cross-build half is blocked on upstream Cyrius
stdlib / AGNOS-ABI gaps. Smaller follow-ups on the agentic loop: **streaming
landed in 0.6.1** (content live + tool_calls assembled from deltas); remaining —
richer per-tool JSON Schemas (**daimon-gated**: daimon 1.2.6 stores an
`input_schema` but its manifest omits it and registration hardcodes `{}` — filed
as daimon issue `2026-06-11-mcp-manifest-omits-tool-input-schema`; thoth
advertises a permissive `{"type":"object"}` until daimon emits `inputSchema`, then
passes it through as `function.parameters`), parallel tool calls, and surfacing
tool rounds in `/audit`. Full-stack live e2e of the loop against **real** daimon
is a host-side step (daimon's server won't run in thoth's build sandbox — signal
16, confirmed repeatedly; thoth's seam is verified wire-compatible with 1.2.6's
actual code + responses, and the loop against faithful mocks of that wire).
