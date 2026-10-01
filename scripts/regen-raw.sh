#!/usr/bin/env bash
# Regenerate the REAL Checkov raw output for a corpus, with the scanner version PINNED.
#
#   ./scripts/regen-raw.sh              # both: raw/ from broken/, raw-fixed/ from fixed/
#   ./scripts/regen-raw.sh broken       # only raw/
#   ./scripts/regen-raw.sh fixed        # only raw-fixed/
#   ALLOW_VERSION_BUMP=1 ./scripts/regen-raw.sh broken
#
# Why this exists: expected/expected-findings.json pins exact integers over ONE scanner's
# ruleset. `pip install checkov` today installs a newer Checkov with added and re-severitied
# checks, so regenerating raw/ with an unpinned tool silently turns the baseline into a
# baseline for an undocumented scanner version. The pin lives in <outdir>/versions.json and
# this script REFUSES to overwrite the corpus when it cannot honour it — a version bump has
# to be a deliberate commit next to the new expected/ counts.
#
# Scope: Checkov only. raw/trivy.json, raw/kubescape.json and raw/popeye.json are curated
# representative samples (see README "Notes"), not tool output, so this script does not
# touch them. The pinned trivy command is in the README's "Full run" section.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null || { echo "regen-raw: jq is not on PATH." >&2; exit 127; }

corpus_outdir() {
  case "$1" in
    broken) echo raw ;;
    fixed)  echo raw-fixed ;;
    *) echo "regen-raw: unknown corpus '$1' (expected: broken | fixed)" >&2; return 3 ;;
  esac
}

# checkov_pin <outdir> — the version <outdir>/versions.json says this corpus was built with.
checkov_pin() {
  if [ -f "$1/versions.json" ]; then
    jq -r '.checkov // ""' "$1/versions.json"
  else
    echo ""
  fi
}

# Trim real Checkov output down to the shape this repo commits: an array of one block, only
# the seven fields the engine's adapter reads, and a file_path normalised to /lab/<corpus>/…
# so the committed evidence paths do not depend on where the tool happened to be invoked.
# The list is sorted so two regenerations of the same corpus diff cleanly (Checkov's own
# ordering is not stable); the engine sorts findings by id, so order here is cosmetic.
#
# Heads-up on the FIRST regeneration of raw/ (broken/): the committed raw/checkov.json
# predates this script — it has every "guideline" nulled and is not sorted. Regenerating it
# with checkov 3.3.8 reproduces the same 107 failed checks and the same result_hash
# (verified: total 69, controls 20, CRITICAL 1 / HIGH 16 / MEDIUM 33 / LOW 19), but it does
# add the real guideline URLs, which land in each finding's "references". That is a large
# but count-NEUTRAL baseline diff: re-run with UPDATE_BASELINE=1 and say so in the commit.
TRIM='[ { check_type: (.check_type // "kubernetes"),
          results: { failed_checks: [ (.results.failed_checks // [])[] | {
            check_id, check_name, resource, guideline, severity,
            file_path: ("/lab/" + $corpus + "/" + (.file_path | split("/") | last)),
            file_line_range } ] | sort_by(.file_path, .check_id, .resource) } } ]'

