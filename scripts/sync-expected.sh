#!/usr/bin/env bash
# Regenerate the DERIVED half of expected/expected-findings.json from a real scan.
#
# expected-findings.json mixes two kinds of field:
#   hand-written   scenario, note, engine  -- intent, caveats and the engine pin.
#                  A human decides these; they are preserved verbatim.
#   derived        total, counts, controls -- pure functions of the scan output.
#                  These were hand-maintained, and drifted twice (16->19->20
#                  controls, 57->69 findings), which is exactly what a baseline
#                  must never do. They are generated here instead.
#
# Usage: ./scripts/sync-expected.sh <scan-result.json> [baseline.json] [--check]
#          baseline defaults to expected/expected-findings.json
#          (no flag) rewrite the baseline
#          --check   exit 1 if the baseline is out of sync, write nothing
set -euo pipefail
cd "$(dirname "$0")/.."

SCAN="${1:?usage: ./scripts/sync-expected.sh <scan-result.json> [baseline.json] [--check]}"
shift
EXPECTED=expected/expected-findings.json
MODE=write
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=--check ;;
    *)       EXPECTED="$1" ;;
  esac
  shift
done

command -v jq >/dev/null || {
  echo "sync-expected: jq is required to regenerate the baseline." >&2
  echo "  Install it (apt install jq / brew install jq) and re-run." >&2
  exit 127
}
[ -f "$SCAN" ]     || { echo "sync-expected: no such scan result: $SCAN" >&2; exit 2; }
[ -f "$EXPECTED" ] || { echo "sync-expected: no such baseline: $EXPECTED" >&2; exit 2; }

# Derive. Severity counts always carry all five keys so a severity dropping to
# zero shows up as 0 rather than vanishing from the object.
NEW="$(jq --slurpfile scan "$SCAN" '
  ($scan[0].findings // []) as $f
  | . + { total: ($f | length),
          counts: ( reduce ["CRITICAL","HIGH","MEDIUM","LOW","INFO"][] as $s
                    ({}; . + { ($s): ($f | map(select(.severity == $s)) | length) }) ),
          controls: ( $f | map(.canonical_control) | unique | sort ) }
' "$EXPECTED")"

CUR="$(cat "$EXPECTED")"

# Compare on sorted keys so a formatting difference never reads as drift, but
# WRITE in the file's natural key order so regeneration does not reshuffle a
# tracked file.
norm() { jq -S . ; }

if [ "$MODE" = "--check" ]; then
  if [ "$(norm <<<"$NEW")" = "$(norm <<<"$CUR")" ]; then
    echo "sync-expected: in sync ($(jq -r '.total' <<<"$NEW") findings · $(jq -r '.controls|length' <<<"$NEW") controls)"
    exit 0
  fi
  echo "sync-expected: ${EXPECTED} is OUT OF SYNC with ${SCAN}" >&2
  diff <(norm <<<"$CUR") <(norm <<<"$NEW") | head -n 40 >&2
  echo "  Re-run ./run-lab.sh --update-baseline and review the diff." >&2
  exit 1
fi

printf '%s\n' "$NEW" > "$EXPECTED"
echo "sync-expected: ${EXPECTED} regenerated — $(jq -r '.total' <<<"$NEW") findings · $(jq -r '.controls|length' <<<"$NEW") controls · $(jq -rc '.counts' <<<"$NEW")"
