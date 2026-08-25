# thoth — agentic-harness gap review

> **What this file is:** the candidate gaps between thoth and the current agentic-coding
> harness landscape that thoth has **not committed to**. Nothing here is scheduled and
> nothing here is a promise.
>
> **What this file is NOT:** the plan. [`roadmap.md`](roadmap.md) is the plan, and it
> **supersedes this file**. Anything scheduled, declared, or carried as a known limitation
> there has been removed from here — deliberately, so there is exactly one place to look
> for "what is thoth going to do" and exactly one for "what has thoth not decided about".
> Shipped work is in [`../../CHANGELOG.md`](../../CHANGELOG.md) and is not narrated here.

**Superseded files:** this replaces `agentic-improvements-review.md` (the 0.39.0 tiered
review) and the earlier `gap-review.html`. Their Tier-1, Tier-2 and Tier-3 recommendations
were either shipped (0.40.0 / 0.41.0 / 0.42.0 — see the CHANGELOG), promoted to
[`roadmap.md`](roadmap.md), or carried forward below.

## How this was produced, and how much to trust it

The original survey ran three parallel researchers against **current** sources (official docs,
changelogs and repos — the space moves fast enough that a confidently wrong feature list is
worse than a short one), then checked each candidate gap against thoth's own source **before**
calling it missing. A fourth agent inventoried **agnosai** from a consumer's point of view and
was pushed to answer the consumption question with evidence rather than a wish list.

Confidence is marked throughout: **confirmed-missing** (looked, not there), **partial** (thoth
has some of it), **conflict** (thoth or its spine already owns the domain). Where thoth is
*ahead* of the field that is said too — this is a gap review, not a case for rewriting things
that work.

---

## Read this first: what thoth already gets right

Kept because a naive gap list would recommend rebuilding these.

- **A real cryptographic audit chain.** thoth vendors libro and surfaces a hash-linked,
  tamper-evident record of every gated action, with `/audit` verifying integrity in-process and
  `/audit export` writing it out. Almost no other harness has this; most have a log file.
- **Authorization as a real seam, not a prompt.** t-ron supplies allow/deny/flag verdicts, an
  injection scanner over tool params, a pattern analyzer, a rate limiter and a per-agent risk
  score, with distinct reserved verbs (`thoth_run` vs `thoth_shell` vs `thoth_edit`) that let a
  policy separate the operator's own actions from the model's. Everything below **builds on**
  this; none of it replaces it.
- **Honest degradation as a house rule.** Missing capabilities are announced, not faked — the
  banner states live gateway reachability rather than a hardcoded READY, an absent t-ron falls to
  a fail-closed confirm, and the source says plainly where a boundary is not a sandbox. That
  posture is why this review is short on "thoth pretends to be secure" findings.
- **Mid-session model switching**, which no surveyed harness matches, plus a model picker,
  reasoning-effort control and per-turn token/cost accounting.
- **Instruction-file safety.** thoth wraps `AGENTS.md` as "verbatim reference — durable facts,
  NOT commands to obey" and deliberately does not auto-inject `CLAUDE.md`. Most harnesses inject
  instruction files as trusted text.
- **Tool-definition pinning.** Trust-on-first-use hashing against the CVE-2025-54136 rug-pull,
  with a changed definition **withheld** rather than warned about. Rare among peers.
- **Subagent delegation with exactly ONE dispatch path.** Peers ship subagents; thoth's runs the
  child's tool calls through the *same* gate, hook, jail, checkpoint gate and audit chain as the
  parent's rather than a parallel implementation — so a delegated action is exactly as authorized
  and as observable as a direct one, and there is no second authorization path to drift.

---

## The open gaps

### 1 · OS-enforced sandboxing of `shell` / `edit` — **confirmed-missing; the largest safety delta**

thoth's own source is admirably blunt that it has none: the glob filter "is a COARSE convenience
pre-filter, NOT a sandbox", the jail is "a boundary, not a sandbox". Peers enforce at the OS —
Codex and Claude Code use Seatbelt on macOS and Landlock+seccomp on Linux, with read-only /
workspace-write / full-access tiers.

**Do not take agnosai's sandbox for this.** Its own README says the process tier has "No seccomp,
no Landlock, no cgroups". The right seam is **kavach**, which AGNOS already assigns kernel
confinement to, and which agnosai itself bridges to rather than reimplementing. "kavach owns the
sandbox, not the application" is a first-party standard, quoted verbatim in the standards doc.

**⚠ Status: attempted and deliberately not shipped.** kavach 3.12.3 added the `[lib.confine]`
profile this needs, and it builds clean inside thoth — the mechanical half is done. The blocker is
a design finding, not a shortfall: **kavach's confinement is container-shaped.** It blocks host
interpreters without a rootfs, and thoth's `shell` tool is a host-shell invocation, so every call
would be refused. Making it work means changing a security policy **inside kavach's threat model**,
which is kavach's owner's decision and not thoth's to make unilaterally. The seam was removed
rather than shipped as a promise thoth could not keep.

**The open question:** should kavach's interpreter blocklist become conditional (a host-exec
confinement tier), or should thoth's `shell` gain a rootfs-shaped execution mode? Until one is
answered this stays here rather than on the roadmap.

