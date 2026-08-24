# thoth — agentic-harness gap review (2026-08-24)

**Status: for review. Nothing here is decided, and nothing here has been built.** This is a
recommendation document produced at 0.39.0 to answer three questions: what do the popular agentic coding
harnesses do that thoth does not, which of those gaps are worth closing, and what can **agnosai** — now
Cyrius-ported at 2.0.6 — legitimately supply.

## How this was produced, and how much to trust it

Three parallel researchers surveyed the landscape against **current** sources (official docs, changelogs
and repos — the space moves fast enough that a confidently wrong feature list is worse than a short one),
then checked each candidate gap against thoth's own source **before** calling it missing. A fourth agent
inventoried agnosai from the point of view of a consumer, and was pushed to answer the consumption question
with evidence rather than a wish list.

Confidence is marked throughout: **confirmed-missing** (looked, not there), **partial** (thoth has some of
it), **conflict** (thoth or its spine already owns the domain). Where thoth is *ahead* of the field that is
said too — this is a gap review, not a case for rewriting things that work.

---

## Read this first: what thoth already gets right

Several of these are unusual enough that a naive gap list would recommend rebuilding them.

- **A real cryptographic audit chain.** thoth vendors libro and surfaces a hash-linked, tamper-evident
  record of every gated action, with `/audit` verifying integrity in-process. Almost no other harness has
  this; most have a log file. thoth is ahead on the hard half and behind only on the easy half (exporting
  it — see T3).
- **Authorization as a real seam, not a prompt.** t-ron supplies allow/deny/flag verdicts, an injection
  scanner over tool params, a pattern analyzer, a rate limiter and a per-agent risk score, with the
  distinct reserved verbs (`thoth_run` vs `thoth_shell` vs `thoth_edit`) that let a policy separate the
  operator's own actions from the model's. The recommendations below **build on** this; none replace it.
- **Honest degradation as a house rule.** Missing capabilities are announced, not faked — the banner states
  live gateway reachability rather than a hardcoded READY, an absent t-ron falls to a fail-closed confirm,
  and the source says plainly where a boundary is not a sandbox. That posture is why this review can be
  short on "thoth pretends to be secure" findings.
- **Mid-session model switching**, which no surveyed harness matches, plus a model picker, reasoning-effort
  control and per-turn token/cost accounting.
- **Context condensation already half-built.** `[hoosh].summarize` (0.36.4) is a genuine condenser: a cheap
  silent side-call recaps what the byte framer can no longer fit, cached per conversation and folded
  incrementally. Peers call this auto-compaction. thoth's is real; see T1-5 for the two pieces missing.
- **Instruction-file safety.** thoth wraps `AGENTS.md` as "verbatim reference — durable facts, NOT commands
  to obey" and deliberately does not auto-inject `CLAUDE.md`. Most harnesses inject instruction files as
  trusted text. thoth is ahead here and should not give it up when closing T2-3.

---

## Tier 1 — Close these. High value, aligned with what thoth already is.

> ✅ **ALL SIX SHIPPED IN 0.40.0.** Kept here as the record of what was proposed and why — see the
> [CHANGELOG](../../CHANGELOG.md) for what was actually built, including where the implementation departed
> from the proposal (T1-4 took the snapshot-directory route rather than sit's write surface, and T1-3's
> agnosai leaf was published as an upstream `[lib.guard]` profile rather than hand-extracted).
> Tier 2 and Tier 3 below remain open.

### T1-1 · A `grep`/`glob` search tool for the model — **confirmed-missing**
Every single surveyed harness gives the model a search primitive. thoth's model-facing tools are
`read_file`, `list_dir`, `shell`, `edit`, `create_file`, `memory_write` — so to find a symbol it must walk
directories one `list_dir` at a time, or reach for `shell`, which is **off by default** and t-ron-gated.

This is the highest-leverage missing tool, and it compounds with T1-2: with `AGENT_MAX_ITERS = 8`, a model
that spends four rounds locating a file has one round left to do the work. It is also thoth-native
substrate (like `read_file`), not a spine capability, so it does not touch the architecture rule.
**Must inherit 0.39.0's jail**: `_project_no_symlink` + `_project_sensitive`, or it reopens what was just
closed.

