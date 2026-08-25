# 0018 — Subagent delegation: a scoped child *context*, not an orchestrated agent

**Status**: Accepted
**Date**: 2026-08-24

## Context

Every surveyed agentic-coding harness — Claude Code, Codex, OpenHands, Cursor, Goose — landed on the
same answer to the same two problems:

1. **A noisy sub-investigation permanently costs the parent's context window.** "Find where this symbol
   is defined" means grepping the tree, reading ten files, and reporting three lines. The three lines
   are the answer; the ten files are the cost, and once they are in the transcript they are in the
   transcript for the rest of the session. thoth feels this acutely: `[hoosh].summarize` exists
   precisely because the window fills, and `/compact` exists because it fills faster than the byte
   framer's boundary.
2. **One context cannot be worked in parallel.** Two independent questions serialize behind each other
   even when neither needs the other's findings.

thoth has every ingredient and closes neither. It has a keyed conversation store with `conv_fork`
(0.41.0), a full tool-calling loop with a configurable iteration cap (0.40.0), and a condenser
(`[hoosh].summarize`, 0.36.4). What it does not have is a way to spend context that does not come out
of the parent's window.

**The reason this ADR exists at all** is that the feature brushes the one rule thoth is most careful
about. [ADR-0002](0002-consume-the-agnos-stack.md) says thoth owns no domain logic and consumes the
spine; **orchestration is daimon's declared domain**, and agnosai — now Cyrius-ported — owns crews,
task DAGs, 18 agent presets and a scheduler. A naive reading says "multiple agents = orchestration =
not thoth's", and the roadmap deliberately blocked implementation until this was settled in writing.
The 0.39.0 gap review listed it as *"the biggest architectural question in the list"* and refused to
answer it.

## Decision

**Add subagent delegation to thoth, as a scoped child *context* — and draw the line at identity.**

The distinction that resolves the spine question:

> **If it needs an identity, a persona, a registry entry, or a peer, it is orchestration and belongs
> to the spine. If it is one conversation's own context, windowed, it is thoth's.**

A thoth subagent is the second thing. Concretely, it has:

- **no identity** — it is not named, not registered anywhere, not addressable;
- **no persona** — the avatara overlay is the parent's, unchanged (agnosai's own `AgentDefinition`
  has no personality field for exactly this reason: that axis belongs to avatara);
- **no registry entry** — daimon never hears about it; daimon hosts *tools*, and the child calls the
  same tools through the same daimon the parent does;
- **no peer** — a subagent cannot talk to another subagent, cannot be scheduled, cannot join a crew;
- **no lifetime** — it exists between one tool call and its return, then it is gone.

What it *is*: the parent's own model, its own tools, and its own system prompt, run over a **fresh,
empty message list** for a bounded number of rounds, returning **one string**. That is not an agent in
any sense daimon or agnosai would recognise. It is `[hoosh].summarize`'s sibling: summarize condenses
what the window can no longer hold *behind* you, delegation bounds what an investigation will cost
*ahead* of you. Both are context management over thoth's own conversation, and it would be incoherent
to ask daimon — which does not know thoth has a context window — to do either.

### The fence (non-goals, and they are the load-bearing half)

This ADR is a **fence, not a permission slip**. thoth must NOT grow, under this or any successor:

- **named specialist agents / roles / presets** — that is agnosai's `AgentDefinition` + avatara;
- **crews, task DAGs, or a scheduler** — agnosai;
- **inter-agent messaging or a shared blackboard** — orchestration;
- **subagents with a lifetime beyond their tool call**, or that persist to disk;
- **a subagent registry, or subagents addressable by name**;
- **depth > 1** (see below) — recursion is the door through which "a crew" arrives by accident.

The moment a requirement needs one of these, the answer is to consume agnosai or daimon, not to grow
thoth. If that day comes, this ADR should be superseded explicitly rather than stretched.

### The shape

The model gets one new tool, **`delegate(task, ...)`**, which:

