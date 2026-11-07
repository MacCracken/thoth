# 0023 — The network waits on a worker while a surface is up

**Status**: Accepted
**Date**: 2026-11-06

## Context

Every sandhi verb blocks its caller until the peer answers or a deadline passes: DNS, connect, the TLS handshake, the send, the wait for
headers, the read. thoth made those calls on the thread that owns the screen. A silent gateway therefore meant a dead surface for up to
`[hoosh].timeout_ms`, three minutes by default. In the window there were no frames, Esc was unread and the compositor's ping went
unanswered (audit G-6, 18 of 24 pings on the wire). A hung gateway also held the first frame for the whole probe (M-9, 6.3 s measured).

The transport has a partial answer. sandhi's idle turn (`sandhi_http_options_idle_ms` / `_idle_cb`, 1.10.5) hands control back between reads of
a stream's **body**. Against a real hoosh that covers the first-token wait, because hoosh sends its headers before it calls the provider.
It does not cover a stream's header wait, a gateway that accepts and says nothing, or any buffered verb, and the buffered verbs carry every
non-streaming round, every delegated child, every MCP call and every probe.

## Decision

**While a surface has bound its wait poll, a network call runs on a worker thread, and the main thread stays with the surface.** All of it
lives in `src/netwait.cyr`.

- **The worker only does the network.** A stream's events come back one at a time, with the worker parked, and the caller's callback runs on the
  main thread. Nothing a callback touches ever sees a second thread, so no callback changed.
- **A stop walks away.** A thread in `recv` cannot be cancelled, so the main thread gives the job to the worker and returns at once. A left
  stream ends at its next idle turn. A call stuck before its first byte ends at its own deadline, or with the process if
  `[hoosh].timeout_ms = 0`, which asks for exactly that.
- **A job owns what its worker reads.** The url and body are copied, because the next round rewrites the caller's buffers while a left worker may
  still be sending, and two requests must not mix on the wire. An arena goes with the job, and the worker hands it back when it ends.
- **A left call is reported as left.** It went out and its effect is unknown, so the model is told it may still complete: not "no result", which
  invites a repeat, and not "not run", which is false.
- **The startup probe does not wait on anyone's frame.** It waits 150 ms, which a local gateway or a refused connect needs, and the surface then paints with
  the answer outstanding.
- **No surface, no worker.** One-shot, the line REPL and a target with no poll make the plain call, byte for byte. The surfaces that bind are
  the TUI and the window, so the worker runs on Linux today.

## Consequences

- **Positive** — one mechanism covers every wait: DNS, connect, TLS, send, headers, body, and every verb. Esc reaches a hung gateway in under
  50 ms and the compositor's pings are answered in under 50 ms. It needs no dependency change.
- **Negative** — each streamed frame costs a handoff, about 19 µs. A 1 MB reply in 16-byte deltas takes 1.75 s against 0.56 s. At a model's real rate that is
  nothing, and keeping every callback on one thread is worth it.
- **Negative** — a process can now hold a thread nobody waits for, so `main` ends with `sys_exit_group`: a bare `SYS_EXIT` would end only the
  main thread and leave thoth running behind a stuck worker.
- **Negative** — a parallel batch's slot stays busy until its left worker ends, so the next round takes the serial executor.
- **Neutral** — type-ahead during a network wait is drained and dropped, as it always was during a stream.

## Alternatives considered

- **Extend sandhi's idle turn to the header wait and the buffered verbs.** The right layer for a stream, but it leaves connect, the handshake and the
  send on the main thread, and it means a sandhi release and a cyrius fold first. A cooperative wait would be simpler than a worker, so this
  stays worth doing if those three stop mattering.
- **Keep the call on the main thread and pump the window from a second thread.** The window's state has no lock, and the pump rebuilds frames.
- **The idle turn alone.** It proves the common case and leaves a hung gateway exactly as dead as before, which is what the audit filed.
- **A shorter `SO_RCVTIMEO` and a retry.** Native TLS fails a context for good on an expired read, and a record cut off mid-read cannot resume.
- **thoth's own HTTP client on sandhi's connection API.** A fork of the transport, by another name.

## Addendum (0.54.4): the stall clock

`[hoosh].timeout_ms` reached a stream as sandhi's read deadline, and any byte restarts that. hoosh sends a `: keep-alive` comment through a silent stream every 15 s, so a provider gone quiet behind it never tripped the deadline. Reproduced on real hoosh 2.10.0 with a provider that sends one token and stops: with an 18 s deadline, 0.54.3 was still hung when killed at 42 s, and the one-shot has no Esc.

sandhi never hands a comment to the stream callback, so a clock kept where events pass counts frames, and the idle turn this ADR already uses reads it. The job holds the clock on the worker path, and a small wrapper holds it on the plain path, which now takes idle turns as well. Past the deadline with no frame, the idle turn ends the stream and `net_stalled()` says why, so the turn can say the gateway answered and the provider did not, and the status bar stays up.

Two limits. A gateway sending frames keeps a turn alive however little they carry, so this catches a stalled provider and not a gateway set on holding thoth. And the idle turn needs `fd_wait_ready`, which AGNOS's floor answers with -38, so there a keep-alive still restarts the deadline.
