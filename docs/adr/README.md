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
- [0006 — The M4 tool spine: daimon remote-client, bote and t-ron native via vendored dist bundles](0006-m4-tool-spine-daimon-bote-tron.md) — *Accepted.* M4 binds daimon remote (HTTP via sandhi) and bote + t-ron native (vendored bundles); every gated action flows through one fail-closed t-ron authorization choke point.
- [0007 — The M5 avatara seam: native via a vendored dist bundle, persona threaded into the hoosh system prompt](0007-m5-avatara-seam-native-persona-system-prompt.md) — *Accepted.* M5 binds avatara native (vendored 2.8.0 bundle); the Thoth/Librarian persona is sourced from the archetype and threaded into the hoosh `{role:system}` message so it steers the turn (runtime-switchable since 0.22.x via `/persona`/`/role`).
- [0008 — Multi-target builds: one source tree, target picked at build time (Linux first)](0008-multi-target-builds.md) — *Accepted.* M6 wires `scripts/build.sh` to fan one source tree to targets; x86_64 Linux ships, AGNOS is staged and announced as blocked upstream (the `SYS_LSEEK` floor gap), never faked.
- [0009 — Presentation capability ladder + tier-agnostic render surface](0009-presentation-capability-ladder.md) — *Accepted (T3 revised by the 0.30.0 addendum).* Presentation is a tier ladder (T0 plain … T2 rich alt-screen … **T3 a sovereign Wayland desktop GUI**, `thoth gui`, shipped 0.29–0.30.x) picked once at startup; feature code emits through a semantic color-role API + facts-not-bytes view-models (0.28.0) so features render at every tier and degrade closed when piped/CI. T3 = thoth's OWN Wayland app, not thoth-in-puka.
- [0010 — Data-producer honest-omit: surface a field only when present, never fake](0010-data-producer-honest-omit.md) — *Accepted.* Token counts, cost, git, etc. appear only once the producer actually reports them; an absent producer is omitted (or announced), never shown as a fabricated zero.
- [0011 — One-shot / argv front-door: thoth as a non-interactive shell citizen](0011-one-shot-argv-front-door.md) — *Accepted.* An explicit argv task (`thoth 'task'`, piped stdin, `--json`, `-o`, `--completion`, `--tier`) runs one turn to clean stdout and exits, so thoth composes in pipes and scripts without disturbing the interactive floor.
- [0012 — Memory seam: omit-until-mneme (thoth reads + injects; mneme owns the engine)](0012-memory-seam-omit-until-mneme.md) — *Accepted.* thoth reads a project-local `.thoth/memory/` flat-file store and injects it into the turn (opt-in); the semantic-recall engine is mneme's domain, consumed when it binds — not reimplemented here.
- [0013 — Highlight fenced code in the reply feed by buffering each block until its close](0013-reply-code-highlighting-block-buffered.md) — *Accepted.* Streamed reply code fences are syntax-highlighted by buffering a block until its closing fence, so highlighting is correct without a full markdown parse of partial output.
- [0014 — The model's `shell` tool: a local, POSIX-only, defense-in-depth agentic capability](0014-model-shell-tool-local-posix-gated.md) — *Accepted.* An opt-in, t-ron-gated `shell` tool lets the backing model propose local commands; off by default, POSIX-only, with allow/deny globs — a thoth-local capability, not a spine domain.
- [0015 — Project read/explore tools: default-on, jailed to the launch directory](0015-project-read-tools-jailed-default-on.md) — *Accepted.* Default-on `read_file`/`list_dir` tools + `@file` mentions let the agent see the project it was launched in, jailed to the launch dir (plus user-granted `/allow` roots) — reading the working directory is thoth's own local hands, not a spine domain.
- [0016 — `.thoth/` home directory: config + memory discovery, honest readiness](0016-thoth-home-dir-config-memory-discovery.md) — *Accepted.* Config + project memory live under a discoverable `.thoth/` home (`.thoth/config.cyml` + `.thoth/memory/`), found by walking up from the CWD then `~/.thoth/` (legacy `./thoth.cyml` still read); READY is stated only when a configured gateway actually answers.
