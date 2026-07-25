#!/usr/bin/env bash
# Run the TATAR-Kuber lab end-to-end. Requires `tatar-kuber` on PATH and the engine's
# canonical registry via --registry or $TATAR_REGISTRY.
#   go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
set -euo pipefail
cd "$(dirname "$0")"
LANG_OPT="${1:-en}"
REG="${TATAR_REGISTRY:?set TATAR_REGISTRY to engine schema/canonical-controls.yaml}"

# Optional: regenerate real scanner output (offline, no cluster) if tools are present.
command -v checkov >/dev/null 2>&1 && checkov -d broken --framework kubernetes -o json > raw/checkov.json 2>/dev/null || true
command -v trivy   >/dev/null 2>&1 && trivy config broken --format json                 > raw/trivy.json   2>/dev/null || true

echo "[lab] raw scanner output -> TATAR normalization -> report"
tatar-kuber scan   --raw-dir raw --cluster tatar-kuber-lab --lang "$LANG_OPT" --registry "$REG" -o normalized
mv -f normalized/scan-result.json normalized/tatar-findings.json
tatar-kuber report --input normalized/tatar-findings.json -o html --out normalized/report.html
tatar-kuber verify-lab --input normalized/tatar-findings.json --expected expected/expected-findings.json
