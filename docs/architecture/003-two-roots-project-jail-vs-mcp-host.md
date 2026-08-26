# 003 — Two roots: thoth's project jail is not the MCP host's directory

> Non-obvious invariant — *how the world is*, not *what we chose*. The choices
> that make it so are [ADR-0002](../adr/0002-consume-the-agnos-stack.md)
> (consume the spine, do not reimplement it) and
> [ADR-0015](../adr/0015-project-read-tools-jailed-default-on.md) (the jailed project read
> tools). This note states the standing fact a reader cannot derive from either
> file alone.

## The invariant

**A file path means two different places depending on which tool receives it.**

- thoth's own `read_file` / `list_dir` / `search` / `edit` resolve a path
  **relative to the directory thoth was launched in**, confined to it and below
  (plus any root the *user* granted with `/allow`). This is the project jail.
- A tool that comes from **daimon's registry** executes on the **MCP host**, and
  resolves its path against **that host's** root. For bote's `fs_read` /
  `fs_write` / `fs_mkdir` that root is `$BOTE_FS_ROOT`, fixed when the bote
  process started — which has nothing to do with where thoth is running, or with
  where it was running when the operator opened a different project an hour ago.

The two roots are unrelated by construction and thoth cannot reconcile them:
re-rooting someone else's host would be forking the spine, and thoth has no way
to *ask* a host where it is rooted — MCP has no such field.

## Why this bites

Both tools describe themselves the same way. bote registers `fs_read` as *"Read
a text file under the project root"* and means its own root; thoth advertises
`read_file` as *"relative to THIS project's root"* and means the launch cwd. A
model reading the two descriptions side by side has nothing to choose on, and
daimon's registry is serialized into the advertisement **first**.

Observed in 0.44.0, against the local dev stack: asked to review the project it
was launched in, the agent issued `fs_read {"path":"src/tasks/health.js"}` and
received `cannot read /home/macro/.agnos-stack/workspace/src/tasks/health.js`.
Nothing was misconfigured and nothing in the jail failed. The relative path was
correct; it was resolved in the other tree.

The failure mode is quiet in both directions, and the write direction is worse
than the read one: a `fs_write` aimed at "this project" lands in the host's
workspace, reports success, and leaves the project unchanged.

## What thoth does about it (0.44.1)

thoth cannot fix where a host is rooted. It can refuse to be ambiguous about
where **it** is:

1. **The system prompt names the root.** `project_prompt_clause()`
   (`src/project.cyr`) states the absolute launch directory, names
   `read_file` / `list_dir` / `search` as the tools jailed to it, and says host
   file tools are rooted elsewhere. It is part of thoth's operating clause in
   `persona_system_prompt()`, so a subagent inherits it.
2. **A failed host file tool is corrected with a fact.**
   `_agent_xtree_append()` (`src/agent.cyr`) fires only when a registry tool
   *errored* and the relative path it asked for *actually exists* in this
   project, and then names the call that works. It is a file-existence test, not
   a guess.
3. **Jail refusals are actionable.** `project_refuse_outside()` tells a model
   that used an absolute in-project path which relative path to retry with,
   instead of the true-but-useless "outside the project".

⚠ **What was tried and removed.** A note appended to every path-taking tool's
*advertised description* was measured against the live stack (3 runs × 40 rounds,
annotated vs not) and moved nothing — 12 stray `fs_read` calls with it, 2
without, on run-to-run variance far larger than the effect. It was deleted
rather than kept as decoration. Prose in a tool description is a hope; a
file-existence test at the moment of failure is a fact. Prefer the second.

## The rule for new work

Before adding anything that takes a path, ask **whose directory it resolves in**.
If the answer is "the MCP host's", it is not a project tool and must never be
described as one — and if thoth is going to hand the model both kinds at once,
it owes the model a way to tell them apart.
