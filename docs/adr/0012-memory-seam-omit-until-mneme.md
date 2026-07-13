# 0012 — Memory seam: omit-until-mneme (thoth reads + injects; mneme owns the engine)

**Status**: Accepted
**Date**: 2026-07-02

> **Update (0.32.x — the native branch is now live).** mneme has since been **Cyrius-ported and is consumed** — the
> 0.32.x memory arc wired the seam through daimon's MCP registry: `/remember` → `mneme_create_note`, per-turn
> semantic recall via `mneme_search` (0.32.2), cited sources (0.32.3), the grounding indicator (0.32.4), and
> `/notes` vault browse (0.32.6). The **producer swap this ADR anticipated has completed**: the local
> `.thoth/memory/` reader is now the *degraded fallback* when daimon does not advertise the `mneme_*` tools, not the
> only path. The decision below stands as recorded; the "not yet ported" framing in the Context/Consequences is
> historical. See the CHANGELOG (0.32.x) and [architecture note 002](../architecture/002-capability-ladder.md).

## Context

Users want thoth to carry **project-local memory** — read a project's context
files and remember durable facts across sessions, localized to the project
(`.thoth/memory/`). The obvious hazard: **memory is not thoth's domain.**

The AGNOS family already owns memory as a first-party capability — **mneme**
(Greek μνήμη), an "AI-native knowledge base and personal notes" with semantic
search, auto-linking, and RAG (<https://github.com/MacCracken/mneme>). mneme is
still **Rust, not yet ported to Cyrius**, so thoth's Cyrius spine cannot consume
it *yet*. Its client contract is already fixed: **`mneme-mcp` exposes 8 MCP
tools** (`mneme_create_note`, `mneme_search`, `mneme_get_note`,
`mneme_update_note`, `mneme_query_graph`, `mneme_search_feedback`,
`mneme_list_vaults`, `mneme_switch_vault`), and its notes are **file-backed
markdown vaults**.

thoth's prime directive ([ADR-0002](0002-consume-the-agnos-stack.md),
[architecture 001](../architecture/001-consumer-only-no-domain-logic.md)) is
**consume the spine, never fork it**. Building a memory *engine* in thoth —
retrieval, embeddings, ranking, auto-linking, curation — would be a textbook
spine fork.

But there is a slice that is unambiguously thoth's, and it is **the verb thoth
already ships**: context assembly. thoth reads the avatara persona
(`persona_system_prompt`, `src/session.cyr:209`) and the conversation-history
tail (`_hoosh_history_start`, `src/hoosh.cyr:338`) and threads both into every
request as leading `{role:system}` messages. Reading local context files and
injecting them is the **same operation over a different source** — nothing new
in kind.

## Decision

**Model memory as a capability seam (`SEAM_MEMORY`) on the existing ladder
([ADR-0006](0006-m4-tool-spine-daimon-bote-tron.md) /
[ADR-0009](0009-presentation-capability-ladder.md)), that binds to mneme when
present and degrades to a thin thoth-owned local reader when absent — announced
honestly, never faked.** This is the **omit-until-owner** shape
([ADR-0010](0010-data-producer-honest-omit.md)), the exact `git → sit` pattern:
a thoth-owned stand-in the real domain owner supersedes with a producer swap.

- **The bright line (litmus test).** thoth owns **reading + injecting**; mneme
  owns the **engine**. The test for any future request: *"does it require
  understanding the memories' CONTENT?"* — recency and byte-budget need no
  content understanding (→ thoth); ranking, embeddings, relevance selection,
  auto-link, graph traversal, summarization, dedup all do (→ mneme). **Relevance
  selection IS retrieval, and retrieval is mneme's.** Selection stays
  content-blind (newest-first + a byte budget), guarded in code comments and here.

- **Native branch (mneme present).** mneme fronts via MCP, so it registers with
  **daimon** exactly like bote; thoth discovers `mneme_*` tools through the
  *existing* daimon registry — **no new transport, no new thoth config**. RAG /
  ranking / graph all execute in mneme; thoth only drives. `seam_cap_state →
  CAP_FULL`.

- **Fallback branch (mneme absent — shipping now).** A dumb flat-file reader
  (`src/memory.cyr`): `.thoth/memory/MEMORY.md` (curated index, always injected)
  + `*.md` fact files, newest-first until a **4 KB** budget fills
  (stop-at-fact-boundary), injected as a second `{role:system}` message **after**
  the persona, **before** history. Notes carry frontmatter matching mneme's vault
  format, so the local store is **later ingestible by mneme — the fallback is not
  throwaway.** `seam_cap_state → CAP_DEGRADED`.

- **Opt-in (`[memory].enabled`, default off).** Injecting `.thoth/memory` makes
  its contents a system message the model obeys; a repository could ship a
  `.thoth/memory` to steer an agent (a prompt-injection surface, the same trust
  question as `CLAUDE.md`). So auto-injection is **off by default** —
  `seam_cap_state → CAP_ABSENT`, byte-identical floor — and the user opts in.

- **Writes are verbatim, t-ron-gated, never curated.** `/remember <text>` and a
  `memory_write` MCP tool append the literal bytes to a flat `.md` file through
  the **existing** t-ron choke point (reserved name `thoth_remember`,
  `src/gate.cyr`). thoth does **not** summarize, dedupe, auto-tag, embed, rank, or
  link — every one of those is mneme-ai's job. Curation is the human's (edit the
  files) or mneme's.

## Consequences

- Users get project-local memory today; the seam reports its honest state
  (`full` mneme / `degraded` local / `absent` off) in `/seams` + `/state`.
- The swap to mneme is a **producer swap behind one injection point** — zero
  change to the request builders — the day mneme's Cyrius port registers with
  daimon.
- **Cardinal risk — relevance-creep.** "Select the memories *relevant* to this
  turn" is one commit from becoming retrieval, i.e. a spine fork. The selection
  logic MUST stay content-blind; this ADR and the code comments are the guard.
- **Prompt-injection** is mitigated by opt-in + t-ron-gated writes +
  escaped-not-executed content, but a checked-in `.thoth/memory` remains a trust
  decision the user makes by enabling the seam.
- **AGNOS write residuals** (no portable `fchmod` / `O_NOFOLLOW`, `sys_open`
  carries no mode channel) are the same honesty debt as `[history].file`
  ([roadmap](../development/roadmap.md)); documented, never a mode we can't enforce.

## Slot

A new non-gating **0.12.x "memory seam"** line: `0.12.0` seam + local reader
inject, `0.12.1` `/remember`, `0.12.2` `memory_write` tool + `AGENTS.md` pickup.
The **git producer moves to 0.13.0** — it is externally gated on **sit** shipping
`.git/` read-mode and may sit dormant, whereas the memory fallback is
thoth-drivable now.

Cross-references: [ADR-0002](0002-consume-the-agnos-stack.md),
[ADR-0006](0006-m4-tool-spine-daimon-bote-tron.md),
[ADR-0009](0009-presentation-capability-ladder.md),
[ADR-0010](0010-data-producer-honest-omit.md).
