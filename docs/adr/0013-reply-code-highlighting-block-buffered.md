# 0013 — Highlight fenced code in the reply feed by buffering each block until its close

**Status**: Accepted
**Date**: 2026-07-03

## Context

thoth already syntax-colours source in two places — `/read` (0.8.4) and diff bodies
(0.8.5) — through one coverage-guarded highlighter, `_hl_span` (`src/diff.cyr`), over the
vendored **vyakarana** tokenizer. But the model's own reply is markdown, emitted to the
feed **verbatim**: a ` ```python ` block in an answer was never coloured, even though the
machinery to colour it was right there.

Closing that gap has one hard constraint — thoth streams by default (`[hoosh].stream=true`),
so the reply arrives as SSE deltas split at arbitrary byte boundaries — and one hard
invariant: the **byte-identical floor** (piped / one-shot / CI / `NO_COLOR` output must be
unchanged). Two facts shape the design:

1. A fence marker is a whole-line construct (CommonMark: ≤3 spaces, then ≥3 of `` ` ``/`~`),
   so a fence decision can only be made on a **complete line** — never on a partial delta.
2. vyakarana grammars are **stateful across lines** (multi-line strings, block comments).
   Highlighting a code block line-by-line would mis-colour those; the whole block must
   reach **one** `tokenize_stream`.

## Decision

Add `src/mdhl.cyr` — a line-assembling fence state machine that sits in front of the four
reply-emit paths (hoosh/agent × blocking/streaming). It buffers each fenced code block
until its **closing fence** (or turn end), then highlights the whole block in **one**
`_hl_span` pass (reused unchanged). Fence-delimiter lines and prose are emitted verbatim.
Fence info-strings map to grammar names via a small alias-first table (`bash`→`shell`,
`py`→`python`, …); every canonical name falls through and `_hl_span` self-heals an unknown
grammar to verbatim. Error bodies are **not** routed through it (only reply content is).

- **In scope**: fenced blocks (`` ``` `` and `~~~`), info-string language selection,
  unterminated / indented / longer-run / CRLF / tilde fences, streaming chunk-split
  robustness.
- **Out of scope**: inline `` `code` `` spans; nested fences (blockquote / deep list
  indent); re-highlighting already-painted feed rows (the live-upgrading "inner-window
  card" is a separate, larger cut against the feed ring — deferred).

## Consequences

- **Positive** — reply code is coloured with the same fidelity as `/read`, multi-line
  constructs included, reusing `_hl_span` with zero highlighter changes. Coverage is
  guaranteed (a property test asserts `strip_sgr(output) == input`): never a dropped or
  reordered byte. The floor is a strict pass-through at `PT_PLAIN`. Line assembly dissolves
  every streaming chunk boundary.
- **Negative** — a fenced code block is **withheld until its closing fence arrives**: while
  a block streams, the reader sees the ` ```lang ` opener, then the spinner, then the whole
  block appears highlighted at once (a visible latency only on large streamed blocks).
  Because detection is line-based, TUI text also renders **line-by-line** rather than
  character-by-character (a fence marker can't be recognised from a partial line) — which
  removes the per-character "typing" flicker (complementing the 0.15.0 paint throttle) but
  is a behaviour change for every reply. A newline-free reply is buffered until turn end
  (short ones appear whole; a pathological >2 KiB no-newline line force-flushes uncoloured).
- **Neutral** — a new module + a fence-tag→grammar table thoth now owns (presentation, not
  spine — vyakarana still owns tokenization). The withhold-latency is fully removed by the
  deferred live-upgrading card (stream verbatim, repaint highlighted at close), which earns
  its own ADR because it must re-render sealed feed-ring rows.

## Alternatives considered

- **Persistent tokenize_stream fed line-by-line** (stream code live, colour each line as it
  completes). Rejected: correctness rests on `tokenize_stream_drain` emitting completed
  tokens without `finish` (unverified), risks a one-line unstyled-tail flicker on multi-line
  constructs, and forks `_hl_span` into a new per-line highlighter.
- **Stream verbatim, then repaint the block highlighted in place** (the "inner-window card",
  option C). The best UX — no withholding — but it must rewrite already-sealed feed-ring
  slots, touching the soft-wrap / SGR-carry invariants. Deferred to its own reviewed cut.
- **Route the single shared `_hoosh_print_str` chokepoint** (minimal diff). Rejected: that
  helper also prints HTTP error bodies, so it would highlight error JSON — scope creep. A
  dedicated `_hoosh_print_reply` keeps highlighting to actual reply content.
- **Highlight only the blocking path.** Rejected: streaming is the default, so it would
  leave the common case uncoloured.
