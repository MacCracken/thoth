# Security Policy

> thoth is an **agentic coding tool**: it edits files and runs shell commands
> on the user's machine. That makes its security surface unusually load-bearing
> for its maturity. Read [ADR-0001](docs/adr/0001-os-agnostic-agnos-primary.md)
> for the fail-closed posture.

## Supported versions

thoth is **pre-1.0** and versions as SemVer `0.x`
([ADR-0004](docs/adr/0004-semver-pre-release.md) — this supersedes the earlier
"CalVer at first release" plan). Tagged `0.x` releases exist and ship, but the
surface still moves, so support runs forward only: fixes land on the tip and
are released as the next patch rather than backported.

| Version | Supported |
| ------- | --------- |
| `main` (tip of default branch) | ✅ best-effort |
| the latest `0.x` tag | ✅ best-effort — fixed forward in the next patch |
| any earlier `0.x` tag | ❌ upgrade to the latest |

## The AGNOS security model

thoth does **not** own its own security boundary. In AGNOS:

- **kavach** owns the sandbox — applications never manage their own security
  boundaries.
- **t-ron** owns MCP per-tool authorization — the gate around the file-edits
  and shell commands the agent performs.

thoth **consumes** these; it does not reimplement them. Off AGNOS, where t-ron
is unreachable, authorization degrades **closed** — a conservative built-in
deny/prompt, never a silent allow — and the absence is announced to the user,
never faked. See [architecture note 001](docs/architecture/001-consumer-only-no-domain-logic.md).

## Reporting a vulnerability

Please report suspected vulnerabilities **privately** — do not open a public
issue for an unfixed flaw.

- Email: **cyriusmaccken@gmail.com** with a subject line starting `thoth security:`
- Include: affected component, reproduction steps, impact, and any suggested fix.
- You will get an acknowledgement as soon as is practical. Coordinated
  disclosure is appreciated; please give a reasonable window before public
  disclosure.

Fixes are tracked per the AGNOS first-party process; findings are recorded
under [`docs/audit/`](docs/audit/) — see
[`2026-08-24-audit.md`](docs/audit/2026-08-24-audit.md) for the standing pass.

## Scope notes

- thoth is a **driver** — vulnerabilities in inference, the MCP protocol, MCP
  authorization, orchestration, or personality belong to the owning crate
  (hoosh / bote / t-ron / daimon / avatara). Report those to the owning project;
  report **thoth-specific** issues (the driver loop, the capability seams, the
  off-AGNOS degradation path) here.
