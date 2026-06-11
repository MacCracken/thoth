# 0007 — The M5 avatara seam: native via a vendored dist bundle, persona threaded into the hoosh system prompt

**Status**: Accepted
**Date**: 2026-06-11

## Context

M5 is the last absent seam: avatara, the Thoth/Librarian archetype overlay.
Through M4, thoth's persona was a hardcoded stand-in — `persona_name`/`role`/
`tagline` returned string literals in `src/session.cyr`, a descriptor that
[ADR-0003](0003-wear-the-avatara-thoth-archetype.md) explicitly framed as a
placeholder for the real avatara binding, never a reimplementation.

avatara settles its own binding question by what it ships. It is **not** a
server (unlike hoosh/daimon) and not consumed as a git `[deps.X]` crate; it
ships `dist/avatara.cyr`, a self-contained `cyrius distlib` bundle — the same
shape as bote-core / t-ron / libro. The bundle exposes archetype constructors
(`egyptian_thoth()` returns a 320-byte `Profile`) and `prof_*` accessors over
the emitted profile: `prof_name`, `prof_soul`, `prof_spirit`, `prof_desc`, and
the trait/emphasis weights (`prof_precision` = 0.95, `prof_pedagogy` = 0.9, …).

Two realities shaped the binding. First, **avatara 2.7.0 was built against an
older language**: its manifest named `json` (carved into `bayan` at Cyrius
6.1.25) and `math`. Consuming it cleanly required avatara **2.7.1**, which
re-pins to 6.1.34 and drops the dead `json` entry; the dist itself references
no `json_*`/`bayan_*` at all, so no regeneration of the wire layer was needed.
Second, the persona had **no path to the model**: `hoosh_build_request`
hardcoded a single `{role:user}` message with no system slot. Flipping the seam
to "native" while leaving the archetype reachable only by the banner would have
been a value-thin half-measure that brushed the honest-ladder doctrine.

## Decision

- **avatara binds native**: `src/vendor/avatara.cyr` (committed dist bundle,
  avatara **2.7.1**, re-synced by `scripts/sync-avatara.sh`). The archetype is
  in-process — the off-AGNOS bundled descriptor over the same contract AGNOS
  serves co-resident. `seam_status(SEAM_AVATARA)` reports **native** by
  construction (like bote): the persona is always available from the bundle, so
  there is nothing to configure and nothing to fail.
- **The persona is sourced from avatara, not reimplemented**
  (`src/session.cyr`): a lazily-built, cached `egyptian_thoth()` profile backs
  `persona_name` (`prof_name`), `persona_soul` (`prof_soul`), `persona_spirit`
  (`prof_spirit`), and `persona_desc`. thoth authors only profile→string glue.
  The **"Librarian" role and the THOTH backronym tagline stay thoth's own**
  overlay framing over avatara's Egyptian wisdom-scribe archetype — they are
  thoth's identity labels, not avatara domain logic.
- **The archetype steers the turn** (M5 step 2): `persona_system_prompt()`
  composes avatara's soul + spirit prose with thoth's coding operating clause,
  built once and cached. `hoosh_build_request` gained a `system` parameter;
  `hoosh_send` passes the persona as a leading `{role:system}` message, gated on
  the seam being native. An empty/absent system preserves the prior bare
  single-user-message shape exactly — degraded honestly, never faked.

Stdlib consequence (recorded in `cyrius.cyml`): `[deps].stdlib` gains **`math`**
— the bundle's `f64_le`/`f64_ge` live in `lib/math.cyr`; the other f64 ops are
compiler builtins. Declared by hand rather than left to non-strict patching
(the documented placeholder-loop hazard). One benign duplicate: the bundle
carries `ERR_NONE = 0`, matching the vendored libro's identical constant (same
value; last definition wins). Its `xalloc` (an OOM guard over stdlib `alloc`)
is self-contained and collides with nothing.

## Consequences

- **Positive** — the capability ladder is now five-fifths wired: hoosh remote,
  daimon remote, bote native, t-ron native, **avatara native**. The persona is
  honest (read from the archetype, no stub) and behaviorally real (it reaches
  the model). Live-verified: the banner renders the avatara-sourced name and
  `/seams` shows `avatara [native]`; 105 unit assertions cover the persona
  sourcing, the built system prompt, and the request-shape cases.
- **Negative** — a fourth committed vendor bundle to track against its upstream
  tag (the largest yet, ~783 KB / 586 fns, mostly DCE-unreachable). thoth is
  now coupled to avatara's archetype API surface (`egyptian_thoth` + `prof_*`),
  and to `math` being present at the pin.
- **Neutral** — the `system` slot opened for the persona is the natural landing
  spot for the next deferred items (multi-turn conversation history, request
  tuning). The model-driven turn is still not a gated action — the persona
  shapes inference, which executes nothing locally (t-ron's surface is
  unchanged).

## Alternatives considered

- **Banner-only M5** (flip the seam, leave `hoosh_build_request` untouched):
  rejected — it reports "native" while the archetype is inert, exactly the
  honest-ladder violation the doctrine exists to prevent.
- **Hardcode a Thoth system prompt in thoth**: rejected — that re-fakes the
  persona thoth just stopped faking, and forks archetype content the spine owns
  (ADR-0002/0003). The soul/spirit prose is read from avatara's emitted profile.
- **Vendor avatara 2.7.0 as-is**: rejected — its `json` dep is dead at 6.1.34;
  2.7.1 is the language-aligned tag. (`math` is *not* stale — it is the current
  module name.)
- **Reach avatara remote/co-resident now**: deferred — avatara ships a distlib,
  not a server; the native-vs-remote reach-transport distinction is the M6
  question (a later ADR), not M5's.
