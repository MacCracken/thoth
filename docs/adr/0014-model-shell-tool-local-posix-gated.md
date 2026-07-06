# 0014 — The model's `shell` tool: a local, POSIX-only, defense-in-depth agentic capability

**Status**: Accepted
**Date**: 2026-07-06

## Context

Users want thoth's backing model to **run shell commands** during an agentic
turn — build, test, `git`, inspect files — and feed the output back into the
loop. thoth already has two adjacent pieces:

- **`/run <cmd>`** (`src/commands.cyr` → `src/exec.cyr` `run_shell`): the
  **human's** shell escape. It streams to the terminal, returns only an exit
  code, and is gated under the reserved t-ron name `thoth_run`. It is the
  operator typing a command they intend.
- **`memory_write`** (`src/memory.cyr`, [ADR-0012](0012-memory-seam-omit-until-mneme.md)):
  the one existing **thoth-native, model-invokable** agentic tool — advertised
  to the model, intercepted locally in the serial executor, gated at the single
  t-ron choke point, never forwarded to daimon.

The new capability is the intersection: a **model-proposed** shell command. Two
things make it not a trivial copy of `/run`:

1. **Trust.** `/run` is the operator's own authorized command; the shell tool is
   an **untrusted model** proposing one. They are different trust levels and an
   operator must be able to permit one without the other.
2. **Substrate, not spine.** Shell execution is owned by **no** AGNOS capability
   domain (unlike inference→hoosh, MCP→bote, orchestration→daimon,
   authorization→t-ron, archetype→avatara). It is raw substrate. But the *output
   capture with a timeout* the model needs is not in the linked stdlib
   (`lib/process.cyr`'s `exec_capture` has no timeout; `lib/regression.cyr`'s
   timed helpers are not in thoth's `[deps].stdlib`), and it is not portable —
   AGNOS has no `/bin/sh -c` (`sys_spawn` takes a program path only) and no
   `WNOHANG` `waitpid`.

## Decision

Ship a thoth-native, **local**, **opt-in**, **POSIX-only** agentic tool named
**`shell`**, mirroring the `memory_write` shape, with **defense in depth** and a
**byte-identical floor** when disabled.

1. **A local tool, not a seam.** There is no external domain owner to bind to
   ([ADR-0012](0012-memory-seam-omit-until-mneme.md)'s seam exists because *mneme*
   owns memory), so the shell tool is gated on a plain `config_shell_enabled()`
   (opt-in, default off) **and** a compile-time capability check
   `shell_supported()`. No `SEAM_SHELL`; nothing to pollute `/seams`.

2. **A distinct reserved name `thoth_shell`.** The model's shell is authorized
   under `thoth_shell`, **separate from `thoth_run`** (the human `/run`). A
   t-ron policy can allow the operator's `/run` while independently denying,
   flagging, or rate-limiting the model's shell (t-ron's default-deny-unknown
   fail-closes it until an explicit `allow` rule is added).

3. **Defense in depth, deny-biased at every layer:**
   - opt-in — unadvertised entirely when off or on a non-POSIX target;
   - a **local `[shell.deny]`/`[shell.allow]` glob filter checked BEFORE t-ron**
     (so a deny-list holds even with no `[tron].policy` — the common case): deny
     wins; a non-empty allow-list is default-deny;
   - the **t-ron `thoth_shell` gate** (the authority): the raw command is passed
     as the scanned payload (`_params_one("command", cmd)`, JSON-escaped) so
     t-ron's injection scanner / pattern analyzer / rate limiter see what will
     run; deny is final; flag → the fail-closed confirm (which **denies** in
     one-shot);
   - a **bounded, timed capture**: output capped, a runaway command SIGKILLed at
     the deadline with partial output preserved, and **every** proposed +
     executed command audited.

4. **The timed capture is substrate in `src/exec.cyr`** —
   `exec_shell_capture` copies `lib/regression.cyr`'s proven pattern (child
   stdout+stderr → temp file, `WNOHANG`-poll-with-deadline, `SIGKILL` + blocking
   reap, `file_read_all`). This is *porting the floor*, not forking the spine:
   `exec.cyr` is already "the driver's own local hands," and shell exec is owned
   by no AGNOS domain. It lives in thoth src, never in vendored `lib/`.

5. **POSIX-only; degrade closed, announced.** The raw-syscall body is compiled
   out on AGNOS/Windows (`#ifndef CYRIUS_TARGET_AGNOS`/`_WIN`, mirroring
   `lib/process.cyr`); `shell_supported()` returns 0 there so the tool is **not
   advertised**, and `/state` says "enabled but unsupported on this target." This
   is the deferred-clipboard precedent: architecturally impossible off POSIX,
   degrade closed by ABI, never faked.

6. **Byte-identical floor.** With `[shell].enabled` off (the default),
   `agent_tools_add_shell` returns the tools length unchanged (zero writes), no
   `/state` row is emitted, and no request body changes. A call named `"shell"`
   is matched **unconditionally** in `_agent_round_has_local` (forcing the serial
   path) and the dispatch site re-checks `config_shell_enabled() &&
   shell_supported()`: an un-advertised or hallucinated `"shell"` call is neither
   executed **nor** forwarded to daimon — it returns an honest not-enabled string.

## Consequences

- **Reachable only in agentic turns** (daimon wired + `[hoosh].tools`), exactly
  like `memory_write`: `agent_enabled()` is `0` without daimon, so `cmd_task`
  routes to a plain turn. Relaxing that so `[shell].enabled` alone enters the
  agentic loop is a larger core-routing change — **deferred**, and `/state`
  announces "gated on daimon" so it is never silently inert.
- **The globs are a coarse pre-filter, not a sandbox** — a shell can `cd`,
  chain, or base64-decode around a string glob (`glob_match` is `*`/`?` only).
  Real containment is: default-off, the operator's trust decision, the t-ron
  policy, and OS-level confinement of thoth itself. This is stated honestly in
  the code, `/state`, and `thoth.cyml.example`; no confinement is overclaimed.
- **Known residual limits** (documented, not faked): binary NUL bytes in output
  are scrubbed to spaces (text-tool contract; the JSON escaper stops at a NUL);
  the timeout kills the `/bin/sh`, not a backgrounded grandchild; the capture
  temp file lives in world-writable `/tmp` (best-effort `O_EXCL` create, no
  `O_NOFOLLOW` in the frozen open ABI).
- **Deferred**: a Windows timed capture (`WaitForSingleObject` + `TerminateProcess`),
  process-group kill (`setpgid` + `kill(-pgid)`), and the `agent_enabled()` relax.

See also [ADR-0002](0002-consume-the-agnos-stack.md) (consume the spine),
[ADR-0006](0006-m4-tool-spine-daimon-bote-tron.md) (t-ron authorization),
[ADR-0010](0010-data-producer-honest-omit.md) (honest omit / announce-never-fake).
