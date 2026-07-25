#!/usr/bin/env bash
# Run the TATAR-Kuber lab end-to-end. Requires the `tatar-kuber` binary on PATH
# (go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest) and the
# engine's canonical registry via --registry or $TATAR_REGISTRY.
set -euo pipefail
cd "$(dirname "$0")"
LANG_OPT="${1:-en}"
REG="${TATAR_REGISTRY:?set TATAR_REGISTRY to engine schema/canonical-controls.yaml}"

if command -v checkov >/dev/null 2>&1; then
  echo "[lab] checkov -d broken ..."
  checkov -d broken --framework kubernetes -o json > raw/checkov.json 2>/dev/null || true
fi

echo "[lab] scan + verify ..."
tatar-kuber scan   --raw-dir raw --cluster tatar-kuber-lab --lang "$LANG_OPT" --registry "$REG" -o out
tatar-kuber report --input out/scan-result.json -o html --out out/report.html
tatar-kuber verify-lab --input out/scan-result.json --expected expected-findings.json
