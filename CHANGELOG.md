# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Structured driver-event logging** (`src/log.cyr`, `src/config.cyr`): thoth
  now logs its own driver events — turns routed to hoosh, t-ron authorization
  decisions, mid-session model switches, session start — as structured
  `event=<name> key=value` lines through the vendored **sakshi** logger (its
  `[timestamp] [LEVEL]` envelope, zero heap alloc). This is thoth's *operational*
  log, distinct from t-ron's cryptographic audit chain (the `/audit` command):
  sakshi records what the driver did; t-ron records the security verdicts. thoth
  owns no logging domain logic — sakshi owns the envelope/transport/levels;
  `log.cyr` only composes the message and gates it on config.
  - **`[log]` config** (`file`, `level`): **off by default** — logging binds only
    when `[log].file` or `[log].level` is set, so an unconfigured session stays
    quiet (the TUI is uncluttered). `file` appends; with only a `level`, sakshi's
    stderr default applies. `level` is `off|fatal|error|warn|info|debug|trace`
    (default `info`). An unopenable file is announced and logging stays off
    (degraded honestly). `/state` shows the log target.
  - Events: `session_start`; `model_switch model=…`; `hoosh_turn model=… stream=…
    multi=… result=ok|transport_error|http_error [status=…]`; `authz tool=…
    verdict=allow|deny|flag` (or `gate=confirm allow=…` when t-ron is absent).
- **15 new unit assertions (163 total)**: the structured-message builder
  (`log_begin`/`log_kv_str`/`log_kv_int` → `log_message`, incl. null-value `-`
  and negative ints), the level parse (`off`→disabled, each named level, unknown
  → default), and the `[log]` config defaults / `log_active` off-without-init.

## [0.5.1] - 2026-06-11

**Multi-turn conversation context** — the headline: free-text turns now carry
prior exchanges, so the backing model has conversation memory (a bounded,
byte-budgeted window; `/reset` clears it, `[hoosh].history = false` reverts to
stateless). Plus a routine toolchain refresh to **Cyrius 6.1.38**. thoth still
owns no domain logic — it holds the transport-side context window; hoosh owns
the inference. 148 unit assertions pass; multi-turn live-verified end-to-end
(context accumulates across turns, `/reset` clears it, the toggle stays
stateless).

### Added
- **Multi-turn conversation context** (`src/session.cyr`, `src/hoosh.cyr`,
  `src/config.cyr`): free-text turns now carry the prior exchanges, so the
  backing model has conversation memory. `session.cyr` keeps a capped history
  (role + a stable content copy; oldest dropped past `SESS_HIST_MAX`); each turn
  records the user message, sends the whole conversation via the new
  `hoosh_build_messages`, and records the assistant reply on success (rolled back
  on failure so history holds only completed exchanges). The streaming path
  accumulates the SSE deltas (`_hoosh_acc`) so the full reply enters history; the
  blocking path copies the parsed content. The request is **byte-budgeted**
  (`_hoosh_history_start`, budget = `HOOSH_REQ_CAP/8`) so the conversation tail
  can never overflow the request buffer (raised to 256 KiB), always keeping at
  least the newest turn. thoth owns only this transport-side context window —
  hoosh owns the inference.
  - **`/reset` command**: clears the conversation context (fresh start; keeps the
    model id and turn counter), reporting how many messages were dropped.
  - **`[hoosh].history` toggle** (default **true**): `history = false` makes each
    turn stateless (the prior single-turn behavior — lower token use, no memory).
    `/state` shows the context mode + message count.
- **17 new unit assertions (148 total)**: the multi-turn history group
  (append/accessors, the stable-copy guarantee, pop/clear, the drop-oldest cap),
  the request group (`_hoosh_history_start` budgeting + the multi-turn
  `hoosh_build_messages` shape with/without system and stream), and the `/reset`
  classification.

### Changed
- **`HOOSH_REQ_CAP` raised 32 KiB → 256 KiB** (`src/hoosh.cyr`) to hold a
  multi-turn request; the per-turn builder byte-budgets against it.