regen() {
  local corpus="$1" outdir pin have runner fp
  outdir="$(corpus_outdir "${corpus}")"
  pin="$(checkov_pin "${outdir}")"

  if [ -z "${pin}" ] && [ -z "${ALLOW_VERSION_BUMP:-}" ]; then
    echo "regen-raw: ${outdir}/versions.json has no \"checkov\" pin — refusing to guess." >&2
    echo "           Set the pin, or re-run with ALLOW_VERSION_BUMP=1 to record whatever is installed." >&2
    return 1
  fi

  have=""
  if command -v checkov >/dev/null; then
    have="$(checkov --version 2>/dev/null | tr -d '[:space:]')"
  fi

  if [ -n "${have}" ] && [ "${have}" = "${pin}" ]; then
    runner=local
  elif [ -n "${pin}" ] && command -v docker >/dev/null; then
    runner=docker          # the pinned image IS the pin — better than refusing
  elif [ -n "${have}" ] && [ -n "${ALLOW_VERSION_BUMP:-}" ]; then
    runner=local           # deliberate bump: use what is installed and record it
  else
    echo "regen-raw: cannot run Checkov ${pin:-<unpinned>} for ${corpus}/." >&2
    if [ -n "${have}" ]; then
      echo "           Installed checkov is ${have}, which does NOT match the pin ${pin}." >&2
      echo "           Either  pip install 'checkov==${pin}'" >&2
      echo "           or      install Docker so the pinned image can be used" >&2
      echo "           or      ALLOW_VERSION_BUMP=1 ./scripts/regen-raw.sh ${corpus}" >&2
      echo "                   (then expect expected/ counts to move — update them in the SAME commit)." >&2
    else
      echo "           No checkov on PATH and no Docker. pip install 'checkov==${pin}'" >&2
    fi
    return 1
  fi

  echo "== ${corpus}/ -> ${outdir}/checkov.json  (checkov ${pin:-${have}}, runner=${runner}) =="
  mkdir -p "${outdir}"
  local tmp
  tmp="$(mktemp)"
  # Checkov exits non-zero when it finds anything, which is the NORMAL case for broken/.
  # Only an empty stdout means it actually failed.
  case "${runner}" in
    local)
      checkov -d "${corpus}" --framework kubernetes -o json --compact --quiet > "${tmp}" || true
      have="$(checkov --version 2>/dev/null | tr -d '[:space:]')"
      ;;
    docker)
      docker run --rm -v "${PWD}:/lab:ro" -w /lab "bridgecrew/checkov:${pin}" \
        -d "${corpus}" --framework kubernetes -o json --compact --quiet > "${tmp}" || true
      have="${pin}"
      ;;
  esac
  if [ ! -s "${tmp}" ]; then
    rm -f "${tmp}"
    echo "regen-raw: checkov produced no output for ${corpus}/ — nothing written." >&2
    return 1
  fi

  jq --indent 1 --arg corpus "${corpus}" "${TRIM}" "${tmp}" > "${outdir}/checkov.json"
  rm -f "${tmp}"

  # versions.json is written from the tool's OWN --version, never by hand. corpus_sha256 ties
  # this output to the manifests it was just produced from: run-lab.sh recomputes it with
  # scripts/corpus-fp.sh and FAILS when the corpus moved but the output did not, which is the
  # only way a reader can trust that raw/ still describes broken/ (and raw-fixed/, fixed/).
  fp="$(./scripts/corpus-fp.sh "${corpus}")"
  if [ -f "${outdir}/versions.json" ]; then
    jq -c --arg v "${have}" --arg fp "${fp}" '.checkov = $v | .corpus_sha256 = $fp' "${outdir}/versions.json" > "${outdir}/versions.json.new"
  else
    jq -cn --arg v "${have}" --arg fp "${fp}" '{checkov: $v, corpus_sha256: $fp}' > "${outdir}/versions.json.new"
  fi
  mv -f "${outdir}/versions.json.new" "${outdir}/versions.json"

  echo "   wrote ${outdir}/checkov.json ($(jq '.[0].results.failed_checks | length' "${outdir}/checkov.json") failed checks) · ${outdir}/versions.json checkov=${have} corpus_sha256=${fp:0:12}"
}

if [ "$#" -eq 0 ]; then
  set -- broken fixed
fi
for c in "$@"; do
  regen "${c}"
done

echo
echo "Now re-run ./run-lab.sh. If the counts moved, decide WHY before touching expected/:"
echo "  manifest or scanner changed -> update expected/ in this commit."
echo "  nothing changed but the engine -> that is an engine regression; report it in Tatar-Kuber."
