# 0015 — Project read/explore tools: default-on, jailed to the launch directory

**Status**: Accepted
**Date**: 2026-07-08

## Context

thoth is an agentic **coding** front-end, yet the backing model could not *see* the codebase it
was launched in. During an agentic turn the model's context is the prompt + the persona system
message + project-memory **facts** + tool results, and its tools are daimon's MCP tools (only when
a daimon endpoint is wired), `memory_write` ([ADR-0012](0012-memory-seam-omit-until-mneme.md)), and
the opt-in `shell` tool ([ADR-0014](0014-model-shell-tool-local-posix-gated.md)). The only ways code
reached the model were the **user** typing `@file` mentions (0.21.0) or the model driving the heavy,
opt-in `shell` hammer (`cat`/`ls`) — full arbitrary command execution just to read a file. Out of
the box a coding agent was effectively blind ("confined to its local memory space").

The adjacent substrate already exists and is thoth-owned: `/read` (`file_read_all` into a bounded
buffer), `@file` mention expansion (`src/mention.cyr`), and the file tree (`dir_list`). Reading the
local project the user launched in is thoth's own local hands — not a spine domain. daimon owns MCP
tool *execution* (external tools); it does not own "read the working directory."

The hard part is **safety**. A *model*-invokable read is a new surface: a prompt-injection (a
poisoned file, a hostile task) could tell the model to read `~/.ssh/id_rsa` or `/etc/passwd` and
leak it in a later reply or tool call. This is unlike `/read` and `@file`, where the **human** chose
the path. So the capability is only safe if it cannot escape the project.

## Decision

Add two thoth-native, model-invokable tools — **`read_file(path)`** and **`list_dir(path)`**
(`src/project.cyr`) — riding the existing read substrate, advertised **default-ON** whenever the
agentic loop is on (`[hoosh].tools`), and executed **LOCALLY** in `agent.cyr`'s serial dispatch
(never forwarded to daimon).

Every path is confined by a **project jail** (`_project_jail_ok`): an absolute path (leading `/`), a
leading `~`, or any `..` path component is **refused**; the (relative) path then resolves against the
process cwd — the directory thoth was launched in — so reads are confined to the project and below.
The jail is the security boundary, so these tools are **not** t-ron-gated per call (a read-only,
project-confined operation; per-read prompts would be unusable for a coding agent). Output is bounded
(`PROJECT_READ_CAP` 64 KiB per file, `PROJECT_LIST_CAP` 16 KiB per listing) into reused buffers.

**Default-on**, because a coding tool whose agent cannot see the codebase is not useful — the master
switch is `[hoosh].tools` (turn the loop off to disable). This is the coding-tool norm; the jail, not
being off, is what makes it safe.

**In scope (0.23.0)**: read + list, jailed, default-on. **Out of scope**: writing/editing (that is the
`shell` tool's job, and a future edit tool); widening the jail to other roots — the **0.23.1 user-grant
model** lets the user allow additional roots (another repo, **vidya** to learn Cyrius features) as a
permission, like every other restriction.

## Consequences

- **Positive** — the agent can autonomously explore and read the project it was launched in, the core
  ability a coding agent needs; it works standalone (no daimon required, like the shell tool since
  0.20.0); it reuses proven substrate (no new read path); and it is safe-by-construction against the
  main exfil vector (escaping to secrets outside the project).
- **Negative** — a new (jailed) surface thoth now owns; the model *can* read any project file when the
  loop is on, including a project-local secret (e.g. a checked-in `.env`) — but that is the trust model
  of a coding agent working in a project the user launched it in and enabled tools for, and the jail
  blocks the worse case (reading outside the project). **Residual (documented, not faked)**: a symlink
  *inside* the project pointing outside is followed (no portable `O_NOFOLLOW` — same class as the
  `/tmp`-symlink residuals); it requires a pre-existing symlink in the user's own repo, lower risk than
  the `..`-escape the jail blocks.
- **Neutral** — sets up the 0.23.1 grant model (a `[project]` config section + a `/allow` grant, vidya
  as a first-class root) and possible later tools (a `grep`/glob search, a project-map hint in the
  system prompt).

## 0.23.1 update — user-granted read roots

The jail stays the default; the **user** (never the model) can widen it to additional absolute roots — to
review another repo, or to read the **vidya** Cyrius knowledge base and bring the latest language features
back to the project. This is a permission model like every other restriction, and it preserves the core
property: *the model can only read where the human pointed it.*

- **The boundary widens** (`_project_read_ok`): a read is allowed if it is a jailed in-project relative path
  **or** an absolute path with no `..` component that sits under a granted root. `_project_under_root`
  prefix-matches on a `/` boundary (`/a/b` is under `/a`; `/ab` is not). A granted root must be absolute and
  longer than `/` (granting `/` would defeat the jail); trailing slashes are stripped and duplicates ignored.
- **Grants are the human's, not the model's.** Sources: config `[project].read_roots` (persistent) +
  `[project].vidya`, and the `/allow` command (`/allow`, `/allow <abs-path>`, `/allow vidya`). `/allow` is a
  slash command — the model cannot invoke it, exactly as it cannot invoke `/run`. So the widening is always a
  human authorization; the model just gets a bigger (still bounded, still `..`-free) read surface.
- **Honest, surfaced, degrades closed.** `/allow` and `/state` (a `reads` row) list the active roots; a read
  outside the project and every granted root is refused with an honest string. The symlink-inside-a-root
  residual carries over from the jail (a granted root the user trusts, same risk class as the project).
- **Alternatives folded in here** (same reasoning as below): requiring absolute roots (no cwd/`..`
  normalization ambiguity), rejecting `/` (would negate the jail), and keeping grants human-only (a
  model-invokable "grant myself a root" tool would reopen the exfil vector the jail closes).

## Alternatives considered

- **Opt-in like the `shell` tool** — rejected as the default: it leaves the agent blind out of the box,
  the exact complaint. (Turning off `[hoosh].tools` remains the off switch.)
- **t-ron-gate each read** — rejected: safest but unusable (a coding agent reads many files; per-read
  confirm prompts would drown the session). The jail gives the safety without the friction.
- **Unrestricted paths (like `/read` for the human)** — rejected: a real exfil surface (a prompt-
  injection reads `~/.ssh` and leaks it). The jail is non-negotiable for a *model*-invokable read.
- **Rely on the `shell` tool** (`cat`/`ls`) — rejected as the answer: it is opt-in, t-ron-gated,
  POSIX-only, and full arbitrary execution; using it merely to read a file is a far larger hammer and
  surface than a purpose-built, read-only, jailed tool.
- **A daimon/MCP filesystem server** — rejected as the *floor*: it requires a wired daimon endpoint and
  external configuration; reading the launch directory is thoth's own substrate and must be the
  always-available baseline. daimon MCP tools remain additional, never required.
