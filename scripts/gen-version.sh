#!/usr/bin/env bash
# gen-version.sh — generate src/version.cyr from the VERSION file.
#
# VERSION is the SINGLE SOURCE OF TRUTH for thoth's version (cyrius.cyml reads it
# too via ${file:VERSION}). The runtime binary can't read the file at run time, so
# the version string is embedded into source here — `thoth_version()`, the one
# runtime copy, consumed by the banner, the /state build line, and the TUI status
# bar. Run on every version bump (and by scripts/build.sh before each build) so the
# generated file can never drift from VERSION. The generated src/version.cyr IS
# committed so a raw `cyrius build` (without this script) still sees the right value.
set -euo pipefail
cd "$(dirname "$0")/.."
V="$(tr -d '[:space:]' < VERSION)"
cat > src/version.cyr <<EOF
# thoth — runtime version string. GENERATED from ./VERSION by scripts/gen-version.sh.
# DO NOT EDIT BY HAND. VERSION is the single source of truth (cyrius.cyml reads it too).
fn thoth_version() { return "$V"; }
EOF
echo "gen-version: src/version.cyr -> $V"
