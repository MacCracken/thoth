# 001 — Consumer-only: thoth holds no first-party domain logic

> Non-obvious invariant — *how the world is*, not *what we chose*. The choice
> that makes it so is recorded in the ADRs (see [`../adr/`](../adr/)); this note
> states the standing fact a reader can't derive from the code alone.

## The invariant

thoth contains no LLM-inference, MCP-protocol, MCP-security, or
personality/archetype logic of its own. It is a pure front-end/driver: it reads
a task, plans, edits files, runs tools, iterates, and can switch the backing
model mid-session — but every domain that work touches is owned elsewhere and
merely *driven* by thoth. There is genuinely nothing to fork inside thoth,
because thoth owns nothing to fork.

The capability spine lives entirely in sibling first-party crates:

- **hoosh** — LLM inference gateway: model routing and mid-session model
  switching. The signature "switch the backing model mid-session" is a *routing*
  concern thoth asks hoosh to perform; thoth holds no provider SDKs, no model
  catalog, no inference path.
- **daimon** — agent orchestration, MCP tool execution, and the host registry.
- **bote** — the MCP protocol itself.
- **t-ron** — MCP per-tool authorization (the security gate around the
  file-edits and shell commands the agent runs).
- **avatara** — the personality layer; thoth's own "Thoth / Librarian" persona
  is an archetype overlay *pulled from* avatara, not a string table baked into
  thoth.

This is the AGNOS "own the stack" principle in force: when AGNOS owns a domain,
thoth depends on it and never reimplements it. The mid-session model switch, the
tool host, the protocol, the auth gate, and the persona are all things thoth
*invokes*, never things it *is*.

## What it affects

Anyone tempted to add provider/SDK, MCP-protocol, MCP-security, or
personality/archetype code *into* thoth is hitting this invariant and must stop.
The fix is never "implement it here" — it is "add it to the owning crate and
consume it":

- A new model provider or routing rule → **hoosh**, then route to it.
- A new tool, orchestration step, or host-registry entry → **daimon**.
- A protocol-level change to how tools are spoken to → **bote**.
- An authorization rule for what a tool may do → **t-ron**.
- A change to the scribe persona, tone, or archetype behaviour → **avatara**.

Reaching for any of those *inside* thoth — even "just a little" to smooth over a
fallback, an offline mode, or a host that's inconvenient to reach — forks a
domain AGNOS already owns and breaks this invariant. The most security-sensitive
case is t-ron: thoth runs an agent that edits files and executes shell commands,
so an in-tree auth shim that bypasses t-ron is a real security regression, not a
convenience. Where an owned capability is unreachable, the correct posture is to
degrade and announce — and to degrade *closed* on security (a conservative
built-in deny/prompt, never a silent allow) — never to re-implement the missing
domain in thoth.

## Why the OS-agnostic posture stays cheap

The above is a rule about the *capability spine* (above thoth). It does not
conflict with thoth running across operating systems, because OS-agnosticism is
a separate, lower layer — the *substrate* (below thoth): syscalls, allocation,
argv, process spawn. That fan-out already exists in the vendored Cyrius stdlib,
behind one stable interface:

- `syscalls_x86_64_agnos`, `syscalls_x86_64_linux`, `syscalls_aarch64_linux`,
  `syscalls_macos`, `syscalls_windows`
- `alloc_agnos`, `alloc_macos`, `alloc_windows`
- `args_agnos`, `args_macos`, `args_win`
- `process_agnos`, `process_win`

thoth code is written against the portable interface and the target is selected
at build time; thoth never calls a per-OS file directly. So portability is a
posture the substrate already pays for, not infrastructure thoth must invent.
The two layers never collide: thoth may abstract the OS *beneath* it, but it
holds no domain logic *above* it to fork. Port the floor; never fork the spine.
