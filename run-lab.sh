#!/usr/bin/env bash
# Exercise the FULL TATAR-Kuber feature set against this lab, offline (no cluster, no scanners),
# and SELF-CHECK the result: any drift from the committed baseline makes this script exit non-zero.
#   go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
#   ./run-lab.sh            # English
#   ./run-lab.sh mn         # Mongolian report
#   ./run-lab.sh --update-baseline    # adopt THIS run as the baseline — then read `git diff`
# The canonical registry is embedded in the binary, so no engine checkout is needed.
# (Override with TATAR_REGISTRY=/path/to/schema/canonical-controls.yaml if you want.)
# Nothing tracked is written: the scan goes to .lab-out/ and the reports to normalized/
# (report.html, report.json, tatar.sarif — all gitignored), so `git status` stays clean
# unless you pass --update-baseline.
# `tatar-kuber` is the ONLY hard requirement. jq is a fast path, not a dependency: without it
# steps 0 and 7 use coreutils fallbacks and step 8 is skipped — the run says so as it goes and
# again in a summary at the end, so a weaker run can never look like a full one.
set -euo pipefail
cd "$(dirname "$0")"

# --------------------------------------------------------------------------
# Arguments. The language used to be read straight off $1, so there was nowhere
# to put a flag; adopting a new baseline was an environment variable only,
# which is easy to miss in the help text and easy to set by accident.
# --------------------------------------------------------------------------
LANG_OPT=en
UPDATE_BASELINE="${UPDATE_BASELINE:-}"   # legacy env form still honoured
usage() {
  cat <<'USAGE'
Usage: ./run-lab.sh [en|mn] [--update-baseline]

  en | mn             language for the rendered report (default: en)
  --update-baseline   adopt THIS run as the committed baseline: rewrite
                      normalized/tatar-findings.json and regenerate the derived
                      fields of expected/expected-findings.json, then review
                      `git diff` before committing.
  -h | --help         this message

  UPDATE_BASELINE=1 ./run-lab.sh   is still accepted and means the same thing.
USAGE
}
while [ $# -gt 0 ]; do
  case "$1" in
    en|mn)                  LANG_OPT="$1" ;;
    --update-baseline)      UPDATE_BASELINE=1 ;;
    -h|--help)              usage; exit 0 ;;
    *) echo "run-lab: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
REG_FLAG=""
[ -n "${TATAR_REGISTRY:-}" ] && REG_FLAG="--registry ${TATAR_REGISTRY}"

EXPECTED=expected/expected-findings.json
GOLDEN=normalized/tatar-findings.json
OUT=.lab-out              # scratch scan output (gitignored)
OUT_FIXED=.lab-out-fixed  # scratch scan output for the hardened corpus (gitignored)

# Preflight — `go install` drops the binary in $(go env GOPATH)/bin, which is usually NOT on
# PATH. Without this the script printed a banner, then died on a bare "command not found".
command -v tatar-kuber >/dev/null || {
  echo "tatar-kuber is not on PATH. Install the engine, then re-run:" >&2
  echo "  go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest" >&2
  echo "  export PATH=\"\$(go env GOPATH)/bin:\$PATH\"" >&2
  exit 127
}

# jq makes the self-checks sharper; it does not gate them. Missing, the lab still runs and
# still fails on drift — it just compares text instead of canonical JSON. Each fallback
# announces itself, is listed again under "[lab] DEGRADED" at the end, and CI has jq, so the
# full-strength comparison still gates every push.
HAVE_JQ=1
command -v jq >/dev/null || HAVE_JQ=0
# A newline-joined string rather than an array: `${#arr[@]}` on an EMPTY array is an unbound
# variable under `set -u` in bash 3.2, which is still /bin/bash on macOS.
DEGRADED=""
degraded() { DEGRADED="${DEGRADED}         - $*"$'\n'; }

FAILED=0
fail() { FAILED=1; echo "   x $*" >&2; }

# json_str FILE KEY — the string value of a TOP-LEVEL key. jq when it is there; otherwise a
# line-oriented fallback, which is enough for exactly the files read here: small, committed
# by hand, one "key": "value" per key, and no nested object that repeats the same key name.
json_str() {
  if [ "${HAVE_JQ}" = 1 ]; then
    jq -r --arg k "$2" '.[$k] // ""' "$1"
  else
    # First match, then q — not `| head -1`, whose early exit can SIGPIPE sed and trip pipefail.
    sed -n '/"'"$2"'"[[:space:]]*:/{s/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q;}' "$1"
  fi
}

