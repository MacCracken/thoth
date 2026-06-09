# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.1.0** — first real release, 2026-06-09 (roadmap M2: the driver core).
Scaffolded 2026-06-08 via `cyrius init`.

thoth uses **SemVer `0.x`** through its pre-1.0 phase
([ADR-0004](../adr/0004-semver-pre-release.md)) — this supersedes the earlier
"CalVer at first release" note. The post-1.0 scheme is deferred.

## Posture

thoth 0.1.0 is the **driver core**: the interactive REPL/TUI loop is real and
usable, but every capability seam is **absent** — no model-backed reasoning
(hoosh), MCP tools (daimon/bote), authorization (t-ron), or live personality
(avatara) is wired yet. Absent capabilities degrade honestly; nothing is faked.
Each future milestone flips one seam from absent → remote/native.

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

- **Cyrius pin**: `6.1.15` (in `cyrius.cyml [package].cyrius`), matching the
  installed `cycc`.
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

The 0.1.0 driver core — ~500 lines across these Cyrius modules:

- `src/main.cyr` — entry; includes the modules and runs the loop.
- `src/repl.cyr` — the read → dispatch → iterate loop.
- `src/commands.cyr` — input classification + command handlers.
- `src/seams.cyr` — the capability-seam registry.
- `src/session.cyr` — session state + the static avatara persona descriptor.
- `src/exec.cyr` — the portable local shell escape for `/run`.
- `src/util.cyr` — buffered stdin `read_line`, `emit`, small helpers.

Binary: ~124 KB (`build/thoth`, x86_64-linux).

## Tests

- `tests/thoth.tcyr` — **47 assertions** over the pure logic (`classify_input`,
  `token_is` / `arg_after`, the seam registry, session state, `cstr_starts_with`).
  Passes on `cyrius test`.
- `tests/thoth.bcyr` — benchmark stub (no-op).
- `tests/thoth.fcyr` — fuzz stub.

## Dependencies

**Current (declared in `cyrius.cyml`):** stdlib only — `string`, `fmt`,
`alloc`, `io`, `vec`, `str`, `syscalls`, `result`, `tagged`, `process`,
`assert`, `bench`. (`result` / `tagged` / `process` back the portable `/run`
shell escape; `process.cyr` abstracts spawn across Linux / macOS / agnos /
Windows.)

**Intended spine deps (NOT yet declared — seams absent).** When a seam is
wired, thoth will consume the owning crate rather than reimplement it
(own-the-stack). None are wired up today:

- **hoosh** — LLM inference gateway: model routing and the mid-session switch.
- **daimon** — agent orchestration + MCP tool execution + host registry.
- **bote** — the MCP protocol.
- **t-ron** — MCP per-tool authorization (the gate around file-edits and shell
  commands; today stood in for by the fail-closed confirm gate).
- **avatara** — personality / archetype overlay; the Thoth / Librarian persona.

These become `cyrius.cyml` git-deps (each with a tag + explicit `modules` list)
as each seam is wired; the off-AGNOS reach transport is deferred to a later ADR.

## Known limitations (0.1.0)

- Spine seams are absent — no model, MCP tools, or t-ron authorization yet.
- No structured logging (sakshi). Audit-worthy events (`/run`, `/write`) are not
  yet logged; this lands when the t-ron / daimon seams wire up.
- `/read` is read-only but unrestricted; sandboxing belongs to the t-ron seam,
  not an in-tree allowlist.
- `/write` takes single-line content; multi-line editing is future work.

## Consumers

_None yet._

## Next

See [`roadmap.md`](roadmap.md) — M3 wires the hoosh seam (inference +
mid-session model switch).
