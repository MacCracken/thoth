# 0017 — Model `edit` tool: surgical, jailed to the launch directory, t-ron-gated, opt-in

**Status**: Accepted
**Date**: 2026-07-12

## Context

thoth is an agentic **coding** front-end. As of [ADR-0015](0015-project-read-tools-jailed-default-on.md)
the model can *read* the project (`read_file`/`list_dir`) and *explore* it, and with the opt-in
`shell` tool ([ADR-0014](0014-model-shell-tool-local-posix-gated.md)) it can run commands — but it
could not cleanly **write** code. The only ways the model could change a file were to shell out
(`sed`/`cat >`/`git apply` — clumsy, unobservable, all-or-nothing) or to drive a daimon-hosted MCP
tool (`fs_write`, only when a daimon endpoint is wired, and observed by thoth only as opaque result
text). A coding agent that can read but not edit is half a tool: the read tools completed the
"see the code" half; the "change the code" half was missing.

The adjacent substrate is already thoth-owned: `file_write_all` (`lib/io.cyr`), the `/write` command's
read-old → diff → write mechanics (`src/commands.cyr`), `src/diff.cyr` (LCS + `compute_file_diff`'s
escape-free structured line-ops), and the `_project_jail_ok` boundary. Editing the local project the
user launched in is thoth's own local hands — not a spine domain. daimon owns MCP tool *execution*
(external tools); it does not own "rewrite the working directory." Making a local edit tool
thoth-native is the symmetric completion of ADR-0015, using the same substrate + jail.

The hard part, as with the read tools, is **safety** — and a *write* is strictly more dangerous than
a read: a prompt-injection could tell the model to clobber `~/.ssh/authorized_keys`, corrupt a file,
or write outside the project. So a model-invokable write is only acceptable if it (a) cannot escape
the project, (b) cannot be turned on by accident, (c) is independently deniable by policy, and
(d) cannot blind-clobber the wrong location.

## Decision

Add one thoth-native, model-invokable tool — **`edit(path, old_string, new_string)`** (`src/edit.cyr`)
— with **surgical** semantics: it replaces the **unique** occurrence of `old_string` with
`new_string` in an existing project file and applies the change to disk. It degrades **closed** at
every layer:

1. **Surgical + unique-match (correctness/safety).** `old_string` must occur **exactly once**; zero
   matches or more than one → the edit is **refused, not applied** (the model must include enough
   surrounding context to name one site). An empty `old_string` is refused. `new_string` may be empty
   (a deletion). This is the Claude Code `Edit` contract — the model cannot blind-replace the wrong
   place. The transform is a pure, exhaustively unit-tested core (`_edit_apply`).
2. **Opt-in (`[edit].enabled`, default off).** Advertised only when enabled — like `[shell].enabled`,
   not default-on like the read tools — because a write is consequential. Advertise-gate and
   dispatch-gate are kept in lockstep, and a hallucinated `edit` while disabled returns an honest
   "not enabled" string (never forwarded to daimon).
3. **Jailed to the launch cwd (`_project_jail_ok`).** Relative paths only; absolute, `~`, and `..`
   are refused. Deliberately **not** `_project_read_ok`: the user's `/allow` grants are *read* roots
   (e.g. vidya, granted so the agent can *learn* Cyrius); honoring them for writes would let the model
   write into a repo opened only for reading — a privilege escalation. A write-roots grant, if ever
   wanted, needs its own key.
4. **t-ron gated under a distinct `thoth_edit` verb.** Gated *inside* the tool after parse (so the
   parsed path is the scanned object), degrading to the fail-closed confirm when no policy is bound.
   The verb is **distinct from `thoth_write`** (the operator's `/write`), following the
   `thoth_run`/`thoth_shell` split precedent — so a policy can allow the human's `/write` yet deny
   model edits.

The tool is **local + forced-serial** (registered in `_agent_round_has_local`, never routed to the
parallel daimon executor). It returns a summary the model sees (`(edit: <path> - +A -D lines, N
bytes written)`, counts via `diff_stats`); the colored diff card in the feed follows in later cuts
(0.31.1 records the old/new snapshot keyed by turn/round; 0.31.2 renders it in the GUI draw-IR via
`compute_file_diff`).

## Consequences

- thoth can now **write code**, not only read it — the capability an agentic coding TUI fundamentally
  needs. Off by default; a user opts in with `[edit].enabled = true` and (recommended) a `[tron].policy`
  that scopes `thoth_edit`.
- **Verified**: the pure core and the apply-to-disk half are unit-tested (surgical match/unique/
  not-found/delete/bounds; real-file read-modify-write; parse + jail refusals), and the **full gated
  path** was live-driven end-to-end against a real t-ron allow-policy (parse → jail → t-ron VK_ALLOW →
  surgical apply → `file_write_all` → file changed on disk).
- **Residuals (honest, not fully fixed here)**:
  - **Non-atomic write.** `file_write_all` opens `O_TRUNC` then does a single write, so a short write
    (disk-full/quota) or an error leaves the file truncated. The tool now treats `wr != newlen` as a
    failure (it never *reports* success on a partial write, and the roundlog records `err`), but it
    cannot yet *prevent* the truncation — a crash-safe replace needs a portable temp-file+`rename`, and
    there is no portable `xrename` in the stdlib (`sys_rename`'s arity differs per target). A portable
    atomic `file_write_all` is a stdlib follow-up that would also harden `/write`.
  - **Symlink-inside-project is followed on write** (no portable `O_NOFOLLOW`) — more dangerous for a
    write than a read; the jail is a boundary, not a sandbox.
  - Separator/escape checks are POSIX/AGNOS-only (`/`, `..`, `~`); Windows `\`/`C:\` needs handling when
    `--win` ships.
  - Creating *new* files is not yet supported (edits existing files only) — a deliberate follow-up.
