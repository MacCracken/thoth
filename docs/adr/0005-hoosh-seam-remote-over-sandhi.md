# 0005 — The hoosh seam binds remote-client over HTTP via sandhi

**Status**: Accepted
**Date**: 2026-06-10

## Context

M3 wires the first capability seam: hoosh, the signature feature (LLM inference,
multi-provider routing, the mid-session model switch). The seam registry already
anticipated three binding modes — absent, remote-client, native — but 0.1.0 left
every seam absent. M3 had to choose, concretely, *how* thoth reaches hoosh.

hoosh (2.2.2) settles part of the question on its own: it is a standalone
HTTP gateway, not an embeddable library. It exposes no Cyrius distlib; its
[ADR 0001](https://github.com/MacCracken/hoosh) commits to "hoosh is an HTTP
gateway server." So thoth cannot link hoosh in-process — it must speak to it
over a transport. The gateway is OpenAI-compatible: `POST /v1/chat/completions`,
stateless, the provider/model chosen per request by the `model` field.

That leaves two real decisions: (1) what transport, and (2) how thoth is
configured to find the gateway. For the transport, the own-the-stack mandate
([ADR-0002](0002-consume-the-agnos-stack.md)) forbids hand-rolling an HTTP/TLS
client when AGNOS already owns one — **sandhi**, the service-boundary layer
(folded into the Cyrius stdlib as `lib/sandhi.cyr`). For configuration, thoth
needs to know the gateway's address (and, optionally, a bearer token) without
inlining secrets in the build manifest.

## Decision

The hoosh seam binds as **remote-client over HTTP, transported by sandhi**.

- thoth POSTs an OpenAI-compatible chat-completions request to the configured
  gateway via `sandhi_http_post`, parses `choices[0].message.content` with the
  stdlib `json` value parser, and prints it (`src/hoosh.cyr`). The request
  builder, JSON escaper, and response/error extractors are pure and unit-tested;
  only the round-trip does I/O.
- thoth owns the well-known `/v1/chat/completions` path (it is fixed by the
  contract hoosh speaks); `thoth.cyml` carries only the gateway base URL.
- The **mid-session model switch needs no session protocol**: hoosh routes per
  request by the `model` field, so a different model on the next request *is*
  the switch. `/model <id>` sets session state used on the next turn.
- **Configuration is `thoth.cyml`** — thoth's own runtime CYML file (distinct
  from the `cyrius.cyml` build manifest), parsed once at startup via the stdlib
  `cyml` + `toml` modules. The presence of `[hoosh].url` is what flips the seam
  from absent → remote: no endpoint declared, no remote claim. The real file is
  gitignored (it may hold a token); `thoth.cyml.example` is the committed
  template.

In scope: the hoosh seam reached as an HTTP client, non-streaming. Out of scope:
the AGNOS-native co-resident binding (same contract, a later milestone);
streaming/SSE responses; and a swappable-backend abstraction — the seam binds to
hoosh's *contract*, not to arbitrary alternative gateways.

## Consequences

- **Positive** — the signature feature is real and verified end-to-end (a turn
  routes through hoosh to a live provider; a mid-session `/model` switch
  re-routes Anthropic → OpenAI within one session). Transport is composed, not
  reimplemented; choosing sandhi pre-positions the M4 MCP seam, which rides the
  same crate (`sandhi/rpc/mcp.cyr`). Degradation stays honest: an unconfigured
  seam reports absent, an unreachable gateway announces the transport error.
- **Negative** — opting into sandhi drags its whole transitive stdlib set into
  `cyrius.cyml` by hand (Cyrius does not resolve transitive deps, and
  under-declaring silently patches call sites with placeholder bytes). The
  binary grows accordingly; `CYRIUS_DCE=1` trims the unreached surface. thoth now
  owns request/response framing against hoosh's wire shape — a coupling to track
  as hoosh evolves.
- **Neutral** — `thoth.cyml` is a new runtime-config surface thoth must keep
  documented (`thoth.cyml.example`) and honest. The off-AGNOS reach transport
  vs. the native binding distinction is recorded but deferred.

## Alternatives considered

**Hand-roll an HTTP client over stdlib `net`/`http`** — rejected. Stdlib `http`
is GET-only, and hand-building POST/TLS over raw sockets is exactly the
spine-forking the identity ADRs forbid. sandhi exists to be composed.

**Embed hoosh as a library** — impossible: hoosh ships no distlib and is
architecturally a server, not a linkable crate.

**Env-var configuration** (`HOOSH_URL`/`HOOSH_TOKEN`) — workable and matches
hoosh's own `$VAR` key expansion, but a `thoth.cyml` file gives thoth a durable,
documented home for future settings and mirrors the `cyrius.cyml` convention.
Rejected for now; env-var overrides could layer on later.

**Carry the full endpoint path in config** — rejected. The `/v1/chat/completions`
path is fixed by the OpenAI-compatible contract, so thoth owns it; the user
configures only the base URL.
