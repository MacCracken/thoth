# ADR-0019 — Layered config: `~/.thoth/` is the base, the project layers on top

**Status:** Accepted (0.43.3) · **Supersedes the discovery half of** [ADR-0016](0016-thoth-home-dir-config-memory-discovery.md)

## Context

ADR-0016 gave thoth a discoverable `.thoth/` home and fixed the real bug it set out to fix: launching
thoth in a different repo silently found no config. It resolved **one** home — the nearest `.thoth/`
directory walking up from CWD, else `~/.thoth/` — and read **one** config file from it.

Two years of ordinary use later, the "one home wins" model is the thing that hurts:

1. **A global config could not coexist with a project one.** `~/.thoth/config.cyml` was documented in
   the committed template as "a global user default", but any project with its own `.thoth/` shadowed it
   entirely. A user who set their gateway URL, model and persona once globally lost all of it the moment
   a repo carried a config that set anything at all. Every other tool with a dotfile home — git, ssh,
   cargo, and the agentic harnesses thoth is measured against — treats the home file as a **base** that
   project files refine.

2. **The walk matched a DIRECTORY, not a config file**, and that produced two failures that looked like
   thoth being broken:
   - A `.thoth/` containing only `memory/` or `checkpoints/` shadowed every config above it **and**
     blocked `~/.thoth` — thoth reported "no config" in a repo that plainly had one.
   - `src/checkpoint.cyr` writes a **CWD-relative** `.thoth/checkpoints/`. So running thoth once from a
     subdirectory created a `.thoth/` there, and from then on thoth launched in that subdirectory could
     not see its own repo's config. Measured, not theorised — see the Evidence section.

   In this very repo `.thoth/` is git-tracked (it holds `config.cyml.example`), so on a fresh clone
   `~/.thoth/config.cyml` could **never** apply here.

## Decision

**Config is two layers, resolved per key.**

- **Global base**: `~/.thoth/config.cyml`.
- **Local override**: the nearest `.thoth/config.cyml` found by walking **up from CWD** — looking for the
  **file**, not the directory — else the legacy `./thoth.cyml`.
- Every key resolves as **local, else global, else the built-in default**. Both layers are optional and
  either alone works.

Memory layers the same way: `~/.thoth/memory/` is read, then the project's `.thoth/memory/`. Each layer
gets its own slice of the injection budget so neither can starve the other. `/remember` continues to
write to the **project** store when there is one.

### The security rule: strictest wins

Layering a list is not a neutral act when the list controls what the model may do. The rule is:

| Key | Rule | Why |
|---|---|---|
| all scalars, `[alias]`, `[pricing.*]` | local wins per key | ordinary refinement; no authority involved |
| `[shell].deny` | **UNION** across both layers | a deny only ever REMOVES authority, so merging can only make the filter stricter — a project may add denies and can never drop the user's |
| `[shell].allow` | local **REPLACES** wholesale when it declares one | an allow GRANTS authority. Unioning would let a repo you cloned widen your global allow-list by appending one glob |
| `[project].read_roots` | local **REPLACES** wholesale when it declares one | same reasoning: this is the model's read jail |

**Authority does not accumulate from the less-trusted side.** A cloned repo's config is the less-trusted
side. Whichever layer is in charge of an allow-list, the resulting authority is exactly what one file
states — never the sum of two.

An **explicitly empty** local list (`allow = []`) is a declaration and stays empty; an **absent** one
falls through to the global. `_shell_glob_decl` returns `-1` for "declared neither" precisely so those
two cases cannot be confused — conflating them would read a local file that says nothing about `allow`
as one that allows nothing.

## Consequences

- `~/.thoth/config.cyml` becomes genuinely useful: set the gateway, model, persona and UI preferences
  once, and let each repo add only what is specific to it.
- The two discovery bugs above are closed. A `.thoth/` holding only `checkpoints/` is now invisible to
  config resolution.
- **The legacy `./thoth.cyml` is now the LOCAL layer** rather than a whole-config fallback, so it
  overrides the global per key like any local file. Still announced as legacy.
- `/state` shows **both** paths and which is which; the greeting says when both are in play.
- `config_source()` gains `2` = "the global only".

### Known limitation, stated rather than hidden

When CWD is `$HOME` (or under it with no nearer config), the local walk can reach
`~/.thoth/config.cyml` and return it as the local layer as well as the global. There is no portable
path-resolution primitive to detect this — the stdlib has no `getcwd`/`realpath` wrapper, and a raw
`syscall(SYS_GETCWD, …)` is exactly the portability claim aarch64 does not honour, so inventing one
would fork the floor to fix a label. It is **harmless in behaviour**: layering a file over itself
resolves every key to the same value. The only effect is that `/state` names the same path on both
rows. The memory layer does *not* have this problem — `_thoth_root_resolve` records which branch matched,
so it reads a single store once instead of injecting every fact twice.

## Evidence

Measured against the shipped binary with a fake `HOME`, before and after:

| CWD situation (`~/.thoth/config.cyml` exists in all) | before | after |
|---|---|---|
| local `.thoth/config.cyml` | local | local |
| local `.thoth/` dir, no `config.cyml` inside | ⛔ **no config found** | **global** |
| no `.thoth` anywhere up the tree | global | global |
| no `.thoth`, legacy `./thoth.cyml` | global (legacy unreachable) | **legacy over global, per key** |
| repo has config, CWD is `sub/` with `.thoth/checkpoints/` | ⛔ **no config found** | **repo config** |

Per-key layering verified live: a local file setting only `[hoosh].model` inherits the global's
`[hoosh].url`, `[subagent].enabled` and `[shell].enabled` while its own model wins. Memory verified by
capturing thoth's actual request body — both stores' facts appear in the system message.

The security rules are enforced by tests that **fail when the rule is broken**: making `allow` union
across layers turns three assertions red.

## Alternatives rejected

- **Home-first with the project as a pure fallback** (project used only when no global exists). A
  literal reading of "global first, local fallback", but it makes a global config *prevent* per-project
  settings — the opposite of what a base layer is for.
- **Union everything, like an accumulating permission model.** Convenient, and rejected on the authority
  argument above: it lets repository content widen the operator's global grants.
- **Keeping one-file-wins and only fixing the directory-vs-file walk.** Closes the two bugs but leaves
  the original complaint — no usable global config — untouched.
