# thoth — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.
>
> **Forward-facing only — what's left to v1.0.** Shipped history lives in
> [`../../CHANGELOG.md`](../../CHANGELOG.md) and the version log in
> [`state.md`](state.md); this file is just the road ahead.
>
> **Where we are:** **M0–M5 are done** — driver core, the hoosh seam (inference
> + mid-session model switch), the M4 tool spine (daimon remote; bote + t-ron
> native; one fail-closed authorization choke point), and the M5 avatara overlay
> are all live, so **all five spine seams are wired**, with the model-driven
> agentic tool-calling loop (0.6.0) running on top. **M6 is in progress** —
> multi-target builds began with the Linux target shipping (0.6.3). What remains
> below is **provisional**: ordering, version labels, and dep gates may still
> move. Treat the unshipped milestones as direction, not commitment.

## Framing (read first)

thoth is **OS-agnostic at the substrate layer and AGNOS-sovereign at the
capability layer**. The two never collide because they govern different
layers:

- **The floor — portable.** Syscalls, allocation, argv, process spawn,
  terminal I/O. The vendored Cyrius stdlib already fans this out across
  one shared codebase to multiple targets behind one stable interface
  (`syscalls_x86_64_agnos` / `syscalls_x86_64_linux` /
  `syscalls_aarch64_linux` / `syscalls_macos` / `syscalls_windows`, plus
  matching `alloc_` / `args_` / `process_` variants). thoth writes
  against the portable interface and picks the target at build time —
  never against a per-OS file.
- **The spine — sovereign.** Model routing and mid-session switching
  (hoosh), agent orchestration + MCP tool execution + the host registry
  (daimon), the MCP protocol (bote), per-tool authorization (t-ron), and
  the Thoth/Librarian archetype overlay (avatara). thoth owns **no**
  domain logic of its own; it consumes this spine and never reimplements
  any part of it.

The bright line: **port the floor; never fork the spine.** thoth may
abstract the OS beneath it, but it must never re-create above it anything
AGNOS already owns. AGNOS is the primary, fully-realized home (native,
co-resident, sandboxed end to end); other operating systems run the
**same** spine reached as a client over a portable transport,
capability-gated. The posture: **everywhere capable, AGNOS canonical** —
portability owns the floor (it always runs), AGNOS owns the ceiling (it
runs best), and the gap between them is an explicit, documented contract.

See [ADR-0001](../adr/0001-os-agnostic-agnos-primary.md) for the full reasoning, [ADR-0002](../adr/0002-consume-the-agnos-stack.md) for the consume-the-stack mandate, and [architecture note 001](../architecture/001-consumer-only-no-domain-logic.md) for the invariant.

## v1.0 criteria

_Provisional — to be ratified as the design settles. v1.0 is an **AGNOS
gate**: the downstream-green criterion is satisfied on AGNOS, where the
whole spine is native._

- [ ] Core driver loop (read → plan → edit → run → iterate) usable on
      AGNOS and at least one off-AGNOS target
- [x] Mid-session model switch routes turns through hoosh — M3 (0.2.0)
- [ ] MCP tool execution via daimon + bote, gated by t-ron on AGNOS
- [x] Off-AGNOS security **fails closed** — absent t-ron degrades to a
      conservative built-in deny/prompt, never silent allow; absence is
      announced, never faked — M2 posture, made fully real by M4 (0.3.0):
      wired t-ron denies by default; absent t-ron prompts deny-by-default
- [x] avatara Thoth/Librarian archetype overlay applied — M5 (0.4.0)
- [ ] Capability ladder documented and honest (per dependency:
      native vs. remote-client vs. absent; full / degraded / absent
      semantics)
- [ ] At least one downstream consumer green **on AGNOS**
- [ ] CHANGELOG complete from the first real release onward
- [ ] Security review pass
- [ ] 1.0 versioning scheme decided (SemVer vs CalVer) — see Versioning below
      and [ADR-0004](../adr/0004-semver-pre-release.md)

## Versioning

