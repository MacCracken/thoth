# 0016 — `.thoth/` home directory: config + memory discovery, honest readiness

**Status**: Accepted · **discovery half SUPERSEDED by [ADR-0019](0019-layered-config-global-base-local-override.md)** (0.43.3)
**Date**: 2026-07-09

> ⚠ **What 0019 changed.** Config is now TWO layers — `~/.thoth/config.cyml` as a global base with the
> nearest `.thoth/config.cyml` overriding it PER KEY — and the local walk looks for the config **file**
> rather than the first `.thoth/` **directory**. That closes two bugs this ADR's one-root model caused: a
> `.thoth/` holding only `checkpoints/` shadowed every config above it and blocked `~/.thoth` entirely,
> and because checkpoints are written CWD-relative, running thoth once from a subdirectory permanently
> hid that repo's own config from it. The `.thoth/` home itself — and the reasoning below for having
> one — still stand.

## Context

thoth read its runtime config from a single fixed path, `./thoth.cyml` — resolved relative to the
**current working directory only**, with no upward search and no user-global fallback. Project memory
already lived at `./.thoth/memory/` ([ADR-0012](0012-memory-seam-omit-until-mneme.md)), also CWD-relative.

This produced a reported bug: launching thoth in a **different repo** (or a subdirectory) meant `thoth.cyml`
was not found, so `config_hoosh_url()` fell back to the localhost default (`http://127.0.0.1:8088`). The
startup probe then hit that default; if a stray local hoosh happened to answer, the greeting printed **READY**
— even though the user's intended config was never loaded. thoth "could not find the hoosh server yet
pronounced itself READY." Two coupled defects: (1) config discovery is CWD-only, and (2) READY is asserted off
a silent default without revealing that no config was found.

`.thoth/` was already a directory name in thoth's world (the memory store). A bare `.thoth` *file* would
collide with the `.thoth/` *directory*.

## Decision

Make **`.thoth/` a home directory** (like `.git/`) that holds *both* config and memory:

- `.thoth/config.cyml` — the runtime config (same CYML format + parser as the legacy `thoth.cyml`).
- `.thoth/memory/` — the project memory store (unchanged location within the home).

**Discovery** (`_thoth_root_resolve`, `src/config.cyr`): walk UP from the CWD for the nearest ancestor
`.thoth/` directory (bounded at 40 levels), then fall back to `~/.thoth/` (a global user home). `config_path()`
reads `<root>/config.cyml`; when that file is not found it falls back to the legacy `./thoth.cyml` so
existing setups keep working. Memory (`memory_dir()` / `memory_index_path()`) derives from the **same** root,
so config and memory stay consistent regardless of launch directory.

**Honest readiness** (`src/tui.cyr` greeting): READY is printed only when a *configured* `[hoosh].url` actually
answers a live probe. When no config was discovered the greeting says "no config — no `<path>` found (add one,
or `~/.thoth/config.cyml`)"; a config with no url says "hoosh absent"; a dead configured url says "hoosh
unreachable — `<url>`". A reachable unconfigured default is noted "[default … is reachable]", never as READY.

## Consequences

- Launching in a subdirectory or another repo finds the right config (or states its absence) — the driver is
  location-independent, and READY reflects the real gateway, not a coincidental localhost default.
- One discoverable `.thoth/` home holds everything; a `~/.thoth/config.cyml` gives a global default.
- Back-compat: `./thoth.cyml` is still honored whenever no `<root>/config.cyml` is found; the example moved to
  `.thoth/config.cyml.example`. `.gitignore` ignores the real `.thoth/config.cyml` and keeps the example +
  `.thoth/memory/` tracked.
- The `.thoth` *file* vs `.thoth/` *directory* collision is avoided by making it unambiguously a directory.
- All user-facing config hints (`/state`, the model picker, one-shot, the status bar) name
  `.thoth/config.cyml`; the legacy `./thoth.cyml` fallback *logic* and internal code comments still use the
  bare name (still accurate — `thoth.cyml` remains a valid fallback).

## Update (0.43.2) — the fallback is gated on the FILE, not on the home, and a legacy load is now announced

This ADR twice said the legacy `./thoth.cyml` is read "when no `.thoth/` home exists". The code has
never done that. `config_path()` falls back whenever `<root>/config.cyml` is **absent**, even with a
`.thoth/` home sitting right there — so an operator reasoning "I have a `.thoth/` home, therefore the
root file is inert, therefore deleting `.thoth/config.cyml` gives me a no-config session" instead got a
*different* config loaded, silently. In a tree carrying both, that meant the authorization seam could
quietly unbind with no message.

Both sentences above are corrected to match the code. The behaviour is **kept** — it is this ADR's
back-compat promise, and narrowing it would break trees that rely on it — but it is no longer silent:

- The greeting names a legacy load (`config: legacy ./thoth.cyml`).
- `/state` carries a `config` row with the live path, flagged `[legacy path]` when it is the fallback.
- `/reload` re-runs discovery (it used to reuse the cached path, so a `.thoth/config.cyml` created in
  response to that very advice was invisible until a restart) and reports it when the file changes.

`config_source()` and `config_root()` had existed since 0.26.0 with **zero callers** — the honesty this
update adds was already built, just never wired.
