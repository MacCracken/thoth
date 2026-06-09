# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

- [001 — Consumer-only: thoth holds no first-party domain logic](001-consumer-only-no-domain-logic.md) — *Affects: anyone adding inference / MCP / security / personality code.* thoth contains no LLM-inference, MCP-protocol, MCP-security, or personality logic of its own — all of it lives in hoosh / daimon / bote / t-ron / avatara, and thoth only drives them. New capability code belongs in the owning crate, consumed through a seam — never in-tree here.