thoth uses **SemVer `0.x`** through its pre-1.0 phase — see
[ADR-0004](../adr/0004-semver-pre-release.md). This supersedes the earlier
"CalVer at first release" plan: a `0.x` number honestly signals that the
surface is still moving (commands and the seam interface still change release to
release). Whether thoth adopts CalVer (the binary standard) or stays SemVer at
1.0 is deferred to a later ADR.

## Milestones

> **Shipped (M0–M5, 0.1.0 → 0.4.0, plus the 0.5.x–0.6.x polish line):** the
> scaffold and identity ADRs, the driver core, the hoosh seam, the M4 tool spine,
> and the M5 avatara overlay — then streaming, multi-turn context, structured
> logging, the `/audit` / `/models` views, the model-driven agentic tool-calling
> loop, and per-tool input schemas. Per-release detail is in
> [`../../CHANGELOG.md`](../../CHANGELOG.md) and the version log in
> [`state.md`](state.md). The road ahead:

### M6 — OS-agnostic build targets + capability ladder (in progress)

Ratify the reach posture and make degradation explicit. The build driver
(`scripts/build.sh`) and [ADR-0008](../adr/0008-multi-target-builds.md) landed
with **0.6.3**; the rest is open.

- ✅ **x86_64 Linux** ships as a named target (0.6.3).
- ☐ **AGNOS, macOS, Windows, aarch64** — staged in the driver, each blocked on a
  named upstream gap: AGNOS needs `SYS_LSEEK` in its syscall floor; macOS/aarch64
  need the cycc `#pure`/aarch64 pass-1 scanner fix (filed
  `cyrius/.../2026-06-12-main-aarch64-pass1-missing-annotation-tokens-unexpected-enum`);
  Windows needs an epoll equivalent (or the sandhi server pruned per target).
  Each lights up with zero thoth source change once its gap closes.
- ☐ **Capability-ladder / feature-gate matrix**: per dependency, native vs.
  remote-client vs. absent, with **full / degraded / absent** semantics defined
  and kept honest so it can't drift and mislead. (The target matrix in `state.md`
  is the start; the per-capability ladder is still owed.)
- ☐ Confirm: identical agent UX everywhere; AGNOS is the only parity promise.

### M7 — Release readiness (provisional)

- Satisfy the v1.0 criteria above (AGNOS downstream-green gate)
- Security review pass
- CalVer cutover at the first real tag

## Out of scope (for v1.0)

The deliberate non-goals — these keep future contributors from forking
the spine or diluting the identity by accident.

- **Any OS-specific reimplementation, bundling, or substitute** for a
  domain AGNOS already owns — inference (hoosh), MCP protocol (bote), MCP
  security (t-ron), orchestration / tool host (daimon), or archetype
  (avatara). No "offline" / "embedded" forks that dodge the spine.
- **A bundled local inference path** to escape hoosh, a **hand-rolled MCP
  client** to escape bote, or an **ad-hoc auth shim** to escape t-ron.
  These are the precise failure modes the identity ADR exists to prevent.
- **A swappable-backend abstraction** that lets the spine be replaced with
  arbitrary alternative implementations — the capability seam binds to the
  **same contract** (native vs. reached-as-client), not to competing
  backends. thoth drives the AGNOS spine; it does not abstract it away.
- **Off-AGNOS feature parity.** Parity is an AGNOS-only promise;
  elsewhere thoth runs a faithful, capability-gated baseline.
- **Silent degradation** of any capability, especially security. Missing
  capabilities fail closed and are announced — never faked.
- **A separate per-OS agent UX or "AGNOS edition" fork.** One driver, one
  UX, many substrates.
- **Declaring a spine crate as a dep before its seam milestone wires it.**
  Each seam binds in its own milestone, not speculatively ahead of design:
  daimon / bote / t-ron land in M4, avatara in M5. (hoosh, wired in M3, is the
  exception that proves the rule — it is consumed as a *running HTTP gateway*,
  not a linked crate, so it never becomes a `cyrius.cyml` git-dep; the stdlib
  `sandhi` transport is what M3 declared.) The **off-AGNOS reach transport** —
  the native-vs-remote binding distinction — is deferred to a later ADR once
  that work is real.