# ver_ge A B — true when A >= B on major.minor.patch. A pre-release suffix ("1.0.3-dev") is a
# build OF that version, so it counts as satisfying it: a HEAD build is what CI uses.
ver_ge() {
  local a b x y i
  IFS=. read -r -a a <<<"${1%%-*}"
  IFS=. read -r -a b <<<"${2%%-*}"
  for i in 0 1 2; do
    x="${a[i]:-0}"; x="${x//[^0-9]/}"; x="${x:-0}"
    y="${b[i]:-0}"; y="${y//[^0-9]/}"; y="${y:-0}"
    if [ "${x}" -gt "${y}" ]; then return 0; fi
    if [ "${x}" -lt "${y}" ]; then return 1; fi
  done
  return 0
}

# check_corpus CORPUS RAWDIR — the manifests in CORPUS/ must still be the ones RAWDIR/ was
# generated from. Nothing else in this script reads CORPUS/ at all: the scan consumes the
# COMMITTED scanner output, so a manifest edited without `./scripts/regen-raw.sh CORPUS`
# leaves every count below describing the previous manifests. That is the gap this closes.
check_corpus() {
  local corpus="$1" rawdir="$2" want have
  if [ ! -f "${rawdir}/versions.json" ]; then
    fail "${rawdir}/versions.json is missing — cannot tell which ${corpus}/ the committed scanner output belongs to."
    return
  fi
  want="$(json_str "${rawdir}/versions.json" corpus_sha256)"
  if ! have="$(./scripts/corpus-fp.sh "${corpus}" 2>&1)"; then
    fail "could not fingerprint ${corpus}/: ${have}"
    return
  fi
  if [ -z "${want}" ]; then
    fail "${rawdir}/versions.json has no \"corpus_sha256\" — run ./scripts/regen-raw.sh ${corpus} so the committed scanner output is tied to ${corpus}/ (expected ${have:0:12})."
  elif [ "${want}" = "${have}" ]; then
    echo "   ok  ${corpus}/ is the corpus ${rawdir}/ was generated from (sha256 ${have:0:12})"
  else
    fail "${corpus}/ has changed since ${rawdir}/ was generated (now ${have:0:12}, recorded ${want:0:12}). ${rawdir}/ is STALE, so every count below is about the OLD manifests. Re-run ./scripts/regen-raw.sh ${corpus} and review what moved."
  fi
}

rm -rf "${OUT}" "${OUT_FIXED}"
mkdir -p normalized "${OUT}" "${OUT_FIXED}"

echo "== 0. pins — engine range, and each corpus against the raw output committed for it =="
if [ "${HAVE_JQ}" = 0 ]; then
  echo "   ~   jq is not on PATH — reading the pins with sed instead (see the summary at the end)"
  degraded "steps 0/7 used coreutils fallbacks instead of jq"
fi
WANT_ENGINE="$(json_str "${EXPECTED}" engine)"
HAVE_ENGINE="$(tatar-kuber version | awk '{print $NF}')"   # "TATAR-Kuber 1.0.3-dev" -> 1.0.3-dev
if [ -z "${WANT_ENGINE}" ]; then
  echo "   (no \"engine\" pin in ${EXPECTED} — skipped)"
elif [ "${WANT_ENGINE#>=}" = "${WANT_ENGINE}" ]; then
  fail "unsupported engine pin '${WANT_ENGINE}' in ${EXPECTED} — expected '>=X.Y.Z'."
elif ver_ge "${HAVE_ENGINE}" "${WANT_ENGINE#>=}"; then
  echo "   ok  engine ${HAVE_ENGINE} satisfies ${WANT_ENGINE}"
else
  fail "engine ${HAVE_ENGINE} is older than ${WANT_ENGINE} — the counts pinned in ${EXPECTED} will NOT match. Upgrade tatar-kuber before trusting a failure below."
fi
check_corpus broken raw
check_corpus fixed  raw-fixed

echo; echo "== 1. doctor — which scanners are installed (live Mode B readiness) =="
tatar-kuber doctor ${REG_FLAG} || true

echo; echo "== 2. scan — offline raw -> canonical + dedup + confidence + risk + MITRE =="
# Always scan in `en`: titles/remediation are localised, so the committed baseline has to be
# in one fixed language to stay diffable. The report step below renders ${LANG_OPT} from this
# same scan — language is a property of the OUTPUT, not of the scan (see `report --lang`).
tatar-kuber scan --raw-dir raw --cluster tatar-kuber-lab --lang en ${REG_FLAG} -o "${OUT}"

