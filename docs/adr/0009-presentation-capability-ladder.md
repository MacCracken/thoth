# 0009 — Presentation capability ladder + tier-agnostic render surface

**Status**: Accepted
**Date**: 2026-06-24

## Context

thoth renders through one choke point — `emit`/`emit_n`/`println` (src/util.cyr),
raw `syscall(SYS_WRITE,1,…)` UTF-8, no ANSI/color/cursor/raw-mode; input is
canonical line-mode `read_line` dispatched in src/repl.cyr behind the `{(o> `
prompt. A design mockup (`Thoth.dc.html`) shows a warm-amber agentic-IDE: status
bar, file tree, tool-call cards with syntax-colored diffs, a slash-palette
composer, truecolor theming, a streaming feed. The mockup is interactive HTML, so
its *literal* richest render is a desktop/webview app.

The pull is to chase that GUI. That would fork the front-end, pull in a non-AGNOS
webview dependency, and invert the value/effort curve. thoth's doctrine is the
opposite: consume the spine, **port the floor, never fork the spine**, degrade
**closed** and **announce, never fake**. thoth already runs a capability ladder
for the spine seams ([architecture/002](../architecture/002-capability-ladder.md));
the same shape applies to the front-end. And the AGNOS ecosystem already *has* the
substrate — hand-rolling termios/ANSI/raw-mode/syntax-highlighting/a terminal host
would reinvent shipped, tested first-party libs.

## Decision

Treat **presentation as a third capability axis**, orthogonal to the spine ladder:
**T0 plain → T1 ANSI → T2 rich-TUI → T3 graphics/desktop**. Feature code emits
**semantic intents** through a tier-agnostic render *surface* (e.g. `sf_tool_card`,
`sf_diff_line`, `sf_status_bar`, `sf_agent_delta`) — never raw escapes; the
active renderer, chosen once at startup, decides the bytes. Tier is detected
(isatty + `TERM`/`COLORTERM`, GPU via mihi), surfaced in `/seams`, and degrades
closed with announcement. `{(o> ` is the literal **T0 floor** and stays
byte-identical when piped/CI.

**Terminal-first.** T1 (ANSI color, the amber palette, syntax-colored diffs) is
the pragmatic primary and the cheap, high-leverage win — pure bytes through the
existing choke point, **no new substrate**. T2 (raw-mode composer, slash palette,
alt-screen panes, status bar) is a deliberate, separable, **gated** milestone.

**Consume, don't hand-roll** (the load-bearing scope decision):

| Need | Lib |
|---|---|
| raw-mode / isatty / winsize / alt-screen / cursor / truecolor SGR | **darshana** (vendor; `chakshu/src/tui.cyr` is the reference loop) |
| syntax-colored diffs | **vyakarana** (vendor) |
| GPU-tier gate + status-bar sysinfo | **mihi** |
| fancy banner / rainbow | **bnrmr** + **anuenue** (pipe) |
| desktop/GPU host (T3) | thoth's OWN sovereign Wayland client — draw-IR + **kashi** raster + a **puka**-forked present shell (**revised** from "thoth-in-puka"; see the 0.30.0 addendum below) |
| git branch / diff | **sit** when `.sit/`; existing `.git/` repos **gated on sit's `.git/` read-mode** roadmap item |

**Out of scope:** a webview/GUI inside the sovereign core (the `Thoth.dc.html` mockup
is a *reference/spec*, never a bundled dep; T3 is thoth's OWN sovereign Wayland client —
no webview — **revised** from "thoth-in-puka", see the 0.30.0 addendum below); a cost/pricing table (hoosh's domain —
cost shows only from an opt-in `thoth.cyml [pricing]` block, else omitted); faking
any datum the mockup shows that thoth lacks (token/ctx%, cost, branch, real diff)
— those fields **omit** until a producer lands.

## Consequences

- **Positive** — the mockup's *look* (amber palette, colored diffs, status line)
  lands at T1 with no substrate risk and `{(o> `/piped output unchanged. T2 reuses
  darshana instead of a from-scratch raw-mode editor (weeks, not months). T3 is thoth's
  OWN sovereign Wayland app (**revised — see the 0.30.0 addendum; it was originally scoped
  as puka-hosted**), shipped 0.29–0.30.x. Sovereignty and degrade-closed hold at every tier.
- **Negative** — every existing `emit`/`println` call site is rerouted through the
  surface (a mechanical but broad refactor). thoth takes on a render-tier model and
  its detection. New vendored deps (darshana, vyakarana, mihi) to track.
- **Neutral** — surfaces honest data gaps as their own small producer tasks:
  getcwd, hoosh `usage` extraction (tokens), a `[pricing]` block (cost), and git
  branch/diff. The git-on-`.git/`-repos slice is **gated on sit gaining a `.git/`
  read-mode** (filed on sit's roadmap); until it lands, the branch field and
  real-git diffs omit (on `.sit/` repos sit serves them today).

## Alternatives considered

- **Webview/desktop GUI first (most faithful to the HTML).** Rejected: pulls a
  heavy non-AGNOS dependency into a sovereign binary, forks the front-end, and
  inverts effort-for-value. (**Revised — see the 0.30.0 addendum:** T3 was originally scoped as puka's optional ceiling; it shipped instead as thoth's OWN sovereign Wayland app, `thoth gui`, with no webview.)
- **Jump straight to T2 so it "looks like the mockup" in one step.** Rejected: the
  raw-mode composer is the single largest substrate change (XL); T1 delivers most
  of the visible polish at a fraction of the risk.
- **Hand-roll the terminal substrate (termios, ANSI, syntax highlight).** Rejected:
  darshana/vyakarana/mihi are shipped, tested first-party libs; reinventing them
  forks the floor — the exact thing the doctrine forbids.

## Addendum (0.30.0) — T3 revised: thoth as its own sovereign Wayland app

The original decision framed **T3 as thoth-in-puka** (puka hosts thoth as a terminal
in its window). Revised: **T3 is thoth as its own sovereign Cyrius Wayland app**,
following jalwa (which forked puka's Wayland client to become a native GUI, not a
terminal-in-puka). This is NOT a webview and NOT a non-AGNOS dependency — it stays
fully sovereign (zero external code): a **draw-command IR** (`src/gui/gdraw.cyr`) →
**CPU rasterizer** (`src/gui/graster.cyr`, kashi VGA font → XRGB8888) →
**view-builders** (`src/gui/gstatus.cyr`, lowering the Stage-B facts-not-bytes
view-models) → a **puka-forked Wayland present shell** (`src/gui/gwindow.cyr`,
vendored+renamed from jalwa's client; the window substrate is FLOOR, destined to
extract to **aethersafha**). The T0–T2 tiers, the semantic-role color layer, and the
degrade-closed / port-the-floor doctrine are unchanged; T3 simply gains a *fourth
renderer* over the same view-models rather than delegating the whole front-end to
puka. The design mockup `Thoth.dc.html` is the T3 pixel spec (its palette == ui.cyr's
roles). Landed 0.29.0 (headless pipeline) → 0.30.0 (runnable `thoth gui`).