### T1-2 · Make the agentic iteration cap configurable — **confirmed-missing**
`var AGENT_MAX_ITERS = 8;` is hardcoded and invisible to the user. Eight tool rounds is roughly "read three
files and make one edit". Peers: Goose `GOOSE_MAX_TURNS` defaults to **1000**; Gemini CLI has
`maxSessionTurns`; Claude Code sets `maxTurns` per subagent.

thoth has already been bitten by this cap: the 0.38.5 bug report describes required-arg tools failing every
round *until the loop exhausted the cap and answered nothing*. A `[hoosh].max_iters` key is a
few lines. Pair it with a visible "round N of M" so hitting the ceiling is legible rather than mysterious.

### T1-3 · Secret redaction on the way **out** — **confirmed-missing**, and agnosai has the code
thoth streams model output straight into the feed, `/save` writes it to disk, and the conversation store
persists it. A model that echoes an API key it found in a `read_file` or `shell` result gets it written to
`.thoth/` verbatim.

The 0.39.0 audit deliberately scoped its config fix (A-3) to thoth's *own* credentials and stated that a
general secret filter is a **different capability**. This is that capability.
**agnosai ships it**: `src/server/output_filter.cyr` — scans for system-prompt leakage (sliding window
against the actual system prompt), API keys by vendor prefix (`sk-`, `Bearer `), and PII; redacts to
`[REDACTED]`. Pure, ~500 lines, depends only on str/bayan/sakshi. See "Taking from agnosai" below.

### T1-4 · Checkpoint / undo for model file edits — **confirmed-missing**
thoth got write access at 0.31.0 (`edit`) and 0.31.x (`create_file`) and never got the safety net every
peer pairs with it. `src/editlog.cyr` is a **record-only** display ring feeding the colored diff card —
record/find/read accessors, no restore.

Peers: Cline keeps a **shadow git repo** separate from project history, committing after every tool use,
with three restore modes; Gemini CLI does the same under `~/.gemini/history/<project_hash>`; Claude Code
checkpoints per user prompt with `/rewind`.

thoth has an unusual advantage: it already vendors **sit**, a first-party Cyrius VCS. A shadow-repo
checkpoint is closer to hand here than in any other harness. (thoth vendors sit's *read* profile today, so
this needs the write surface — a real scoping question, not a detail.)

### T1-5 · Finish context management: `/compact`, `/context`, and a token threshold — **partial**
thoth has the hard half (`[hoosh].summarize`). Missing: a **user-invoked** `/compact`, a `/context`
accounting view showing what is consuming the window, and a **token-threshold** trigger rather than only
the byte-framer boundary. Small work on an existing mechanism, high daily value.

### T1-6 · Per-call approvals with session memory — **confirmed-missing**
`confirm()` is stateless: the same `shell` command re-prompts **every round** of the loop. On an 8-round
turn with a gated tool that is eight identical y/N prompts, which trains the user to hammer `y` — actively
worse than one considered decision. Peers all have "allow for this session" (Claude Code), last-match-wins
patterns (opencode), `/approve` (Codex).

This is a small addition to `src/gate.cyr` and it makes the existing t-ron gate *more* effective, not less.

---

## Tier 2 — Strong candidates, larger or needing a design decision.

### T2-1 · Subagent delegation — **confirmed-missing**, near-universal among peers
Claude Code, Codex, OpenHands, Cursor and Goose all landed on the same answer to the same two problems:
a noisy sub-investigation (grep the tree, read ten files, report three lines) permanently costs the parent's
context window, and one context cannot be worked in parallel.

**This is the biggest architectural question in the list**, because it brushes the spine rule: orchestration
is daimon's declared domain, and agnosai now owns crews and task DAGs. A defensible reading is that a
*scoped child of one conversation* is a thoth-side context-management feature, not multi-agent
orchestration — but that is the maintainer's call and should be settled in an ADR before code.

