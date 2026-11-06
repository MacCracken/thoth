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
`[log].file` / `[history].file` / `[session].file`, and — since 0.51.0 (ADR-0022) — the whole
`[toolpin]` table: `enabled` (a repo must not switch the rug-pull defence off), `file` (where thoth
writes and reads back its trust record) and `durable`; since 0.52.6, `[memory].enabled` (ADR-0012's opt-in is the
operator's trust decision: the injection it enables meets no gate) and `[history].size` (it decides how much of
the operator's history file survives each save). Two further rules fall out of the same principle:

- **A token is bound to the URL that earned it.** When the local layer *redirects* `[hoosh].url` and
  supplies no token of its own, the global `[hoosh].token` is **withheld**. Same URL on both layers
  is not a redirect and changes nothing. (0.52.6: decided by value — an empty local token is no token, and an
  empty local url no redirect; and the converse, ruled on as design question D2 — a local token with no url of its
  own layer is ignored and named, never sent to the operator's gateway.)
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

⚠ ~~**On macOS every project-local authority key is currently suppressed**, because `getenv("HOME")`
returned null there.~~ **Resolved at 0.44.5** (cyrius 6.5.45 gave Darwin a `getenv`): the global layer
loads on macOS and this ADR applies there as on Linux. Between 0.44.3 and 0.44.5 macOS had no global
layer, so every local authority key was suppressed — the correct fail-closed behaviour under this ADR.

**What this does NOT change.** The local layer keeps everything that expresses preference: model,
tier, theme, aliases, pricing, caps, and the capability toggles (`[shell].enabled`, `[edit].enabled`,
`[subagent].enabled`, …). A repo enabling a *tool* is not the same class of hazard as a repo naming a
*command*: every tool call still passes the t-ron gate, and with no policy that gate is a fail-closed
confirm the operator answers. `[hooks]` had no such gate, which is why it was the CRITICAL of the set.
*(0.52.6 and 0.52.8: the preferences that spend the operator's money or guard the session — the budget
ceiling, pricing, `[subagent].enabled`, `[guard]`, `[redact]`, `[hoosh].reasoning` and `max_tokens` —
move only in the safe direction from a local layer; see the addendum.)*

## The open question this leaves

**Per-repo trust.** The safe default forbids something legitimate — approving *your own* project's
hooks once. The natural shape is trust-on-first-use over the local layer's authority keys, mirroring
what `[toolpin]` already does for tool definitions: prompt once, remember the decision, fail closed
where nobody can be asked. It is a real feature with a real threat model of its own (where is the
trust record kept, and what defends *it*?), so it is recorded here rather than guessed at. ADR-0022
(0.51.0) answers that question for the tool-definition half — a keyless store defended by 0600, an
atomic rename, a symlink refusal and a whole-file digest, with its ceiling (a same-uid editor) stated;
the per-repo-hooks half stays open.

## Addendum (0.52.8) — the safe direction

The Decision draws one line: authority keys come from the global layer, and every other key is a
preference the local layer keeps. 0.52.6 found that rule too generous for keys that are preferences
in form but spend the operator's money or weaken the session's defences, and gave three of them a
*direction*: `[budget].max_cost_micro` is strictest-wins, a local `[pricing]` rate may only raise the
global's, and a local `[project].read_roots` entry may only narrow a global root. The 0.52.8 audit
(repair batch 12) found five more on the plain override path, and the maintainer ruled them the same
way:

| Local key | What it bought a clone | Now |
|---|---|---|
| `[guard].enabled`, `[redact].enabled` | The injection guard and secret redaction switched off for the operator's session | may only turn them **on** |
| `[subagent].enabled` | Delegation switched on: each child is a whole model conversation the operator pays for | may only turn it **off** |
| `[hoosh].reasoning`, `[hoosh].max_tokens` | Every request's output ceiling raised (`max_tokens = 128000`, `reasoning = "max"`), past a global `[budget].max_tokens` too, since the budget is checked before each call, not inside one | may only **lower** them |

The comparison is with the global layer's value, or with thoth's default where the global says
nothing. With no global `[hoosh].reasoning`, then, a repository cannot turn reasoning on, and the
`max_tokens` it may lower is the effort's own default. A move the other way is ignored and named like
a suppressed key (stderr, the greeting, `/state`, `/reload`). A value that agrees with the baseline is
not reported, for the reason the Decision gives. (The greeting row is itself 0.52.8's: from 0.44.3 only
stderr named a suppressed key at startup, and the TUI's alternate screen and the window's first frame
cover stderr, so the Decision's "in the greeting" was not true until now.)

`[project].vidya` stays a preference: a repository may say where its knowledge base lives. But
`/allow vidya` turned the key into a read grant of whatever path it named, so a clone's
`vidya = "/home/you/.ssh"` became the operator's one-word grant. A vidya path the local layer chose is
now bounded like a local read root: it must lie under a root the global config grants, with no
symlink below that root, or `/allow vidya` refuses and names the path. A global vidya is granted as
before.

The same audit found the 0.52.6 read-root bound incomplete. The jail's symlink walk skipped every
component of a granted root's own spelling, so a local root that was itself a link inside a global
root, or ran through one, reached outside it. The walk now trusts only the operator's own prefix: the
global root a local root sits under, or an `/allow` grant. A local root reached through a link is
refused when it is granted, and named.

## Addendum (0.53.3)

Global-only was not enough. **A relative value in the global file resolves against the working directory**, so
`policy = "tron-policy.toml"`, the template's own line, named a file in whichever repository the operator opened, and the
repository chose the policy that authorizes the model. A relative `[tron].policy` or `[toolpin].file` now resolves under
`~/.thoth/`, the directory of the file naming it. With no `HOME` it stays unset, which reads as absent: a confirm, never an allow.

`[log].file`, `[history].file` and `[session].file` stay relative when written that way, because a per-project store is what that
spelling is for. Links are refused on all three. **A session store must also be 0600 and the operator's** (`file_is_private`), or it
is refused and named: this attack was named above, a repository shipping a store whose contents resume as the operator's own
turns, and git checks files out 0644 or 0755. An archive that keeps modes can still carry one.

Three more keys join the rule, under R1's safe direction: `[hoosh].max_iters`, `[subagent].max_iters` and `[shell].max_output` may
only be lowered by a local layer, since each round is a model call and a large enough `max_output` switched the guard off.
`[hooks].timeout_ms` is global-only, because a 1 ms value made a `pre_tool` hook deny every call.

The token rule gains a case: a local `url` equal to the global's counts as no url of its own, so a local token beside it is ignored
and named. It was D2 by another key.

And the layer itself: the walk climbs 40 levels with no owner check, so `/tmp/.thoth/config.cyml` from another local user became a
local layer for anyone working under `/tmp`. A config another user owns is skipped and named, as git's `safe.directory` does. Root's files
stay. An operator working in a checkout another uid owns sees its config ignored, and is told.

An unreadable global config now counts as a refused parse, so thoth starts unconfigured rather than running on the local layer alone.

## Addendum (0.54.3)

The maintainer ruled on four of the questions left open, and each draws the same line: what a repository controls does not reach the operator's limits, records or trust.

- **`[hoosh].timeout_ms` may only shorten the deadline.** A local `0` beside a redirected `[hoosh].url` was a hang the TUI could not break out of. A local value that lengthens or
  disables the deadline is ignored and named. A global `0` is the operator's own choice.
- **`[log].level` may only add detail.** The file is global-only, and the log is the record of what a session did, so a clone's `level = "off"` silenced the operator's own record.
  With a global file and no global level, the floor is the info that file gets by default. A `--logs` capture holds the same way, at the flag's level.
- **The project map is a user message.** Nothing a repository controls belongs at system level. The guard's marking stays, and the header says the message is thoth's and asks for nothing.
- **The tally may price from the gateway's figure, but only from a gateway the operator chose.** The operator's rate comes first, and a local `[hoosh].url` never prices. A ceiling that
  cannot fire was worse than one resting on the gateway's arithmetic.
