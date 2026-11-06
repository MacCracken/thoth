#!/usr/bin/env bash
# Record the SHA-256 of every vendored bundle in src/vendor/SHA256SUMS. Run after a sync-*.sh, once its integration edits are
# done: the sums are of the bytes that compile. tests/cases/vendor.cyr holds each bundle to its line, so a bundle changed by
# hand, or half-synced, fails the suite. Nothing else covers these files: cyrius.lock covers lib/ only.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../src/vendor"
if command -v sha256sum > /dev/null; then SUM="sha256sum"; else SUM="shasum -a 256"; fi
$SUM ./*.cyr | sed 's#  \./#  #' > SHA256SUMS
echo "vendor-sums: $(wc -l < SHA256SUMS) bundles"