echo; echo "== 3. reports — HTML + SARIF + JSON =="
tatar-kuber report --input "${OUT}/scan-result.json" -o html  --lang "${LANG_OPT}" --out normalized/report.html
tatar-kuber report --input "${OUT}/scan-result.json" -o sarif --lang "${LANG_OPT}" --out normalized/tatar.sarif
tatar-kuber report --input "${OUT}/scan-result.json" -o json   --lang "${LANG_OPT}" > normalized/report.json

echo; echo "== 4. CI gate — policy .tatar-kuber.yaml (corpus is vulnerable, so this MUST fail) =="
# `gate` exits 0 = passed, 1 = policy violated, 2/3 = error (bad --input/--policy). This step
# used to swallow every outcome in a `|| echo "expected"`, so a gate that PASSED on 1 CRITICAL
# + 16 HIGH printed nothing unusual and left the run green — the one result that proves the
# gate is broken was the one result nobody checked.
GATE_RC=0
tatar-kuber gate --input "${OUT}/scan-result.json" --policy .tatar-kuber.yaml || GATE_RC=$?
case "${GATE_RC}" in
  0) fail "gate PASSED on the deliberately vulnerable corpus — .tatar-kuber.yaml or the corpus regressed. A gate that cannot block THIS posture blocks nothing." ;;
  1) echo "   ok  gate blocked the insecure posture (exit 1) — expected for the lab corpus." ;;
  *) fail "gate exited ${GATE_RC} — that is an error (bad --input or --policy), not a policy verdict, so this run proves nothing about the gate." ;;
esac

echo; echo "== 5. verify-lab — vulnerable corpus (broken/) regression baseline (MUST pass) =="
tatar-kuber verify-lab --input "${OUT}/scan-result.json" --expected "${EXPECTED}" || {
  if [ -n "${UPDATE_BASELINE:-}" ]; then
    echo "   ~  mismatch ignored: --update-baseline is about to regenerate ${EXPECTED} (step 7b)."
  else
    fail "verify-lab FAILED against ${EXPECTED}."
  fi
}

echo; echo "== 6. verify-lab — hardened corpus (fixed/), measured, not assumed =="
# What this measures: the COMMITTED Checkov 3.3.8 output for fixed/ (raw-fixed/), re-normalised
# through the engine, must yield zero canonical findings. It does not re-run Checkov — no
# scanner is installed here. The fixed/ <-> raw-fixed/ fingerprint in step 0 is what stops
# that committed output from silently describing a different fixed/ than the one on disk.
tatar-kuber scan --raw-dir raw-fixed --cluster tatar-kuber-lab-fixed --lang en ${REG_FLAG} -o "${OUT_FIXED}"
tatar-kuber verify-lab --input "${OUT_FIXED}/scan-result.json" --expected expected/expected-fixed.json || {
  if [ -n "${UPDATE_BASELINE:-}" ]; then
    echo "   ~  mismatch ignored: --update-baseline is about to regenerate expected/expected-fixed.json (step 7b)."
  else
    fail "verify-lab FAILED against expected/expected-fixed.json — the hardened corpus moved."
  fi
}

