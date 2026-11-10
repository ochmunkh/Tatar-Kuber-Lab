#!/usr/bin/env bash
# corpus-fp.sh CORPUS — print ONE sha256 over every manifest in CORPUS/: names AND contents.
#
#   ./scripts/corpus-fp.sh broken
#   ./scripts/corpus-fp.sh fixed
#
# Why: raw/ and raw-fixed/ hold scanner output that was generated FROM those manifests, and
# nothing in the repo used to tie the two together. Edit fixed/ without regenerating raw-fixed/
# and every count in a lab run silently describes the OLD manifests — including the README's
# "fixed/ produces zero findings" claim, which is measured from the committed output, not from
# the directory. scripts/regen-raw.sh records this fingerprint in <outdir>/versions.json
# ("corpus_sha256"); run-lab.sh step 0 recomputes it and FAILS when the two disagree.
#
# Both scripts call THIS file, so there is exactly one definition of the fingerprint: two
# copies that drifted apart would turn every run red with nothing actually wrong.
#
# Tools: find + sort + sha256sum (or `shasum -a 256`) + cut. No jq, no new dependency.
#
# Properties: an edited, added, deleted OR renamed manifest all move the hash (the hash covers
# each path together with its bytes). The file list is NUL-separated and sorted under LC_ALL=C,
# so the value does not depend on directory order or on the caller's locale, and the corpus is
# named relative to the repo root (this script cd's there), so it does not depend on the
# caller's working directory either.
set -euo pipefail
cd "$(dirname "$0")/.."

# GNU coreutils has sha256sum; macOS/BSD has `shasum -a 256`. Both print "<hash>  <name>", so
# the two pipelines below are byte-identical whichever one is in use.
if command -v sha256sum >/dev/null 2>&1; then
  SHA=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA=(shasum -a 256)
else
  echo "corpus-fp: need sha256sum (coreutils) or shasum (macOS/BSD) on PATH." >&2
  exit 127
fi

corpus="${1:?usage: ./scripts/corpus-fp.sh <broken|fixed>}"
corpus="${corpus%/}"
[ -d "${corpus}" ] || { echo "corpus-fp: no such corpus directory: ${corpus}" >&2; exit 2; }

# One sha invocation over the sorted list (not xargs, which may batch and is inconsistent about
# -r across platforms), so the intermediate listing is deterministic on every machine.
# The extension set must match everything the pinned scanner reads: checkov's kubernetes
# framework ingests .json manifests as well as .yaml/.yml, so a vulnerable manifest added as
# .json would otherwise leave the fingerprint — and therefore the lab — green. -L follows
# symlinks for the same reason.
files=()
while IFS= read -r -d '' f; do files+=("${f}"); done < <(
  find -L "${corpus}" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) -print0 | LC_ALL=C sort -z
)

if [ "${#files[@]}" -eq 0 ]; then
  # An empty corpus still gets a stable, documented value (the sha256 of an empty listing)
  # rather than an error, so run-lab.sh reports a mismatch instead of a crash.
  printf '' | "${SHA[@]}" | cut -d' ' -f1
  exit 0
fi

"${SHA[@]}" "${files[@]}" | "${SHA[@]}" | cut -d' ' -f1