- **Toolchain: Cyrius 6.1.37 → 6.1.38** (`cyrius.cyml`); `lib/` re-synced via
  `cyrius lib sync` (88 modules). Floor-only churn — `alloc`, `alloc_agnos`,
  `atomic`, `str` — no stdlib API migration, no thoth source change from the bump.
  Clears the 6.1.38 drift warning (pin now matches the installed `cycc`).

## [0.5.0] - 2026-06-11

Two unblocked-polish capabilities land on top of the 0.4.x spine (no milestone,
no upstream gate): **hoosh streaming (SSE)** and **`/audit`**. Turns now stream
the completion as it is generated — thoth prints each delta as the SSE frames
arrive, the natural interactive experience — with `[hoosh].stream = false` as the
blocking escape hatch. `/audit` surfaces t-ron's in-process, libro-backed audit
chain: counts, a tamper-check, the agent risk score, and the recent gated
actions. thoth still owns no domain logic — hoosh streams, t-ron audits; thoth
renders. Toolchain pin unchanged (Cyrius 6.1.37). 131 unit assertions pass; both
features live-verified end-to-end (streaming against a real SSE gateway, `/audit`
against the real vendored t-ron engine). Multi-turn context is deferred to 0.5.1.

### Added
- **hoosh streaming (SSE)** (`src/hoosh.cyr`, `src/config.cyr`): free-text turns
  now **stream the completion as it is generated** — thoth POSTs with
  `"stream":true` and prints each `choices[0].delta.content` as the
  Server-Sent-Events frames arrive (via sandhi's `sandhi_http_stream` + the SSE
  parser; the `[DONE]` sentinel ends the turn). A new pure `hoosh_extract_delta`
  (the streaming sibling of `hoosh_extract_content`) and the `_hoosh_sse_cb`
  event callback do the per-frame work; transport errors and non-2xx still
  degrade honestly (announced, not faked). thoth owns none of the inference —
  hoosh streams, thoth renders.
  - **`[hoosh].stream` toggle** (default **true**): set `stream = false` in
    `thoth.cyml` for a single blocking round-trip (the prior behavior; also the
    only mode that can surface a gateway error *body*, since the stream result
    exposes status but not body). `/state` shows the active mode
    (`… (streaming)` / `(blocking)`). New `config_hoosh_stream` + a `_cfg_bool`
    TOML-boolean reader.
- **`/audit` — surface t-ron's audit chain** (`src/gate.cyr`, `src/commands.cyr`):
  a new command that renders t-ron's in-process, libro-backed audit chain — the
  cryptographic record of every gated action (`/write`, `/run`, `/call`) this
  session. Reports total events, denials, the chain length + a tamper-check
  (`audit_verify_chain`), the agent's rolling risk score (0–100%), and the 10
  newest events (id · verdict · tool · reason, newest first). thoth owns none of
  this: `gate_audit_report` reads t-ron's query API (`query_total_events` /
  `query_total_denials` / `audit_recent` / `risk_score`) and renders; the only
  glue thoth authors is the pure `audit_kind_str` verdict-label. With the t-ron
  seam absent, `/audit` says so plainly — the fail-closed confirm gate keeps no
  cryptographic log — degraded honestly. Closes a `state.md` future-work item.
- **26 new unit assertions (131 total)**: the `/audit` group (a `t-ron audit
  chain` set driving the real vendored engine — three `tron_check` calls then
  asserting event/denial counts, the libro chain length + integrity, newest-first
  ordering — plus the pure `audit_kind_str` cases and the `/audit`
  classification); and the streaming group (the `stream:true` request shape,
  `hoosh_extract_delta` across content/role-only/finish/`[DONE]` frames, and the
  `[hoosh].stream` config toggle through the real TOML parser).

### Changed
- **`hoosh_build_request` gained a `stream` parameter** (`src/hoosh.cyr`):
  signature `(dst, model, system, prompt, stream)`. `stream == 1` emits
  `"stream":true`; anything else preserves the prior `"stream":false` shape.

## [0.4.1] - 2026-06-11

