# Architecture Decision Records

Decisions about thoth — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

- [0001 — OS-agnostic reach, AGNOS-primary home](0001-os-agnostic-agnos-primary.md) — *Accepted.* thoth is OS-agnostic at the substrate layer and AGNOS-sovereign at the capability layer: port the floor, never fork the spine.
- [0002 — Consume the AGNOS stack, do not reimplement](0002-consume-the-agnos-stack.md) — *Accepted.* thoth depends on hoosh / daimon / bote / t-ron / avatara for every domain it touches and builds none of that logic itself.
- [0003 — Wear the avatara Thoth archetype](0003-wear-the-avatara-thoth-archetype.md) — *Accepted.* thoth pulls the existing avatara Thoth/Librarian archetype as its personality overlay; the shared name is the design, not a collision.
- [0004 — SemVer 0.x in pre-release, not CalVer](0004-semver-pre-release.md) — *Accepted.* thoth keeps SemVer 0.x through pre-1.0 rather than cut to CalVer now; the post-1.0 scheme is deferred.
- [0005 — The hoosh seam binds remote-client over HTTP via sandhi](0005-hoosh-seam-remote-over-sandhi.md) — *Accepted.* M3 reaches hoosh as an OpenAI-compatible HTTP gateway transported by sandhi; `thoth.cyml` configures it; the mid-session model switch is just the next request's `model` field.
