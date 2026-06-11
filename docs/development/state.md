# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.2.1** — toolchain + hoosh refresh, 2026-06-11 (Cyrius 6.1.32 / the bayan
stdlib migration; seam re-verified against hoosh 2.4.5). **0.2.0** — the hoosh
seam, 2026-06-10 (roadmap M3: inference + mid-session model switch). First real
release was **0.1.0**, 2026-06-09 (M2: the driver core). Scaffolded 2026-06-08
via `cyrius init`.

thoth uses **SemVer `0.x`** through its pre-1.0 phase
([ADR-0004](../adr/0004-semver-pre-release.md)) — this supersedes the earlier
"CalVer at first release" note. The post-1.0 scheme is deferred.

## Posture

thoth 0.2.x wires the **first capability seam**: hoosh is now **remote-client**
— thoth routes a turn to a backing model and switches the backing model
mid-session, both through the hoosh inference gateway, reached as an
OpenAI-compatible HTTP client transported by sandhi. The other four seams remain
**absent** — MCP tools (daimon/bote) and authorization (t-ron) land in M4, live
personality (avatara) in M5. Absent capabilities degrade honestly; nothing is
faked. Each milestone flips one more seam from absent → remote/native.

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

- **Cyrius pin**: `6.1.32` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc` (bumped from `6.1.23` for 0.2.1; carries the 6.1.25 bayan
  data-domain carve — see Dependencies).
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

The driver core (M2) plus the hoosh seam (M3), across these Cyrius modules:

- `src/main.cyr` — entry; includes the modules, runs `config_load` then the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers (task/model route
  through hoosh when the seam is remote).
- `src/seams.cyr` — the capability-seam registry; `seam_status` is dynamic for hoosh.
- `src/session.cyr` — session state (incl. the copy-on-set model) + the static
  avatara persona descriptor.
- `src/config.cyr` — **M3**: `thoth.cyml` runtime config (hoosh endpoint/token/model).
- `src/hoosh.cyr` — **M3**: the hoosh seam client (request build, sandhi POST,
  response/error extraction).
- `src/exec.cyr` — the portable local shell escape for `/run`.
- `src/util.cyr` — buffered stdin `read_line`, `emit`, small helpers.

Binary: ~1.5 MB (`build/thoth`, x86_64-linux) — up from ~124 KB at 0.1.0; the
sandhi/TLS transport surface (static data) dominates.

## Tests

- `tests/thoth.tcyr` — **67 assertions** over the pure logic: M2's
  `classify_input`, `token_is` / `arg_after`, the seam registry, session state,
  `cstr_starts_with`; plus M3's JSON escaping, chat-request building,
  response/error extraction, config defaults, and the copy-on-set model switch.
  Passes on `cyrius test`.
- `tests/thoth.bcyr` — benchmark stub (no-op).
- `tests/thoth.fcyr` — fuzz stub.

## Dependencies

**Current (declared in `cyrius.cyml`, all stdlib).** Driver core: `string`,
`fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `result`, `tagged`, `process`,
`assert`, `bench` (`result` / `tagged` / `process` back the portable `/run`
shell escape). Data formats: **`bayan`** — the Cyrius 6.1.25 data-domain carve
(json / toml / cyml / base64 / bigint / u128 / csv in one distlib fold); it
carries both the `thoth.cyml` config surface (with `fs`) and the JSON wire
format, and must precede `sigil` (u256) and the transport. Call sites use the
canonical `bayan_*` names. M3 hoosh transport: **`sandhi`** (the HTTP/TLS
client, folded into stdlib as `lib/sandhi.cyr`) plus its full transitive set —
`net`, `http`, `tls`, `ws`, `sakshi`, `sigil`, `args`, `hashmap`, `thread`,
`thread_local`, `fnptr`, `async`, `atomic`, `chrono`, `mmap`, `dynlib`,
`fdlopen`, `freelist`, `ct`, `keccak`. Libs are opt-in and Cyrius does
**not** resolve transitive deps, so the set is declared by hand and ordered
low-level-floor-first (see the `[deps]` comment in `cyrius.cyml`).

**Spine seams.**

- **hoosh** — LLM inference gateway: **wired (remote-client over HTTP via
  sandhi)**. Consumed as a running gateway, not a linked crate (hoosh ships no
  distlib — it is a server). Re-verified at hoosh **2.4.5**; its 2.2.3–2.4.5
  growth (tool calling, batch, `/v1/tools/*` MCP endpoints, DLP, observability,
  17 providers, configurable routing strategy) is server-side or M4+ seam
  material — the chat contract thoth consumes is unchanged. See
  [ADR-0005](../adr/0005-hoosh-seam-remote-over-sandhi.md).
- **daimon** — agent orchestration + MCP tool execution + host registry: absent (M4).
- **bote** — the MCP protocol: absent (M4).
- **t-ron** — MCP per-tool authorization (the gate around file-edits and shell
  commands; today stood in for by the fail-closed confirm gate): absent (M4).
- **avatara** — personality / archetype overlay; the Thoth / Librarian persona: absent (M5).

The off-AGNOS reach transport vs. the AGNOS-native binding distinction is
deferred to a later ADR.

## Known limitations (0.2.1)

- hoosh is the only wired seam; daimon/bote/t-ron (M4) and avatara (M5) are absent.
- hoosh responses are **non-streaming** — thoth waits for the full completion,
  then prints it. Streaming/SSE is future work.
- The hoosh request is fixed (`max_tokens` 4096, single user message, no system
  prompt, no conversation history). Multi-turn context and request tuning are
  future work.
- No structured logging (sakshi) of audit-worthy events (`/run`, `/write`, hoosh
  calls); this lands when the t-ron / daimon seams wire up.
- `/read` is read-only but unrestricted; sandboxing belongs to the t-ron seam,
  not an in-tree allowlist.
- `/write` takes single-line content; multi-line editing is future work.

## Consumers

_None yet._

## Next

See [`roadmap.md`](roadmap.md) — M4 gives the agent real hands: MCP tool
execution via daimon + bote, gated by t-ron (the security-critical seam,
fail-closed off AGNOS).