Maintenance release: toolchain **Cyrius 6.1.34 → 6.1.37**. The vendored stdlib
(`lib/`) is re-synced to the 6.1.37 snapshot; thoth's own source is unchanged and
all 105 unit assertions pass without modification. No behavior change.

The bump was forced by a real breakage: cycc 6.1.37 changed how an
`#ifndef`-guarded `include` is handled — it now opens the guarded file even when
the guard symbol is already defined. The 6.1.34 `lib/sigil.cyr` carried a
redundant, guard-skipped `include "src/sha_ni.cyr"` (and `aes_ni.cyr`); under
6.1.37 that include fired and failed (`cannot open include file: src/sha_ni.cyr`),
breaking every build/test on a host with the newer wrapper. 6.1.37's own sigil
snapshot drops the redundant include, so re-syncing `lib/` to the matching pin
resolves it.

### Changed
- **Toolchain: Cyrius 6.1.37** (`cyrius.cyml [package].cyrius`, was 6.1.34).
  `lib/` re-synced via `cyrius lib sync` (88 modules). Only the transport/crypto
  floor moved: `sigil` (the dropped sha_ni/aes_ni includes), `sandhi`, `tls`,
  `tls_native`, `ws`, and the `syscalls_{windows,x86_64_agnos}` variants. No
  stdlib API migration — every `bayan_*` / `sandhi_*` / sigil call site is
  unchanged, so no thoth source touched.
- Version strings and the banner bumped to `0.4.1`.

### Verified
- 105/105 unit assertions on `cyrius test` under 6.1.37; `cyrius build` produces
  a clean ~2.7 MB `build/thoth`. The toolchain-drift warning is gone (pin now
  matches the installed `cycc`).

## [0.4.0] - 2026-06-11

The last absent seam flips (roadmap M5): **avatara** binds **native** as a
vendored dist bundle, in-process — the same vendored-bundle pattern as
bote-core / t-ron / libro. thoth now wires **all five spine seams**. The
Thoth/Librarian persona stops being a hardcoded stub: it is **sourced from the
avatara archetype** (`egyptian_thoth()` via the `prof_*` accessors), and — the
half that matters — its soul + spirit prose is threaded into a leading
`{role:system}` message so the precision-0.95 scribe archetype actually
**steers the backing model**, not just the banner. thoth still owns no domain
logic: avatara owns the archetype; thoth reads the emitted profile and authors
only profile→string glue (ADR-0003).

### Added
- **avatara seam, native** (`src/vendor/avatara.cyr`, avatara **2.7.1**): the
  vendored archetype bundle, consumed in-process. `seam_status(SEAM_AVATARA)`
  reports **native** by construction; `/seams` and `/state` reflect it.
- **Persona sourced from avatara** (`src/session.cyr`): `persona_name` now reads
  `prof_name(egyptian_thoth())`; new `persona_soul` / `persona_spirit` /
  `persona_desc` expose the archetype's emitted prose. The profile is built once
  (lazy, stable bump-heap pointer). The "Librarian" role and the THOTH backronym
  tagline remain thoth's own overlay framing over avatara's Egyptian
  wisdom-scribe archetype — not avatara logic.
- **Persona system prompt** (`src/session.cyr` `persona_system_prompt`): soul +
  spirit + thoth's coding operating clause, built once and cached. Threaded into
  the hoosh request as a `{role:system}` message when the avatara seam is bound;
  absent → omitted (the bare user turn), degraded honestly.
- **`scripts/sync-avatara.sh`**: re-sync the vendored bundle from the
  GitHub-tagged dist (default `2.7.1`), mirroring `sync-{bote,tron,libro}.sh`.
- **12 new unit assertions (105 total)**: a persona group (identity sourced from
  the archetype, soul/spirit prose, the built system prompt) and the hoosh
  request-shape cases (no system preserves the original shape, empty system is
  omitted, a non-empty system is prepended).

### Changed
- **`hoosh_build_request` gained a `system` parameter** (`src/hoosh.cyr`):
  signature `(dst, model, system, prompt)`. A non-empty system emits a leading
  `{role:system}` message; an empty/0 system preserves the prior
  single-user-message shape exactly. `hoosh_send` passes the avatara persona,
  gated on the seam being native.
