# thoth — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile). For the why behind the
> identity/posture below, see [`docs/adr/`](../adr/); for sequencing, see
> [`roadmap.md`](roadmap.md).

## Version

**0.1.0** — scaffolded 2026-06-08 via `cyrius init`. No releases yet.

thoth is a binary / consumer app, so **CalVer (`YYYY.M.D`) applies at the
first real release**. The SemVer `0.1.0` in `VERSION` is left untouched
during fermentation — the CalVer switch happens at the first real tag, not
now. See [`roadmap.md`](roadmap.md) for the cut.

## Posture (fermenting)

thoth is long-horizon and **FERMENTING**: captured as an idea-log, not yet
built into feature code. No agent / TUI surface exists yet beyond the
scaffold stubs.

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

- **Cyrius pin**: `6.1.14` (in `cyrius.cyml [package].cyrius`)
- **Multi-OS substrate present in the vendored stdlib** (`lib/`), behind one
  stable interface:
  - syscalls — `syscalls_x86_64_agnos`, `syscalls_x86_64_linux`,
    `syscalls_aarch64_linux`, `syscalls_macos`, `syscalls_windows`
    (plus `syscalls_linux_common`)
  - alloc — `alloc_agnos`, `alloc_macos`, `alloc_windows`
  - args — `args_agnos`, `args_macos`, `args_win`
  - process — `process_agnos`, `process_win`

  AGNOS is the primary target; Linux, macOS, and Windows are
  capability-gated reach targets. The fan-out is what makes the OS-agnostic
  floor cheap — it already exists and is now put to deliberate use.

## Source

Initial scaffold only — `src/main.cyr` + `src/test.cyr` (hello-world stubs).
No agent / TUI feature code yet.

## Tests

- `tests/thoth.tcyr` — primary suite (stub; passes on `cyrius test`)
- `tests/thoth.bcyr` — benchmark stub (no-op)
- `tests/thoth.fcyr` — fuzz stub

## Dependencies

**Current (declared in `cyrius.cyml`):** stdlib only —
`string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`.

**Intended (NOT yet declared — fermenting, prose only).** When thoth leaves
the fermenting stage it will consume the AGNOS capability spine rather than
reimplement any of it (own-the-stack). None of the following are wired up;
the manifest carries stdlib deps only. Each is described here so the seams
are recorded, not so they are implied to exist:

- **hoosh** — LLM inference gateway: model routing and the signature
  mid-session model switch.
- **daimon** — agent orchestration + MCP tool execution + host registry.
- **bote** — the MCP protocol.
- **t-ron** — MCP per-tool authorization (the security gate around the
  file-edits and shell commands the agent runs).
- **avatara** — personality / archetype overlay; the Thoth / Librarian
  persona pulled straight from avatara.

These will become `cyrius.cyml` git-deps (each with a tag and an explicit
`modules` list) only once thoth leaves fermentation; the off-AGNOS reach
transport is deferred to a later ADR. A per-dependency capability ladder
(native vs. reached-as-client vs. absent; full / degraded / absent
semantics) is a maintenance obligation tracked in prose here and in
[`roadmap.md`](roadmap.md) until design begins.

## Consumers

_None yet._

## Next

See [`roadmap.md`](roadmap.md).