1. **Is depth-capped at 1.** A subagent cannot delegate. This is not a simplification to revisit
   later — it is a security and cost boundary. Unbounded recursion is unbounded spend, and thoth has
   **no budget enforcement today** (a known gap, recorded in `gap-review.md`); an iteration cap bounds
   rounds, not money. Depth 1 makes the worst case arithmetic instead of exponential. It also caps
   re-entrancy at exactly one nested level, which is what makes the implementation provable rather
   than hopeful.

2. **Runs SERIAL, at both levels.** A round containing `delegate` is forced through the serial
   executor by the existing `_agent_round_has_local` mechanism (the same treatment `search`, `edit`
   and `shell` already get), so the parallel daimon workers are never live while a child runs. The
   child itself dispatches its tools serially. This removes the entire `_par_*` slot-collision hazard
   by construction rather than by careful sharing.

3. **Starts from an EMPTY message list.** The child does not inherit the parent's transcript — that
   is the whole point. It receives the system prompt, the project/memory preamble the parent gets, and
   the task string. It cannot see what the parent has been discussing, which is a limitation to state
   honestly: a task that needs conversational context must have that context written into the task
   string by the parent.

4. **Returns ONE string, through the normal tool-result chokepoint.** The child's final assistant text
   becomes the `delegate` call's tool result, folded in by `_agent_add_result` — which means it passes
   through **`redact_tool_result` and then `guard_wrap_untrusted` automatically**, exactly like any
   other tool result. This matters: a child that read an untrusted file could carry an injection
   payload in its summary, and routing it through the existing chokepoint means that case is already
   handled rather than needing a new control.

5. **Inherits every safety seam, unchanged.** The child's tool calls run through the same
   `hooks_pre_tool` block, the same t-ron `gate_authorize`, the same `_project_read_ok` /
   `_project_no_symlink` / `_project_sensitive` jail, the same `ckpt_capture` write gate, the same
   `toolpin` advertisement gate, and the same `[verify]` loop. **A subagent grants the model no
   authority it did not already have** — it can only call tools the parent was already offered, under
   the same policy. What it changes is *how much* the model can do per user turn, not *what*.

6. **Inherits session grants (0.40.0, T1-6), deliberately.** The alternative — re-prompting inside a
   subagent — recreates the exact prompt-fatigue that T1-6 removed, and would do it in a context where
   the user has less visibility, not more. Grants are session-scoped and the child runs inside the
   same session and the same user turn. Every child tool call is still individually gated and still
   lands in the libro audit chain, so nothing becomes invisible; the grant decides one question the
   user already answered.

7. **Has its own iteration budget** (`[subagent].max_iters`), separate from the parent's, and its own
   round accounting. A child that exhausts its budget returns what it has with the exhaustion stated,
   never silently.

8. **Is opt-in (`[subagent].enabled`, default off)** — and the reason is *not* that it adds authority,
   because it does not. It is that it **multiplies spend** against a system with no budget enforcement.
   thoth's convention is that a capability which is merely useful is default-on (the read tools,
   `search`) and one that is consequential is opt-in (`shell`, `edit`, `[verify]`, `[hooks]`).
   Multiplying token cost is consequential. If budget enforcement lands, this default should be
   revisited.

### Why `delegate` and not `task`

The field convention is `Task` (Claude Code). thoth already has `/task`, `cmd_task` and
`_task_dispatch` meaning "one model turn", and a model tool called `task` sitting beside them would
make every future reader disambiguate. `delegate` is unambiguous inside thoth and self-describing to
the model, which reads the tool's *description* far more than its name.

### Resolved design decisions

A six-lane audit of the tree was run before this ADR was accepted, because the feature's risk is
concentrated in state, not in logic. It found **~60 process-global `var`s across 21 files** that a
naively re-entrant child would corrupt. The decisions below are answers to what it surfaced.

**D1 — The child is a SIBLING loop, not a re-entry.** `delegate` does not call `agent_turn`. It runs a
purpose-built loop with **its own** request, tools, accumulator and result buffers. This is possible
cheaply because the two builders that matter are already destination-parameterized —
`agent_format_tools(dst, …)` and `agent_build_request(dst, …)` — so the child passes its own storage
and the parent's is never addressed. The per-tool dispatch arms are **extracted** into one reusable
function that returns a result string and touches no accumulator, so the parent's serial executor and
the child call the *same* code and cannot drift into two authorization paths.