- **Seam registry**: `SEAM_AVATARA` is now `native` (was `absent`); the
  `seam_status` comment block and `src/session.cyr` / `src/main.cyr` headers
  updated — the persona is an overlay sourced from avatara, no longer a "static
  descriptor".
- **`cyrius.cyml`**: `[deps].stdlib` gained **`math`** (the avatara bundle's
  `f64_le` / `f64_ge`; the other f64 ops are compiler builtins). `lib/` re-synced
  to the 6.1.34 pin via `cyrius lib sync` (88 modules).
- Version strings and the banner bumped to `0.4.0`.

### Notes
- The avatara bundle carries a benign `ERR_NONE = 0` that matches the vendored
  libro's identical constant (same value; last definition wins), and its own
  self-contained `xalloc` (an OOM guard over stdlib `alloc`, defined nowhere
  else). No fn/type collisions with the other bundles, the stdlib, or thoth's
  own source.

## [0.3.0] - 2026-06-11

The agent gets real hands (roadmap M4): **three seams flip at once**. daimon
(MCP tool execution + host registry) binds **remote-client** over HTTP via
sandhi; bote (the MCP protocol) and t-ron (per-tool authorization) bind
**native** as vendored dist bundles, in-process. Every dangerous action —
`/run`, `/write`, and the new MCP `/call` — now flows through one t-ron-backed
authorization choke point that fails closed at every layer. Live-verified
end-to-end across the real spine: thoth → t-ron allow → daimon → MCP JSON-RPC
→ hoosh's bote-backed `/v1/tools/call` → echo back up the chain; a deny-listed
tool refused with no request sent. See [ADR-0006](docs/adr/0006-m4-tool-spine-daimon-bote-tron.md).

### Added
- **daimon seam client** (`src/daimon.cyr`): `/tools` lists the MCP host
  registry (`GET /v1/mcp/tools`); `/call <tool> [json]` invokes a tool
  (`POST /v1/mcp/call`) and prints the MCP tool-result text. Binds when
  `thoth.cyml [daimon].url` is declared; degrades honestly otherwise.
- **t-ron authorization gate** (`src/gate.cyr`): when `[tron].policy` names a
  loadable policy TOML, every gated action becomes a t-ron `ToolCall` —
  **deny is final** (no prompt can override policy), flag falls back to the
  interactive confirm, allow proceeds. Without a policy the M2 fail-closed
  confirm prompt stands in, announced. Built-ins authorize as `thoth_run` /
  `thoth_write`; MCP tools under their real name, checked *before* any
  request leaves thoth. t-ron's own defaults deny unknown agents/tools.
- **Vendored spine bundles** (`src/vendor/`): bote-core 2.7.3 (MCP protocol,
  transport-free), t-ron 2.1.5 (policy/rate/scan/audit engine), libro 2.7.2
  (the audit chain t-ron writes). Committed dist files with re-sync scripts
  (`scripts/sync-{bote,tron,libro}.sh`) — NOT `[deps.X]` blocks, whose
  transitive git sub-deps collide (the hoosh-discovered pattern).
- **26 new unit assertions (93 total)**: daimon call building + result/error
  extraction against canned bodies, t-ron verdicts through the real vendored
  engine (allow/deny globs, deny-by-default for unknown agent/tool — also the
  libro `chain_append` SIGILL canary), `[daimon]`/`[tron]` config defaults,
  `/tools` + `/call` classification, and M4 seam statuses.

### Changed
- **Seam registry is fully dynamic**: bote reports **native** by construction
  (the bundle is in-process); daimon remote when configured; t-ron native when
  a policy loads. `/seams`, `/state`, and the gate all reflect it.
