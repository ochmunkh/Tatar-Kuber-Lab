#!/usr/bin/env bash
# Exercise the FULL TATAR-Kuber feature set against this lab, offline (no cluster, no scanners).
#   go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
#   ./run-lab.sh            # English
#   ./run-lab.sh mn         # Mongolian report
# The canonical registry is embedded in the binary, so no engine checkout is needed.
# (Override with TATAR_REGISTRY=/path/to/schema/canonical-controls.yaml if you want.)
set -euo pipefail
cd "$(dirname "$0")"
LANG_OPT="${1:-en}"
REG_FLAG=""
[ -n "${TATAR_REGISTRY:-}" ] && REG_FLAG="--registry ${TATAR_REGISTRY}"

mkdir -p normalized

echo "== 1. doctor — which scanners are installed (live Mode B readiness) =="
tatar-kuber doctor ${REG_FLAG} || true

echo; echo "== 2. scan — offline raw -> canonical + dedup + confidence + risk + MITRE =="
tatar-kuber scan --raw-dir raw --cluster tatar-kuber-lab --lang "${LANG_OPT}" ${REG_FLAG} -o normalized
mv -f normalized/scan-result.json normalized/tatar-findings.json

echo; echo "== 3. reports — HTML + SARIF + JSON =="
tatar-kuber report --input normalized/tatar-findings.json -o html  --out normalized/report.html
tatar-kuber report --input normalized/tatar-findings.json -o sarif --out normalized/tatar.sarif
tatar-kuber report --input normalized/tatar-findings.json -o json  > normalized/report.json

echo; echo "== 4. CI gate — policy .tatar-kuber.yaml (corpus is vulnerable, so this SHOULD fail) =="
tatar-kuber gate --input normalized/tatar-findings.json --policy .tatar-kuber.yaml \
  || echo "   ^ gate blocked the insecure posture — expected for the lab corpus."

echo; echo "== 5. verify-lab — regression baseline (this MUST pass) =="
tatar-kuber verify-lab --input normalized/tatar-findings.json --expected expected/expected-findings.json

echo; echo "[lab] done → normalized/report.html · normalized/tatar.sarif · normalized/report.json"