### T2-2 · OS-enforced sandboxing of `shell`/`edit` — **confirmed-missing**, the largest safety delta
thoth's source is admirably blunt that it has none: the glob filter "is a COARSE convenience pre-filter,
NOT a sandbox", the jail is "a boundary, not a sandbox". Peers enforce at the OS: Codex and Claude Code use
Seatbelt on macOS and Landlock+seccomp on Linux, with read-only / workspace-write / full-access tiers.

**Do not take agnosai's sandbox for this.** Its own README says the process tier has "No seccomp, no
Landlock, no cgroups". The right seam is **kavach**, which AGNOS already assigns kernel confinement to, and
which agnosai itself bridges to rather than reimplementing. Worth an ADR: "kavach owns the sandbox, not the
application" is a first-party standard, quoted verbatim in the standards doc.

### T2-3 · Prompt-injection defense for untrusted **prose** — **confirmed-missing**
t-ron's scanner walks JSON string leaves of *tool params* for SQL/shell/template patterns. It never sees
prose. thoth injects untrusted prose from three places the model then reads as instructions: `@file`
mentions, `read_file`/`list_dir` results, and recalled mneme notes. (`config.cyr` already calls the memory
feature a prompt-injection surface in its own comment.)

Indirect injection via fetched or read content is the highest-volume attack path against coding agents in
2026. agnosai's `src/server/prompt_guard.cyr` supplies an ordered pattern table plus a system-prompt
wrapper. Two caveats worth stating: pattern matching is a **mitigation, not a boundary** (thoth should
frame it the way it frames the shell filter), and the strongest available control is structural —
Claude Code runs web-fetch results through a **separate context window** so retrieved text cannot issue
instructions into the main thread.

### T2-4 · Lifecycle hooks — **confirmed-missing**, the most-copied extensibility primitive
Claude Code has ~30 events with five handler types and a `permissionDecision: allow|deny` contract; Codex
has shipped a near-identical set. A `PreToolUse` hook that can **block** is a deterministic, code-enforced
deny that a prompt cannot argue with — which is exactly thoth's posture, expressed as a user extension
point. It is also the natural home for "run the linter after every edit" (T2-5) without thoth hardcoding it.

### T2-5 · A verification loop — **confirmed-missing**
thoth has every ingredient — `shell` can run `cyrius test`, `exec.cyr` does timed capture, roundlog records
outcomes — and nothing closes the loop. Peers run tests/linters and iterate on the failures before
declaring done. Cheapest form: a `[verify].command` run after an edit round, with the output fed back as a
tool result. Depends on T1-2 (an 8-round cap cannot absorb a test cycle).

### T2-6 · Conversation forking — **confirmed-missing**, and thoth is one step away
thoth's conversation store already does the hard part: keyed, named, persisted, switchable conversations.
Forking is one more operation on that structure — copy the message vector and title, push, switch. Claude
Code (`/branch`), Codex (`codex fork`) and Goose all ship it.

### T2-7 · Consume MCP **resources** and **prompts** — **partial**, best effort-to-value ratio
The protocol work is already vendored and paid for: `bote-core.cyr` carries full resources and prompts
registries. thoth uses only `tools/`. Server-published resources are context thoth could offer the model;
server-published prompts are naturally surfaced as slash commands. Low risk, no new dependency.

---

## Tier 3 — Worth knowing, lower priority or explicitly declined.

- **Export the audit trail (OTLP)** — *partial*. thoth is ahead on the hard half (a real hash chain) and
  behind on the easy half: the record never leaves the process. The OpenTelemetry **GenAI semantic
  conventions** are the standard worth adopting if this is ever wanted. Low priority for a TUI.
- **MCP tool-description pinning (rug-pull defense)** — *confirmed-missing*. CVE-2025-54136 established
  that approving a tool definition does not survive later server-side changes. thoth re-fetches
  descriptions from daimon every probe and hands them to the model as trusted metadata. Trust-on-first-use
  hashing is the only control that actually works here. **Arguably belongs in daimon**, which owns the
  registry — worth raising there rather than building thoth-side.
