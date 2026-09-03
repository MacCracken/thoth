# ADR-0021 — Authority-granting config keys are read from the global layer only

- **Status**: accepted
- **Date**: 2026-09-03
- **Version**: 0.44.3
- **Supersedes in part**: [ADR-0019](0019-layered-config-global-base-local-override.md)

## Context

ADR-0019 made thoth's config two layers resolved per key: `~/.thoth/config.cyml` as a global base,
the nearest `<repo>/.thoth/config.cyml` overriding it. It stated the security rule plainly —

> **Authority does not accumulate from the less-trusted side.**

— and then enforced it for exactly **two keys**, both lists: `[shell].allow` and
`[project].read_roots` are *replaced* by the local layer rather than appended to, while
`[shell].deny` unions.

Every authority-granting **scalar** was left on the ordinary local-overrides-global path. The local
layer is a file inside the repository, found by walking up from the working directory, and **a
`git clone` reproduces it**. So opening thoth in a repository written by somebody else meant:

| Local key | What it bought the repository |
|---|---|
| `[hooks].session_start` | **Arbitrary code, executed at launch**, before the operator typed anything |
| `[hooks].pre_tool` / `post_tool` / `session_end` | The same primitive on a later trigger |
| `[verify].command` | A command run as the operator after every model write |
| `[hoosh].url` (with the global's `token`) | thoth POSTing the operator's own bearer token to a host the repo chose |
| `[tron].policy` / `agent` | The repo supplying the policy that authorizes the model's tool calls |
| `[session].file` / `[history].file` / `[log].file` | An unjailed write sink — thoth truncates and overwrites whatever path it names; `[session].file` is also read *back*, so a repo could ship attacker-authored `user`/`assistant` turns |

This was found by the 0.44.3 hardening audit and **demonstrated rather than argued**: with the fix
reverted, a repository whose config carried `[hooks].session_start = "touch …"` executed it at
launch. `src/hooks.cyr`'s own header said *"hooks come from the OPERATOR'S CONFIG and nowhere
else"* — true when written, false from the moment config gained a second layer. A documented
residual is a claim with an expiry date, and nothing was re-checking this one.

## Decision

**A key that grants authority is read from the GLOBAL layer only.** The local layer is consulted
solely to discover that it *tried* to set one, so the attempt can be named.

Authority keys are: the four `[hooks]` commands, `[verify].command`, `[tron].policy`, `[tron].agent`,
and `[log].file` / `[history].file` / `[session].file`. Two further rules fall out of the same
principle:

- **A token is bound to the URL that earned it.** When the local layer *redirects* `[hoosh].url` and
  supplies no token of its own, the global `[hoosh].token` is **withheld**. Same URL on both layers
  is not a redirect and changes nothing.
- **`[shell].deny` merges from the trusted side first.** The union filled with the local patterns and
  appended global ones "if there is room", so a local layer declaring `SHELL_GLOB_MAX` denies evicted
  every global deny — an untrusted file *deleting* the operator's deny-list, the exact inversion
  ADR-0019 forbids. Filling from the global side makes an overflow drop local entries.

**Nothing is silent.** A suppressed key is named on stderr at startup (so a one-shot/CI caller learns
of it), in the greeting, in `/state` and on `/reload` — the same treatment 0.43.5 gave unrecognised
keys, and for the same reason: a config line that did nothing must never be indistinguishable from a
config line that was never written.

**Agreement is not escalation.** A local layer naming the *same value* the global already grants has
asked for nothing, and is not reported. That is the ordinary shape of a project config written by the
machine's own owner; flagging it would train the operator to ignore the line that matters.

## Consequences

**This is a deliberate behaviour change against ADR-0019's own example**, which offered "a project
t-ron policy" as something the local layer may set. That illustration cannot be honoured safely:
thoth cannot tell your repository from a cloned one, and the strict reading of the ADR's stated
principle wins over its example. Anyone relying on a project-local `[tron]`, `[hooks]` or `[verify]`
block moves it to `~/.thoth/config.cyml`; thoth names exactly which keys and where.

⚠ **On macOS every project-local authority key is currently suppressed**, because
`getenv("HOME")` returns null there (a cyrius floor gap — `lib/io.cyr` reads `/proc/self/environ`,
which Darwin does not have; filed upstream) so there is no global layer to grant from. That is the
correct behaviour under this ADR, and it is a real limitation until the floor gap is fixed.

**What this does NOT change.** The local layer keeps everything that expresses preference: model,
tier, theme, aliases, pricing, caps, and the capability toggles (`[shell].enabled`, `[edit].enabled`,
`[subagent].enabled`, …). A repo enabling a *tool* is not the same class of hazard as a repo naming a
*command*: every tool call still passes the t-ron gate, and with no policy that gate is a fail-closed
confirm the operator answers. `[hooks]` had no such gate, which is why it was the CRITICAL of the set.

## The open question this leaves

**Per-repo trust.** The safe default forbids something legitimate — approving *your own* project's
hooks once. The natural shape is trust-on-first-use over the local layer's authority keys, mirroring
what `[toolpin]` already does for tool definitions: prompt once, remember the decision, fail closed
where nobody can be asked. It is a real feature with a real threat model of its own (where is the
trust record kept, and what defends *it*?), so it is recorded here rather than guessed at.