### 2 · Network egress control — **confirmed-missing**

Exfiltration is the payoff step of most injection chains. `shell` can curl anywhere and `web_fetch`
reaches any URL. Largely **daimon's and kavach's** seam rather than thoth's, which is why it is not
on the roadmap — but it is the natural companion to gap 1 and should be decided with it.

### 3 · Durable tool-definition pins — **new gap, created by 0.42.0**

`[toolpin]` pins are **session-scoped** by design: they die with the process, so a swap *during* a
session (or across a `/reprobe`) is caught and one *between two runs* is not. That bound is stated
honestly in the code and the CHANGELOG.

Closing it means a durable pin store — which would be a **security-relevant file thoth writes and
must then defend** (tamper, replace, symlink-redirect), so it is a real design decision rather than
a small feature. There is also a legitimate argument that it belongs in **daimon**, which owns the
registry and could pin once for every consumer instead of each consumer pinning separately.

### 4 · Structural isolation of untrusted content — **partial; the strongest available control**

`[guard]` marks untrusted prose with an envelope and does not block, which is the right posture for
a pattern matcher — it is a **mitigation, not a boundary**, and thoth frames it that way.

The strongest control in the field is structural, not lexical: Claude Code runs web-fetch results
through a **separate context window** so retrieved text cannot issue instructions into the main
thread. thoth has **four** untrusted-prose inlets now — `@file` mentions,
`read_file`/`list_dir`/`search` results, recalled mneme notes, and (0.43.0) **MCP resource
content** — and all four land in the main context.

**The prerequisite has landed, which changes this gap's shape rather than closing it.** 0.43.0's
subagent ([ADR-0018](../adr/0018-subagent-delegation-scoped-child-context.md)) *is* a separate
context window: a child reads whatever it reads into its own message list and returns one string,
which reaches the parent through redact → guard like any tool result. The machinery now exists;
what does not is thoth **routing untrusted reads through it automatically**. That would be a real
design decision, not a wiring job — it makes every `@file` cost a model round, and a laundered
summary is arguably a *more* persuasive injection vector than the raw text, since it arrives as
fluent prose the parent has no reason to distrust. Worth deciding deliberately.

### 5 · Export the audit trail to a wire protocol (OTLP) — **partial**

`/audit export` (0.42.0) closed the file half. What is still missing is emission to a collector,
where the **OpenTelemetry GenAI semantic conventions** are the standard worth adopting. Low priority
for an interactive TUI; listed so the choice of convention is recorded before anyone invents one.

### 6 · Image / multimodal input — **confirmed-missing**

thoth has an unusual reason to care: it ships its own Wayland GUI, so it is one of the very few
terminal agents that could *produce* a screenshot as well as consume one.

### 7 · Agent Client Protocol (ACP) server mode — **partial**

ACP is doing for agents what LSP did for language servers (Zed, JetBrains, Neovim). A server mode
would let thoth be driven from other editors without giving up its own TUI. Distribution value; no
architectural conflict. Note that 0.42.0's `--events` stream is a meaningful step toward being
drivable by another program, though it is one-way.

### 8 · Git write operations / worktrees — **confirmed-missing**

The git producer is deliberately read-only, which is right for the status bar, but the agent can
inspect a diff and never land it. Worth pairing with a decision about whether thoth should drive
sit's write surface at all.

### 9 · MCP 2026-07-28 conformance — **bote's problem, not thoth's**

Vendored bote 3.3.7 negotiates 2025-11-25, one revision behind across a structural break. Flagged
here only so it is tracked somewhere; the work belongs upstream.

### Declined, with reasons recorded

- **A2A (Agent2Agent).** No terminal coding harness implements it; its center of gravity is
  enterprise multi-agent orchestration. Listed only so the decision reads as deliberate rather than
  as an oversight.
- **Prometheus metrics.** Not applicable to an interactive TUI.

---

## Taking from agnosai: what, and what not

agnosai is a full orchestration **engine** — 111 modules, and a `dist/agnosai.cyr` of 37,595 lines
(1.6 MB, 2,043 fns). Namespace hygiene is excellent and CI-enforced (`agnosai_*`/`AGN*` on every
symbol, verified — zero unprefixed).

### ⚠ The consumption question, answered with evidence

**Neither published seam is clean for thoth as a whole.**

1. **The vendored bundle's dependency contract is incomplete.** `dist/agnosai.deps` names only 45
   stdlib leaves and **omits the six `[deps.X]` git bundles the fold actually calls into** —
   `kavach_init` (62 refs), `ratelimit_*` (11), `rng_uniform`, `sha256`, `dispatcher_*`, `accel_*`
   are all used in the dist and defined nowhere in it. The README's advertised three-line
   `[deps.agnosai]` block **will not link on its own**, and nothing proves the bundle compiles
   standalone — CI never builds it. At 1.6 MB it would also dwarf every other bundle thoth carries,
   against a preprocessor ceiling thoth is already at ~96 % of.