- **Network egress control** — *confirmed-missing*. Exfiltration is the payoff step of most injection
  chains. `shell` can curl anywhere and `web_fetch` reaches any URL. Again largely daimon's and kavach's
  seam, not thoth's.
- **MCP 2026-07-28 conformance** — vendored bote 3.3.7 negotiates 2025-11-25, one revision behind across a
  structural break. **bote's problem, not thoth's**; flagged so it is tracked somewhere.
- **Image / multimodal input** — *confirmed-missing*. thoth has an unusual reason to care: it ships its own
  Wayland GUI, so it is one of the few terminal agents that could *produce* a screenshot as well as consume
  one.
- **Agent Client Protocol (ACP) server mode** — *partial*. ACP is doing for agents what LSP did for
  language servers (Zed, JetBrains, Neovim). A server mode would let thoth be driven from other editors
  without giving up its own TUI. Distribution value; no architectural conflict.
- **Streaming JSON event output** — *partial*. `thoth -p --json` emits one object at the end; there is no
  event stream for another program to watch a long agentic turn.
- **Git write operations / worktrees** — *confirmed-missing*. The git producer is deliberately read-only,
  which is right for the status bar, but the agent can inspect a diff and never land it.
- **A2A (Agent2Agent)** — **decline.** No terminal coding harness implements it; its center of gravity is
  enterprise multi-agent orchestration. Listed only so the decision is recorded as deliberate.
- **Prometheus metrics** — **not applicable** to an interactive TUI.

---

## Taking from agnosai: what, and what not

agnosai 2.0.6 is a full orchestration **engine** — 111 modules, and a `dist/agnosai.cyr` of 37,595 lines
(1.6 MB, 2,043 fns). Namespace hygiene is excellent and CI-enforced (`agnosai_*`/`AGN*` on every symbol,
verified — zero unprefixed).

### ⚠ The consumption question, answered with evidence

**Neither published seam is clean for thoth as it stands.**

1. **The vendored bundle's dependency contract is incomplete.** `dist/agnosai.deps` names only 45 stdlib
   leaves and **omits the six `[deps.X]` git bundles the fold actually calls into** — `kavach_init` (62
   refs), `ratelimit_*` (11), `rng_uniform`, `sha256`, `dispatcher_*`, `accel_*` are all used in the dist
   and defined nowhere in it. The README's advertised three-line `[deps.agnosai]` block **will not link on
   its own**, and nothing proves the bundle compiles standalone — CI never builds it. Vendoring it whole is
   not currently possible, and at 1.6 MB it would dwarf every other bundle thoth carries.
2. **The HTTP service overlaps daimon.** thoth could talk to a running agnosai the way it talks to daimon —
   but agnosai's tool registry competes with daimon's host registry, and its `builtin/mneme.cyr`
   re-implements as direct HTTP the exact mneme tools thoth already reaches through
   `daimon /v1/mcp/call`. Adopting it gives thoth **two paths to mneme with different auth and different
   failure modes**.

### Take: four small, pure, non-overlapping leaves

These are genuine gap-fillers that do not collide with any seam thoth already consumes. All are
self-contained over str/bayan/sakshi.

| Leaf | Fills | Tier |
|---|---|---|
| `src/server/output_filter.cyr` | secret/PII redaction before output is displayed, saved or persisted | **T1-3** |
| `src/server/prompt_guard.cyr` | injection heuristics over untrusted prose + a system-prompt wrapper | **T2-3** |
| `src/orchestrator/output_validation.cyr` | validate a model response against an output schema; build a retry prompt | new — see below |
| `src/server/ssrf.cyr` (+ `guarded_fetch.cyr`) | URL safety, incl. octal/hex IP literals and per-redirect re-validation | **defer** |

`output_validation` has an immediate use thoth has already been burned by: validating tool-call `arguments`
before they reach daimon. 0.38.5 fixed one shape bug there (`bayan_json_v_str` dropping Ollama's
object-shaped arguments) and 0.39.0's A-10 fixed a JSON-injection seam at the same splice. A real validator
belongs there.

