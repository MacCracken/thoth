# 0006 — The M4 tool spine: daimon remote-client, bote and t-ron native via vendored dist bundles

**Status**: Accepted
**Date**: 2026-06-11

## Context

M4 gives the agent real hands: MCP tool execution under authorization. Three
seams bind at once — daimon (orchestration + MCP tool execution + host
registry), bote (the MCP protocol), and t-ron (per-tool authorization, the
security-critical seam). Each crate settles part of its own binding question:

- **daimon (1.2.4)** is a standalone HTTP daemon, like hoosh — it ships no
  distlib. Its MCP host surface is `GET /v1/mcp/tools` (the registry),
  `POST /v1/mcp/call` (`{"name","arguments"}` → the MCP tool-result shape
  `{"content":[…],"isError":…}`), with external tools forwarded as MCP
  JSON-RPC to their registered callback endpoints.
- **bote (2.7.3)** is a protocol library, not a server. It ships
  `dist/bote-core.cyr` — a fully self-contained, transport-free bundle
  (JSON-RPC codec, protocol structs, registry/dispatcher, jsonx extractor).
- **t-ron (2.1.5)** is middleware, meant to sit in-process with whatever
  executes tools. It ships `dist/t-ron.cyr`: policy engine (per-agent
  allow/deny globs, deny-wins), rate limiter, payload scanner, pattern
  analyzer, and a libro-backed audit chain. Its hardened defaults deny
  unknown agents and unknown tools.

Two constraints shaped the bindings. First, the own-the-stack mandate
([ADR-0002](0002-consume-the-agnos-stack.md)): no hand-rolled MCP client, no
ad-hoc auth shim. Second, a toolchain reality: bote's and t-ron's manifests
declare git sub-deps (`[deps.libro]`/`[deps.majra]`, `[deps.libro]`/
`[deps.bote]`) that `cyrius deps` resolves transitively into colliding
compile sets — the exact failure hoosh hit and solved by vendoring the dist
bundle as a committed file (its `scripts/sync-bote.sh` documents the
collision chain).

## Decision

- **daimon binds remote-client over HTTP via sandhi** (`src/daimon.cyr`),
  exactly like hoosh: `thoth.cyml [daimon].url` gates the seam; no endpoint,
  no remote claim. `/tools` lists the host registry, `/call <tool> [json]`
  invokes one tool. The request builder and result extractors are pure and
  unit-tested; only the round-trips do I/O.
- **bote binds native**: `src/vendor/bote-core.cyr` (committed dist bundle,
  re-synced by `scripts/sync-bote.sh`). The MCP protocol is in-process — the
  same contract AGNOS serves co-resident. thoth's wire shapes for daimon are
  the MCP shapes bote defines; nothing MCP is hand-rolled.
- **t-ron binds native**: `src/vendor/t-ron.cyr` + `src/vendor/libro.cyr`
  (t-ron's audit chain calls libro's `chain_*` surface), re-synced by
  `scripts/sync-{tron,libro}.sh`. `thoth.cyml [tron].policy` names a policy
  TOML; loading it flips the seam. `src/gate.cyr` is the single authorization
  choke point: every gated action (/run, /write, /call) becomes a t-ron
  `ToolCall` → `tron_check` verdict. **Deny is final** — no interactive
  prompt can override policy. Flag falls back to the fail-closed confirm.
  Built-ins authorize under reserved names (`thoth_run`, `thoth_write`); MCP
  tools under their real names, checked *before* any request leaves thoth.
- **Absent t-ron stays fail-closed**: no policy → the built-in confirm prompt
  (deny by default), announced as the stand-in it is. This keeps the M2
  posture as the floor; t-ron raises it, never replaces it with silence.

Stdlib consequences (recorded in `cyrius.cyml`): `regex` (t-ron's policy
globs), `random` + reordering `atomic`/`thread`/`thread_local`/`ct`/`keccak`
*before* `sigil` (sigil's hash path self-installs a per-thread scratch bank;
without the order, libro's `chain_append` SIGILLs — t-ron 2.1.5's documented
constraint), `patra` + `slice` (libro's logging and agnosys subscript use).
One benign duplicate: t-ron's bundle carries its own `chacha20_xor` (same
signature/semantics as sigil's; last definition wins — accepted in t-ron's
own 2.1.5 notes).

## Consequences

- The capability ladder is now three-fifths real: hoosh remote, daimon
  remote, bote native, t-ron native, avatara absent (M5). Live-verified
  end-to-end: a `/call` flowed thoth → t-ron allow → daimon → (MCP JSON-RPC)
  → hoosh's bote-backed `/v1/tools/call` → echo back up the chain; a
  deny-listed tool was refused with **no request sent**; `/run` executed
  under a t-ron allow.
- Verification surfaced an upstream daimon 1.2.4 bug (filed as
  `daimon/docs/development/issues/2026-06-11-mcp-registry-aliases-request-buffer.md`):
  the MCP registry stores strings that alias the transient request buffer, so
  registrations corrupt as later requests arrive. thoth's seam is correct
  against a fresh registration; the instability is daimon's to fix and is
  listed under known limitations.
- Three committed vendor bundles must track their upstream tags (the sync
  scripts pin the known-good defaults). The t-ron+libro pair must move in
  lockstep with t-ron's own `[deps.libro]` pin.
- thoth still owns no domain logic: the gate module *binds* t-ron's engine,
  the daimon module *drives* the host, and the protocol lives in bote's
  bundle. The bright line holds: port the floor; never fork the spine.