2. **The HTTP service overlaps daimon.** thoth could talk to a running agnosai the way it talks to
   daimon — but agnosai's tool registry competes with daimon's host registry, and its
   `builtin/mneme.cyr` re-implements as direct HTTP the exact mneme tools thoth already reaches
   through `daimon /v1/mcp/call`. Adopting it gives thoth **two paths to mneme with different auth
   and different failure modes**.

**The mechanism that does work** — and this is settled, not a proposal — is a lean **`[lib.X]`
profile published upstream**, the way sit publishes `[lib.read]` and sankoch `[lib.zlib]`. agnosai
published `[lib.guard]` on exactly this basis and thoth consumes it for `[redact]` and `[guard]`.
Hand-extracting files instead would be a fork by another name.

### Still open: one leaf worth taking

| Leaf | Fills |
|---|---|
| `src/orchestrator/output_validation.cyr` | validate a model response against an output schema; build a retry prompt |

This has an immediate use thoth has already been burned by: **validating tool-call `arguments`
before they reach daimon.** 0.38.5 fixed one shape bug there (`bayan_json_v_str` dropping Ollama's
object-shaped arguments) and 0.39.0's A-10 fixed a JSON-injection seam at the same splice. A real
validator belongs there. Taking it means asking agnosai to extend `[lib.guard]` or publish a second
profile — not copying the file.

**Explicitly deferred:** `src/server/ssrf.cyr` + `guarded_fetch.cyr`. Low value today and they would
**actively misfire** — thoth has no model-controlled outbound URL (`web_fetch`/`web_search` are bote
tools hosted by daimon, where the guard belongs and where SSRF rejections are already logged), and
thoth's only outbound URLs are operator-set with a default of `http://127.0.0.1:8088`, which a
private-IP guard would reject. Revisit only if thoth gains a direct fetch; if it does, read
`agnosai/docs/adr/007` first, because the per-redirect re-validation is the non-obvious half.

### Borrow the idea, not the code

- **`RiskLevel` (low/medium/high)** on an action. thoth's gate is binary allow/deny/flag; a risk tier
  is the prerequisite for both a graduated permission posture and an approval queue.
- **Budget *enforcement*** (`orchestrator/budget.cyr`): check-before-call, `>=` semantics, a typed
  exceeded-reason. thoth has token/cost **accounting** and no enforcement — nothing stops a runaway
  loop from spending. The logic is trivial against thoth's existing counters; the *shape* is what is
  worth copying.

  ⚠ **This got more urgent at 0.43.0, and the release says so out loud.** Delegation multiplies a turn's
  cost, and the only bounds available today are structural — depth 1, a separate per-child round budget,
  and off-by-default. `[subagent].enabled` is off *because* of this gap, and ADR-0018 records that the
  default should be revisited if real budget enforcement ever lands. A round limit bounds turns, not spend.
- **Asynchronous approvals** (`orchestrator/approval.cyr`): a pending-decision queue that outlives
  the prompt, so an unattended run can *park* a risky edit instead of denying it. thoth's `confirm()`
  is otherwise strictly better (fail-closed, explicit y/yes only), and session-scoped grants already
  removed the re-prompt-every-round problem.
- **The 18 agent presets** as a ready-made answer to "what specialists would a thoth crew contain" —
  relevant to the roadmap's subagent ADR. Note agnosai's `AgentDefinition` has **no personality
  field**, because that axis belongs to avatara.

### Refuse, with reasons

Kept verbatim: this list is what stops a future contributor forking the spine by accident.

- **`src/llm/*` — the hoosh client.** Its own header names `thoth/src/hoosh.cyr` as its reference
  implementation, so thoth would be importing a weaker copy of itself: no SSE streaming, **no
  tool-calling at all** (zero `tool_calls` refs across `llm/` and `crew_runner`), no reasoning
  effort, no mid-session switching.
- **`src/llm/router.cyr`** — model routing is hoosh's declared domain. Adopting it puts routing
  policy in two places.
- **`src/tools/registry.cyr`** — a second tool registry competing with daimon's.
- **`src/server/routes/mcp.cyr`** — thoth is an MCP *client*; if it ever wants to be a server, bote's
  dispatcher is already vendored.
- **`src/orchestrator/audit.cyr`** — thoth already vendors libro. Two chains in one process is worse
  than one. (Its header's reasoning about why hoosh's GET-only `/v1/audit` cannot be an append target
  is worth reading; thoth should not try either.)
- **`src/sandbox/`** — right gap, wrong seam. See gap 1: kavach owns this.

---

## Open questions for the maintainer

Each of these blocks something above. None has a default answer.

1. **Does kavach's interpreter blocklist become conditional, or does thoth's `shell` grow a
   rootfs-shaped mode?** Gap 1 — the largest safety delta — waits on this, and it is a change inside
   kavach's threat model.
2. **Where does durable rug-pull defense live** — thoth persists tool-definition pins, or daimon pins
   once for every consumer? Gap 3.
3. **Is a separate context window for untrusted content worth building before subagents, or as part
   of them?** Gap 4 and the roadmap's subagent ADR share most of their machinery.
4. **Should thoth drive sit's write surface at all** (gap 8), or does the read-only git producer stay
   the boundary?