echo; echo "== 7. baseline — per-finding diff against the committed ${GOLDEN} =="
# Stripped from BOTH sides: fields that change on every run. result_hash is deliberately KEPT —
# it is sha256 over id+severity only, so it is a real signal, not noise.
STABLE='del(.metadata.scan_id, .metadata.started_at, .metadata.finished_at)
        | .findings = ((.findings // []) | map(del(.first_seen, .last_seen)))'
# The same five fields as a line filter, for the jq-less path. An unfiltered diff is not an
# option: scan_id and the four timestamps move on EVERY run, so it could never come back clean.
VOLATILE_LINES='^[[:space:]]*"(scan_id|started_at|finished_at|first_seen|last_seen)"[[:space:]]*:'
# norm SRC DST — canonical JSON with jq; otherwise the file minus the volatile lines. The
# fallback is weaker in two ways: it compares text, so re-ordered keys or re-indented JSON
# read as drift, and the filter is by key NAME, so a nested field that happened to be called
# first_seen would be dropped too. It is strictly a comparison, never a rewrite of anything.
norm() {
  if [ "${HAVE_JQ}" = 1 ]; then
    jq -S "${STABLE}" "$1" > "$2"
  else
    # grep exits 1 when it prints nothing; an empty side just shows up as a huge diff below.
    grep -Ev "${VOLATILE_LINES}" "$1" > "$2" || true
  fi
}
norm "${OUT}/scan-result.json" "${OUT}/actual.norm.json"
if [ -f "${GOLDEN}" ]; then
  norm "${GOLDEN}" "${OUT}/golden.norm.json"
elif [ "${HAVE_JQ}" = 1 ]; then
  echo 'null' > "${OUT}/golden.norm.json"
else
  : > "${OUT}/golden.norm.json"
fi
if [ "${HAVE_JQ}" = 1 ]; then
  HOW="field by field"
else
  HOW="line by line, jq absent: volatile lines filtered, key order NOT canonicalised"
fi
# Only read the count when the file exists — a missing golden is drift, reported below, not a
# reason for this script to die inside a command substitution.
TOTAL_IN_GOLDEN=""
if [ -f "${GOLDEN}" ]; then
  if [ "${HAVE_JQ}" = 1 ]; then
    TOTAL_IN_GOLDEN="$(jq -r '.summary.total_findings // ""' "${GOLDEN}")"
  else
    TOTAL_IN_GOLDEN="$(sed -n '/"total_findings"/{s/.*"total_findings"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p;q;}' "${GOLDEN}")"
  fi
fi
if diff -u "${OUT}/golden.norm.json" "${OUT}/actual.norm.json" > "${OUT}/baseline.diff"; then
  echo "   ok  identical to the committed baseline (${TOTAL_IN_GOLDEN:-?} findings, compared ${HOW})"
else
  head -n 60 "${OUT}/baseline.diff"
  DIFF_LINES="$(wc -l < "${OUT}/baseline.diff")"
  if [ "${DIFF_LINES}" -gt 60 ]; then
    echo "   ... $((DIFF_LINES - 60)) more line(s) in ${OUT}/baseline.diff"
  fi
  if [ "${HAVE_JQ}" = 0 ]; then
    echo "   ~  compared ${HOW} — re-check with jq installed before you believe a formatting-only diff."
  fi
  if [ -n "${UPDATE_BASELINE:-}" ]; then
    cp -f "${OUT}/scan-result.json" "${GOLDEN}"
    echo "   !  --update-baseline — ${GOLDEN} rewritten from this run."
    echo "      Now READ \`git diff ${GOLDEN}\` and justify every line before committing it."
    echo "      A count that moved WITHOUT a manifest or raw/ change is an engine regression:"
    echo "      report it in Tatar-Kuber, do not absorb it here."
  else
    fail "output drifted from ${GOLDEN}. If the change is intended, re-run with --update-baseline and review the diff."
  fi
fi

echo; echo "== 7b. expected/ — the DERIVED fields are generated from this scan, not hand-typed =="
if [ "${HAVE_JQ}" = 0 ]; then
  echo "   ~   SKIPPED — ./scripts/sync-expected.sh needs jq."
  degraded "step 7b (expected-findings.json derived-field check) did not run"
elif [ -n "${UPDATE_BASELINE:-}" ]; then
  ./scripts/sync-expected.sh "${OUT}/scan-result.json"
  ./scripts/sync-expected.sh "${OUT_FIXED}/scan-result.json" expected/expected-fixed.json
  echo "      Read \`git diff ${EXPECTED}\` before committing: a count that moved"
  echo "      WITHOUT a manifest or raw/ change is an engine regression."
elif ./scripts/sync-expected.sh "${OUT}/scan-result.json" --check \
     && ./scripts/sync-expected.sh "${OUT_FIXED}/scan-result.json" expected/expected-fixed.json --check; then
  echo "   ok  total, counts and controls match the scan (both corpora)"
else
  fail "${EXPECTED} no longer matches the scan. If the change is intended, re-run with --update-baseline."
fi

echo; echo "== 8. docs — README badges/counts and the gate policy match ${EXPECTED} =="
if [ "${HAVE_JQ}" = 0 ]; then
  echo "   ~   SKIPPED — ./scripts/sync-readme-counts.sh renders the generated blocks with jq."
  degraded "step 8 (README/.tatar-kuber.yaml count check) did not run"
elif ./scripts/sync-readme-counts.sh --check; then
  echo "   ok  every generated count is in sync"
else
  fail "README/.tatar-kuber.yaml counts are stale — run ./scripts/sync-readme-counts.sh and commit the result."
fi

echo
if [ -n "${DEGRADED}" ]; then
  echo "[lab] DEGRADED — jq was not on PATH, so this run was weaker than CI's:"
  printf '%s' "${DEGRADED}"
  echo "         Install jq (apt install jq / brew install jq) for the full-strength run."
fi
if [ "${FAILED}" -ne 0 ]; then
  echo "[lab] FAILED — see the x lines above."
  exit 1
fi
echo "[lab] done → normalized/report.html · normalized/tatar.sarif · normalized/report.json"
