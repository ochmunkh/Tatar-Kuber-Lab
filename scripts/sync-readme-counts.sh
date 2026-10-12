#!/usr/bin/env bash
# Generate every hand-typed count in README.md (BOTH language halves) and .tatar-kuber.yaml
# from expected/expected-findings.json — one source of truth, so the English and the Монгол
# numbers cannot drift apart. The git log shows why: `19 control, 69 finding` had to be
# repaired in the Mongolian half by a separate follow-up commit.
#
#   ./scripts/sync-readme-counts.sh          # rewrite the generated blocks in place
#   ./scripts/sync-readme-counts.sh --check  # exit 1 if any block is stale (run-lab.sh / CI)
#
# A generated block is whatever sits between  <!-- counts:NAME -->  and  <!-- /counts:NAME -->.
# Everything outside those markers is yours; the script never touches it.
#
# The verify-lab block reproduces the output format of the engine's internal/cli/verify.go
# ("  %-8s expected %d, actual %d  [%s]"). If that format ever changes, change it here too.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null || { echo "sync-readme-counts: jq is not on PATH." >&2; exit 127; }

EXPECTED=expected/expected-findings.json
MODE=write
case "${1:-}" in
  ""|write|--write) MODE=write ;;
  check|--check)    MODE=check ;;
  *) echo "usage: $0 [--check]" >&2; exit 3 ;;
esac

SCENARIO="$(jq -r '.scenario' "${EXPECTED}")"
NCONTROLS="$(jq -r '.controls | length' "${EXPECTED}")"
TOTAL="$(jq -r '.total' "${EXPECTED}")"
CRITICAL="$(jq -r '.counts.CRITICAL // 0' "${EXPECTED}")"
HIGH="$(jq -r '.counts.HIGH // 0' "${EXPECTED}")"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# verify_block — the fenced "Expected:" sample output, rendered from expected/.
verify_block() {
  printf '```\n'
  printf 'verify-lab: %s\n' "${SCENARIO}"
  printf '  controls: expected %s, missing 0\n' "${NCONTROLS}"
  printf '  findings: actual %s\n' "${TOTAL}"
  local sev v
  for sev in CRITICAL HIGH MEDIUM LOW INFO; do
    v="$(jq -r --arg s "${sev}" '.counts[$s] // empty' "${EXPECTED}")"
    if [ -n "${v}" ]; then
      printf '  %-8s expected %s, actual %s  [ok]\n' "${sev}" "${v}" "${v}"
    fi
  done
  printf 'RESULT: PASS\n'
  printf '```\n'
}

# splice <file> <name> <body> — replace the text between the NAME markers, on stdout.
splice() {
  jq -Rsj --arg n "$2" --arg b "$3" '
    . as $d
    | "<!-- counts:\($n) -->" as $s
    | "<!-- /counts:\($n) -->" as $e
    | ($d | index($s)) as $i
    | ($d | index($e)) as $j
    | if   $i == null then error("marker <!-- counts:\($n) --> not found")
      elif $j == null then error("marker <!-- /counts:\($n) --> not found")
      elif $j < $i    then error("markers for \($n) are in the wrong order")
      else $d[: $i + ($s | length)] + $b + $d[$j :] end
  ' "$1"
}

# apply <file> <name> <body> — splice in place.
apply() {
  splice "$1" "$2" "$3" > "$1.tmp"
  mv -f "$1.tmp" "$1"
}

cp README.md "${TMP}/README.md"
cp .tatar-kuber.yaml "${TMP}/.tatar-kuber.yaml"

apply "${TMP}/README.md" badge \
  "![Controls](https://img.shields.io/badge/expected-${NCONTROLS}%20canonical%20controls-1F6F54)"
# $'\n' is ANSI-C quoting, not command substitution: $(...) strips trailing newlines, and the
# verify-lab markers sit on their own lines around the fenced block.
apply "${TMP}/README.md" verify-lab $'\n'"$(verify_block)"$'\n'
apply "${TMP}/README.md" controls-en   "(${NCONTROLS})"
apply "${TMP}/README.md" controls-mn   "(${NCONTROLS})"
apply "${TMP}/README.md" regression-en "${NCONTROLS} controls → 8"
apply "${TMP}/README.md" regression-mn "${NCONTROLS} control → 8"
apply "${TMP}/.tatar-kuber.yaml" policy "${CRITICAL} CRITICAL + ${HIGH} HIGH"

STALE=0
for f in README.md .tatar-kuber.yaml; do
  if ! diff -u "${f}" "${TMP}/${f}" > "${TMP}/${f}.diff"; then
    STALE=1
    if [ "${MODE}" = check ]; then
      echo "sync-readme-counts: ${f} is out of date with ${EXPECTED}:" >&2
      cat "${TMP}/${f}.diff" >&2
    else
      cp -f "${TMP}/${f}" "${f}"
      echo "updated ${f}"
    fi
  fi
done

if [ "${MODE}" = check ] && [ "${STALE}" -ne 0 ]; then
  echo "sync-readme-counts: run ./scripts/sync-readme-counts.sh and commit the result." >&2
  exit 1
fi
if [ "${STALE}" -eq 0 ]; then
  echo "sync-readme-counts: in sync (${NCONTROLS} controls · ${TOTAL} findings · ${CRITICAL} CRITICAL + ${HIGH} HIGH)"
fi
