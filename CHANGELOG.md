# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Project identity, goal, and the OS-agnostic-but-AGNOS-primary design captured
  in `CLAUDE.md`, `README.md`, and `docs/development/{state,roadmap}.md`.
- ADR-0001 (OS-agnostic reach, AGNOS-primary home), ADR-0002 (consume the AGNOS
  stack), ADR-0003 (wear the avatara Thoth archetype); architecture note 001
  (consumer-only: thoth holds no first-party domain logic). Indexed in their
  READMEs.
- Required root files: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`.

### Changed
- `cyrius.cyml`: `version` now reads `${file:VERSION}` (was an inlined `0.1.0`);
  real `description`; added `repository`; `[build].output` → `build/thoth`.
- Standards links repointed from the stale `docs/development/applications/…`
  path to `docs/development/first-party/…`.

## [0.1.0]

### Added
- Initial project scaffold