- **`cyrius.cyml`**: toolchain pin `6.1.32` → `6.1.33` (dep-resolver CVE
  hardening; no stdlib migration). Stdlib deps gained `regex` (t-ron policy
  globs), `random`, `patra`, `slice` (vendored libro/t-ron surfaces), and the
  concurrency+crypto floor (`atomic`/`thread`/`thread_local`/`ct`/`keccak`/
  `random`) moved **before** `sigil` — t-ron 2.1.5's documented ordering
  constraint (without it, libro's `chain_append` SIGILLs).
- `confirm` moved from `src/commands.cyr` into `src/gate.cyr`, beside the
  seam it stands in for; thoth's private `_hex_digit` renamed
  `_hoosh_hex_digit` (stdlib patra now carries an identical private one).
- Version strings and the banner bumped to `0.3.0`.

### Known issues
- **daimon 1.2.4 upstream**: the MCP host registry stores strings aliasing
  the transient request buffer, so registrations corrupt as later requests
  arrive (calls 502, `/tools` shows garbage). Filed as
  `daimon/docs/development/issues/2026-06-11-mcp-registry-aliases-request-buffer.md`.
  thoth's seam is correct against a fresh registration.
- t-ron's bundle duplicates sigil's `chacha20_xor` (same signature/semantics;
  last definition wins) — benign, accepted in t-ron's own 2.1.5 notes.

## [0.2.1] - 2026-06-11

Maintenance release: toolchain **Cyrius 6.1.23 → 6.1.32** (the bayan stdlib
migration) and the hoosh seam re-verified against **hoosh 2.4.5** (was wired
against 2.2.2). The `/v1/chat/completions` contract thoth consumes is unchanged
across hoosh 2.2.3–2.4.5 — the gateway's new surface (tool calling, batch, MCP
tool endpoints, DLP, observability, new providers, configurable routing
strategy) is server-side or belongs to later seams (M4: daimon/bote/t-ron).
No thoth behavior change.

### Changed
- **Toolchain: Cyrius 6.1.32** (pin, was 6.1.23). Clean `lib/` re-sync
  (52 modules).
- **Stdlib migration: `json` / `toml` / `cyml` / `base64` / `bigint` → `bayan`.**
  Cyrius 6.1.25 carved the data-domain modules out of stdlib into the bayan
  distlib; those five names no longer resolve. `[deps].stdlib` now lists
  `bayan` in their place, ordered before `sigil` (u256) and the transport
  (json/base64). Call sites migrated to the canonical `bayan_*` names
  (`bayan_json_v_*` in `src/hoosh.cyr`, `bayan_toml_*` / `bayan_cyml_*` in
  `src/config.cyr`) rather than the deprecated back-compat aliases.
- Version strings and the banner bumped to `0.2.1`.

### Verified
- 67/67 unit assertions on `cyrius test`; live end-to-end against a local
  hoosh **2.4.5** gateway — a turn routed to Anthropic, then a mid-session
  `/model` switch re-routed to OpenAI in the same session, both through the
  bayan-migrated response parser.

## [0.2.0] - 2026-06-10

The signature feature, wired (roadmap M3): the **hoosh seam** flips from absent
→ **remote-client**. thoth routes a turn to a backing model and switches the
backing model mid-session — both through hoosh, the AGNOS inference gateway,
reached as an OpenAI-compatible HTTP client transported by **sandhi**. Verified
end-to-end against a live gateway: a turn routed to a real provider, and a
mid-session `/model` switch re-routed Anthropic → OpenAI within one session.
thoth still owns no domain logic — hoosh owns inference, routing, and the
switch; thoth drives. See [ADR-0005](docs/adr/0005-hoosh-seam-remote-over-sandhi.md).

### Added
- **hoosh seam client** (`src/hoosh.cyr`): builds an OpenAI-compatible
  chat-completions request (with a JSON string escaper), POSTs it via
  `sandhi_http_post`, and extracts `choices[0].message.content` with the stdlib
  `json` value parser. The request builder, escaper, and response/error
  extractors are pure; only the round-trip does I/O.
- **`thoth.cyml` runtime config** (`src/config.cyr`): thoth's own CYML config
  (distinct from the `cyrius.cyml` build manifest), parsed once at startup via
  the stdlib `cyml` + `toml` modules. `[hoosh].url` / `token` / `model`.
  `thoth.cyml` is gitignored (it may hold a token); `thoth.cyml.example` is the
  committed template.
