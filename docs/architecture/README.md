# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

- [001 — Consumer-only: thoth holds no first-party domain logic](001-consumer-only-no-domain-logic.md) — *Affects: anyone adding inference / MCP / security / personality code.* thoth contains no LLM-inference, MCP-protocol, MCP-security, or personality logic of its own — all of it lives in hoosh / daimon / bote / t-ron / avatara, and thoth only drives them. New capability code belongs in the owning crate, consumed through a seam — never in-tree here.
- [002 — The capability ladder: binding mode × capability effect](002-capability-ladder.md) — *Affects: anyone reading or extending the seam registry / `/seams`.* Each seam has two orthogonal dimensions — binding mode (native / remote-client / absent) and capability effect (full / degraded / absent) — and the second can't be inferred from the first: absent t-ron is **degraded** (the fail-closed gate), never absent; mneme binds remote-client via daimon (**full** recall when hosted), and an *absent* binding is still **degraded** (the local `.thoth/memory` reader) when `[memory].enabled`, not dead. The ladder spans all seven seams (hoosh, daimon, bote, t-ron, avatara, mneme, sit) and is computed live from `src/seams.cyr`, not narrated by hand.