`ssrf`/`guarded_fetch` are **low value today and would actively misfire**: thoth has no model-controlled
outbound URL (web_fetch/web_search are bote tools hosted by daimon, where the guard belongs — daimon
already logs SSRF-guard rejections), and thoth's only outbound URLs are operator-set, with the default
being `http://127.0.0.1:8088` — which a private-IP guard would reject. Defer unless thoth gains a direct
fetch; if it does, read `agnosai/docs/adr/007` first, because the per-redirect re-validation is the
non-obvious half.

**Open question for the maintainer**: even for the four leaves, the mechanism matters. A `[lib.guard]`-style
profile published by agnosai — the way sit publishes `[lib.read]` and sankoch publishes `[lib.zlib]` — would
be far better than thoth hand-extracting four files, which is a fork by another name. **That is a request
to make of agnosai, not a change to make in thoth.**

### Borrow the idea, not the code

- **`RiskLevel` (low/medium/high)** on an action. thoth's gate is binary allow/deny/flag; a risk tier is the
  prerequisite for both a graduated permission posture and an approval queue.
- **Budget *enforcement*** (`orchestrator/budget.cyr`): check-before-call, `>=` semantics, a typed
  exceeded-reason. thoth has token/cost **accounting** and no enforcement — nothing stops a runaway loop
  from spending. The logic is trivial against thoth's existing counters; the *shape* is what is worth
  copying.
- **Asynchronous approvals** (`orchestrator/approval.cyr`): a pending-decision queue that outlives the
  prompt, so an unattended run can *park* a risky edit instead of denying it. thoth's `confirm()` is
  otherwise strictly better (fail-closed, explicit y/yes only).
- **The 18 agent presets** as a ready-made answer to "what specialists would a thoth crew contain" — though
  note agnosai's `AgentDefinition` has **no personality field**, because that axis belongs to avatara.

### Refuse, with reasons

- **`src/llm/*` — the hoosh client.** Its own header names `thoth/src/hoosh.cyr` as its reference
  implementation, so thoth would be importing a weaker copy of itself: no SSE streaming, **no tool-calling
  at all** (zero `tool_calls` refs across `llm/` and `crew_runner`), no reasoning effort, no mid-session
  switching.
- **`src/llm/router.cyr`** — model routing is hoosh's declared domain. Adopting it puts routing policy in
  two places.
- **`src/tools/registry.cyr`** — a second tool registry competing with daimon's.
- **`src/server/routes/mcp.cyr`** — thoth is an MCP *client*; if it ever wants to be a server, bote's
  dispatcher is already vendored.
- **`src/orchestrator/audit.cyr`** — thoth already vendors libro. Two chains in one process is worse than
  one. (Its header's reasoning about why hoosh's GET-only `/v1/audit` cannot be an append target is worth
  reading; thoth should not try either.)
- **`src/sandbox/`** — right gap, wrong seam. See T2-2: kavach owns this.

---

## Suggested sequencing

Nothing here is scheduled; this is the order that maximises value per unit of risk.

1. **T1-1 (search tool) + T1-2 (iteration cap)** — together, because each is throttled by the other. The
   single biggest improvement to what thoth can actually finish in one turn.
2. **T1-6 (session-scoped approvals) + T1-5 (`/compact`, `/context`)** — small, on existing mechanisms,
   felt every session.
3. **T1-3 (redaction)** — pending the agnosai profile question above.
4. **T1-4 (checkpoints)** — needs a scoping decision on sit's write surface.
5. **T2-1 (subagents)** — needs an ADR first; it is the one item that touches the spine rule.

## Open questions for the maintainer

1. **Subagents vs the spine rule** — is a scoped child of one conversation thoth-side context management,
   or is it orchestration that belongs to daimon/agnosai? Everything in T2-1 waits on this.
2. **Should agnosai publish a `[lib.guard]` profile?** That is the difference between consuming the four
   leaves and forking them.
3. **Checkpointing via sit's write surface** — in scope, or is a simpler snapshot directory the right first
   cut?
4. **Where does rug-pull defense live** — thoth pins tool-description hashes, or daimon does it for every
   consumer? (T3.)
