# 0003 — Wear the avatara Thoth archetype (name = archetype = function)

**Status**: Accepted
**Date**: 2026-06-08

## Context

thoth is the user-facing front-end/driver for the end-user dev workflow on AGNOS, and it owns no domain logic of its own — including personality. Per the own-the-stack standard, divine archetypes belong to avatara: when AGNOS has a crate for a domain, thoth depends on it and never reimplements. So thoth's personality overlay is not a thing thoth builds; it is a thing thoth pulls.

A "Thoth"/Librarian archetype already exists in avatara (see `vision/maat-42.md` and `planning/hadara.md` in the sibling repos). The project name is also Thoth — the Egyptian god of writing, scribes, and wisdom — and that name is settled. This creates a visible alignment: the tool's name, the archetype it wears, and the function it performs (a scribe that reads, plans, writes, and heals code) are the same idea. The question this ADR settles is what to make of that alignment — whether the shared name is a collision to be designed around, or the design itself.

Two facts make this a real decision rather than a default. (a) A name being both a personality and a program is normal — `Claude` is both an assistant persona and the program that wears it — so the overlap is not inherently a problem to be renamed away. (b) avatara archetypes are normally overlaid BY the system onto whatever tool is running; a tool reaching out and pulling the archetype that happens to match its own name is the unusual direction. If we adopt it casually, a future reader could mistake it for a general mechanism ("namesake tools auto-pull matching archetypes") rather than the one-off coincidence it is. The posture must be fixed deliberately so the special case is documented as special.

thoth is fermenting: scaffolded via `cyrius init`, no feature code yet, and avatara is not a declared dependency in `cyrius.cyml` (stdlib deps only). This ADR fixes identity now — which archetype thoth wears and why the name-match is intentional — before any code entrenches a hand-rolled persona.

## Decision

thoth deliberately wears the existing avatara "Thoth"/Librarian archetype as its personality overlay, pulled from avatara rather than reimplemented; the shared name is the design, not a collision.

In scope:

- thoth's persona is the avatara Thoth/Librarian archetype (the scribe: reads a task, plans, edits files, runs tools, iterates), consumed from avatara through the same capability seam as every other AGNOS-owned domain — on AGNOS the archetype is pulled native from avatara; off-AGNOS it degrades to a static bundled persona descriptor reached over the same contract, announced as degraded, never re-authored in-tree.
- Documenting this as a special, on-the-nose case where name = archetype = function all align by intent, with the namesake-pulls-its-own-archetype direction noted explicitly as the exception.

Out of scope:

- Generalizing this into a mechanism — "namesake tools pull matching archetypes" is NOT a pattern thoth establishes; the normal direction stays system-overlays-archetype-onto-tool.
- A thoth-owned or hand-rolled personality, or any per-app persona maintained in thoth.
- Declaring avatara as a real `cyrius.cyml` dependency while thoth is fermenting (it stays prose in state/roadmap; the manifest keeps stdlib deps only), and committing to the off-AGNOS persona-descriptor transport now (deferred with the rest of the off-AGNOS reach).

## Consequences

**Positive**

- On-the-nose coherence: name, archetype, and function are one idea, so the tool's identity reads as intentional rather than coincidental — a scribe named Thoth that wears the Thoth archetype and behaves like a scribe.
- Own-the-stack is upheld for personality too — the archetype is single-sourced in avatara, so persona behavior, voice, and any future archetype refinement flow from one place and are never re-verified or re-authored per app.
- No per-app personality to build or carry: thoth stays a pure front-end that owns no domain logic, personality included.

**Negative**

- A real misreading risk to police: this must not be taken as a general rule that namesake tools pull their matching archetypes. It is a one-off coincidence (name = archetype = function happen to align here); the normal flow is the system overlaying an archetype onto a tool, and that must be reinforced in review and docs so the special case is not mistaken for a mechanism.
- Off-AGNOS the persona is only as faithful as the bundled static descriptor (degraded, announced), not the live avatara overlay — parity in personality, as elsewhere, is an AGNOS-only promise.

**Neutral / follow-on**

- An architecture note should record the invariant that thoth's persona is consumed from avatara (never thoth-owned) and that the namesake pull is a special case, not a general pattern.
- state/roadmap should describe avatara as an intended future dependency (Thoth/Librarian archetype overlay) in prose, with the real `cyrius.cyml` git-dep deferred until thoth leaves the fermenting stage.

## Alternatives considered

**A distinct generic persona (don't wear the matching archetype).** thoth could carry a neutral, thoth-specific persona to sidestep any appearance of a name collision. Rejected — it reimplements personality that avatara already owns (a direct own-the-stack violation), discards the genuine coherence of name = archetype = function, and trades a perfectly-aligned identity for a generic one purely to avoid a coincidence that is actually a feature.

**Rename thoth to break the name-match.** Renaming the tool would make the archetype overlay unremarkable. Rejected — the name is settled (Egyptian Thoth, god of writing/scribes/wisdom; backronym Thinks, Handles, Orchestrates, Transforms, Heals), and a name being both a personality and a program is normal (cf. `Claude`). There is nothing to fix; the alignment is the design.

**Adopt it as a general mechanism (namesake tools auto-pull their archetype).** Tempting to formalize the convenience into a rule. Rejected — it would invert avatara's normal direction (the system overlays archetypes onto tools) into a tool-driven pull as standard behavior, which is not the model. This is a special, on-the-nose case only; generalizing it would misrepresent how archetype overlay works.