⚠ **The first enumeration was WRONG, and the correction is the useful part of this section.** An
adversarial review of the implementation found `_roundlog_cur` missing from the swap set — and the
symptom was not a crash but a *lie*: a child's tool calls flat-appended into the parent's open round and,
past the per-round cap, silently evicted the parent's own, so the round card and the persisted turn
reported tools the parent never called. The test written to defend this very claim checked the byte
buffers and passed. **The question a swap set must answer is "does a tool round WRITE it", not "is it a
buffer"** — and the answer must come from a test that fails when the swap is removed, not from reading
the list. `_sub_enter` now also closes the parent's round for the duration, which additionally keys any
child edit under a round number no parent card ever looks up.

Rejected alternatives, with the reason: **save/restore around a nested `agent_turn`** (the big buffers
would need memcpy both ways, and several seams' out-parameter globals have live windows *inside* a
dispatch arm rather than around it); **a full context-struct refactor** (correct, but it touches
agent.cyr and hoosh.cyr wholesale and still leaves ~20 collaborator modules needing copy-out
discipline); **a subprocess child** (bulletproof on state, but the child's libro audit chain would die
with the process — `/audit` would report a chain that is cryptographically intact and *factually
incomplete*, which is worse than no chain, since `audit_verify_chain` would still say "integrity OK").

**D2 — `delegate` MUST be registered in `_agent_round_has_local`. This is a security requirement, not
a correctness one.** The parallel executor fires **no `hooks_pre_tool` and no events** — those exist
only on the serial path. A multi-call round containing an unregistered `delegate` would route through
the parallel path and skip the operator's blocking security hook entirely, turning a state bug into an
**authorization bug**. One line, and it is load-bearing.

**D3 — The child runs under the PARENT'S sink, not a suppressed one.** Nothing required the child to
be bracketed in `OUT_NULL`, and bracketing it would break two things at once: `confirm` degrades to a
**deny** under a non-interactive sink, and — worse — the `[session grant]` announcement is `ui_emit`
output that would be *discarded*. `gate.cyr` says in as many words that "a silent auto-allow is
indistinguishable from having no gate at all". The child's tool calls are therefore announced exactly
like the parent's, marked as the child's.

**D4 — Session grants inherit.** Given D3 the objection largely dissolves: the grant still announces
itself, every child tool call is still individually gated, and every one still lands in the audit
chain. Grants are exact `(verb, object)` matches rather than patterns, and can never override a policy
DENY. The alternative is not "ask again" but "the subagent cannot use gated tools at all", which is a
worse and less honest outcome.

**D5 — The child authorizes as the SAME t-ron agent, and delegation itself is gated under a new
reserved verb `thoth_delegate`.** Same id means every existing `[tron].policy` keeps covering the child
unchanged; the new verb means a policy can refuse delegation outright, on the existing
`thoth_run`/`thoth_shell` split precedent. **Stated limitation:** a policy can say "no subagents"; it
cannot say "subagents, but no `shell`". The child shares the parent's rate-limit bucket and risk score.

**D6 — The child's turn number is the parent's.** The delegation happens *inside* the parent's turn, so
`/rewind` undoing that turn should undo the child's writes with it — that is what a user asking to undo
a delegated task means. **Residual, stated:** `CKPT_MAX` is 64 and evicts oldest-first, so a chatty
child can age out an *earlier* turn's undo entries through the perfectly-authorized `create_file` path
— no jail break, no policy violation. The child's separate, deliberately small iteration budget is the
bound on this; it is a mitigation, not a guarantee.

**D7 — The events bracket is NOT reused.** `turn_end` last with exactly one `response`/`error` before
it is a documented contract, and nesting a second bracket inside it would reintroduce the precise
defect 0.42.0's live testing found. The child emits its own `subagent_start` / `subagent_end`, and its
tool events carry a `depth` field, present only when non-zero so a non-delegating run's stream stays
byte-identical.