- **Mid-session model switch made real**: `/model <id>` stores a stable copy
  (`session_set_model_copy`) used on the next turn; hoosh routes per request by
  the `model` field, so a new id is the switch.
- **20 new unit assertions** (67 total): JSON escaping, request building, and
  response/error extraction against canned bodies, plus config defaults and the
  copy-not-alias model switch.

### Changed
- **Seam status is honest and dynamic**: `seam_status(SEAM_HOOSH)` returns
  `remote` when `thoth.cyml` declares an endpoint, else `absent`. `/seams`,
  `/state`, `/model`, and free-text task routing reflect it — a configured turn
  POSTs to hoosh; an unconfigured one degrades with a pointer to `thoth.cyml`;
  an unreachable gateway announces the transport error. Never faked.
- **`cyrius.cyml`**: toolchain pin `6.1.15` → `6.1.23`; opted `sandhi` and its
  full transitive stdlib set (plus `cyml`/`toml`) into `[deps].stdlib`, ordered
  so the low-level floor precedes the transport that consumes it (libs are
  opt-in and Cyrius does not resolve transitive deps).
- Version strings and the banner bumped to `0.2.0`.

## [0.1.0] - 2026-06-09

First real release: the platform-neutral **driver core** (roadmap M2). thoth is
a DRIVER — it owns no domain logic and reaches the AGNOS spine
(hoosh/daimon/bote/t-ron/avatara) through capability seams that are all
**absent** in 0.1.0. The agent loop is real; model-backed reasoning, MCP tools,
and authorization are not wired yet, and degrade honestly. SemVer `0.x` per
[ADR-0004](docs/adr/0004-semver-pre-release.md).

### Added
- **Interactive REPL/TUI driver** (`src/repl.cyr`, `src/main.cyr`): a
  read → dispatch → iterate loop over a portable buffered line reader.
- **Commands** (`src/commands.cyr`): `/help`, `/seams`, `/state`, `/model`,
  `/read`, `/write`, `/run`, `/quit`, plus free-text input routed as a coding
  task. Pure `classify_input` / `token_is` / `arg_after` helpers.
- **Capability-seam registry** (`src/seams.cyr`): the five spine seams with
  status (all `absent`); `/seams` renders the capability ladder honestly.
- **Fail-closed authorization gate**: `/run` and `/write` name their target and
  deny by default, proceeding only on explicit `y` — the t-ron-absent
  degrade-closed posture, made real.
- **Local shell escape** (`src/exec.cyr`): `/run` runs `/bin/sh -c` via the
  portable `process.cyr` surface (explicit argv), streaming output and
  reporting the real exit code.
- **Session state + persona** (`src/session.cyr`): turn/model state and the
  static avatara Thoth/Librarian banner descriptor.
- **47-assertion unit suite** (`tests/thoth.tcyr`) over the pure logic.
- Project identity + the OS-agnostic/AGNOS-primary design: `CLAUDE.md`,
  `README.md`, `docs/development/{state,roadmap}.md`, ADR-0001..0004,
  architecture note 001, and the required root files (`CONTRIBUTING.md`,
  `SECURITY.md`, `CODE_OF_CONDUCT.md`).

### Changed
- `cyrius.cyml`: `version` → `${file:VERSION}` (was an inlined `0.1.0`); real
  `description`; added `repository`; `[build].output` → `build/thoth`; added
  `process` / `result` / `tagged` stdlib deps for the portable shell escape.
- Standards links repointed from the stale `docs/development/applications/…`
  path to `docs/development/first-party/…`.

### Security
- `/run` and `/write` are gated by a fail-closed confirm that denies by default
  (stands in for the absent t-ron seam) and names the object being authorized.
- `/run` uses explicit argv via `exec_vec` — no `sys_system` with unsanitized
  data. `/read` is read-only and ungated by design; a real sandbox/authorization
  posture belongs to the t-ron seam, not an in-tree allowlist (see ADR-0001).