**D8 — `[verify]` is suppressed inside the child.** Otherwise every child write triggers a full project
build, N×M times per turn, and `_verify_last_ok`/`_verify_runs` are single globals whose child values
would overwrite what `/state` reports about the parent's last verification.

## Consequences

**Good.**

- The highest-cost thing a coding agent does — locating something in a tree it does not know — stops
  costing the parent's window. This compounds with `search` (0.40.0): the child can spend six rounds
  grepping and return one path.
- The spine rule gets a *sharper* statement than it had. "Orchestration belongs to daimon" was true
  but under-specified; "identity, persona, registry, or peer ⇒ spine" is a test a future contributor
  can actually apply.
- The mechanism is mostly existing parts: the serial executor, the tool-result chokepoint, the gate,
  the jail. The genuinely new code is a bounded child loop and its buffer discipline.

**Costs and risks, stated plainly.**

- **Re-entrancy is the real engineering risk.** `src/agent.cyr` keeps its round state in module-level
  buffers — the request buffer, the work/result accumulator, the parsed tool-call slots, the
  reconstructed tool-calls array. A child running inside a parent's live round would clobber them. The
  implementation must give the child its own storage and prove the parent's is untouched; the
  mitigating fact is that every write to the accumulator funnels through five small functions
  (`_agent_work_reset/putc/puts/puts_esc/sep`) and one read site in `agent_build_request`, so the
  surface is enumerable rather than diffuse. This ADR does not prescribe the mechanism, but it does
  require that the choice be *provable by enumeration*, not by inspection.
- **The child cannot see the conversation.** Stated as a limitation, not hidden. A parent that needs
  the child to know something must say it in the task string.
- **Cost is multiplied, and thoth cannot yet stop it.** Depth 1 + a separate iteration cap + opt-in are
  the three bounds available today. Real budget enforcement remains an open gap.
- **A new injection lever exists, and it is bounded rather than removed.** Untrusted content the model
  reads could tell it to delegate. Depth 1 caps the blast radius at one extra bounded loop, the child
  gets no new authority, and the child's output is redacted and guard-wrapped on the way back. This is
  a mitigation, not a boundary — the same honest framing `[guard]` carries.

## Alternatives considered

- **Consume agnosai's crew runner.** Refused, and not narrowly. Its LLM layer names `thoth/src/hoosh.cyr`
  as its own reference implementation and has **no tool-calling at all** (zero `tool_calls` references
  across `llm/` and `crew_runner`), no SSE streaming, no reasoning effort and no mid-session switching —
  thoth would be importing a weaker copy of itself to gain a feature it would then have to reimplement.
  Its tool registry also competes with daimon's. Wrong seam, wrong direction.
- **Ask daimon to host subagents.** Incoherent at the boundary: daimon executes *tools* on behalf of a
  caller and knows nothing about thoth's conversation, its context window, its persona, or its jail. A
  daimon-hosted subagent would need all four handed to it, which is thoth's domain leaking outward
  rather than daimon's capability being consumed.
- **`conv_fork` + manual switching as the whole answer.** Already shipped and genuinely useful, but it
  is an *operator* affordance: the user forks and drives. It does nothing for the model's own
  sub-investigations, which is the actual cost problem.
- **Depth > 1 with a total-node cap.** Rejected for the first cut. It buys little (a subagent that needs
  a subagent usually wants a crew, which is the thing this ADR fences off) and costs the one property
  that makes the buffer discipline provable.
- **Default-on.** Rejected only on spend, and the reasoning is recorded above so the default can be
  revisited on its actual merits if budget enforcement lands.

## References

- [ADR-0002](0002-consume-the-agnos-stack.md) — the consume-the-spine mandate this ADR is bounded by.
- [ADR-0015](0015-project-read-tools-jailed-default-on.md) / [ADR-0017](0017-model-edit-tool-jailed-gated-opt-in.md)
  — the default-on vs opt-in convention applied above.
- [ADR-0010](0010-data-producer-honest-omit.md) — omit-until-present, applied to the child's round
  accounting.
- `docs/development/gap-review.md` — budget enforcement and structural isolation of untrusted content,
  both of which this ADR touches and neither of which it closes.
