#!/usr/bin/env python3
"""Check that the two language halves of README.md have the same STRUCTURE.

Both halves are hand-maintained, and in practice one gets updated and the other
forgotten -- this repo's git history carries several "fix the stale Mongolian
numbers" commits for exactly that reason. The content cannot be compared by
machine (being in two languages is the point), but the structure must match: a
section added on one side belongs on the other too.

Compared: heading counts per level, table rows, fenced code blocks.

Usage:  python3 scripts/check-readme-parity.py [README.md]
Exit :  0 in sync, 1 drifted, 2 could not read the file / find the sections.
"""

import re
import sys
from pathlib import Path

# The English half runs from the top of the file to the Mongolian heading.
MN_HEADING = re.compile(r"^##\s+Монгол хэл дээр\s*$", re.M)

FENCE = re.compile(r"^\s*```")
HEADING = re.compile(r"^(#{2,4})\s+\S")
TABLE_ROW = re.compile(r"^\s*\|.*\|\s*$")
TABLE_SEP = re.compile(r"^\s*\|[\s:|-]+\|\s*$")

# Heading LEVELS are pooled deliberately. The Mongolian half nests its sections
# one level deeper (### under the single "## Монгол хэл дээр"), so comparing per
# level would report permanent, meaningless drift. Tatar-Kuber's own parity test
# (internal/canonical/readme_test.go) pools levels 2-3 for the same reason; this
# follows that established convention.
LABELS = {
    "headings": "sections",
    "table_rows": "table rows",
    "code_blocks": "code blocks",
}

# Sections that deliberately exist in English only, with the reason. Adding a
# name here is a decision that the section needs no Mongolian counterpart. If it
# DOES need one, write the Mongolian instead -- never machine-translate it.
#
# EMPTY as of 2026-09-30. The Mongolian half used to be a QUICK START -- demo,
# expected controls, why the lab exists -- with the operational detail left in
# English: the pipeline diagram, the full local run, the Kind cluster, the notes
# and the licence. All five are now written, so nothing is discounted and the
# checker watches the whole file. The set stays here because it is the honest
# place to record the NEXT such decision; an entry naming a section that no
# longer exists is caught below, so it cannot silently mask real drift.
EN_ONLY_SECTIONS = set()

# Fenced blocks not expected on the Mongolian side. One: the "Expected:" sample
# of verify-lab output under "30-second demo". It is generated into the English
# half by scripts/sync-readme-counts.sh, which has no Mongolian marker, and the
# engine prints that table in whichever language it was asked for -- so a second
# copy would be a hand-maintained duplicate of generated text.
EN_ONLY_CODE_BLOCKS = 1


def measure(body: str) -> dict:
    counts = {k: 0 for k in LABELS}
    in_fence = False
    for line in body.split("\n"):
        if FENCE.match(line):
            if not in_fence:
                counts["code_blocks"] += 1
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if HEADING.match(line):
            counts["headings"] += 1
        if TABLE_ROW.match(line) and not TABLE_SEP.match(line):
            counts["table_rows"] += 1
    return counts


def main(argv) -> int:
    path = Path(argv[1] if len(argv) > 1 else "README.md")
    if not path.is_file():
        print("check-readme-parity: no such file: %s" % path, file=sys.stderr)
        return 2

    src = path.read_text(encoding="utf-8")
    m = MN_HEADING.search(src)
    if not m:
        print(
            "check-readme-parity: the '## Монгол хэл дээр' heading was not found.\n"
            "  If the section heading changed, update MN_HEADING in this script.",
            file=sys.stderr,
        )
        return 2

    en, mn = measure(src[: m.start()]), measure(src[m.start() :])

    # Do not count the "## Монгол хэл дээр" divider itself as a section.
    mn["headings"] -= 1

    # Discount the recorded English-only sections, and verify each one is really
    # still there -- a stale allowlist entry would quietly mask new drift.
    en_heads = {
        re.sub(r"<!--.*?-->", "", h).strip()
        for h in re.findall(r"^#{2,4}\s+(.*)$", src[: m.start()], re.M)
    }
    stale = sorted(EN_ONLY_SECTIONS - en_heads)
    if stale:
        print(
            "check-readme-parity: EN_ONLY_SECTIONS lists section(s) that no longer exist: "
            + ", ".join(stale)
            + "\n  Remove them from this script so real drift is not masked.",
            file=sys.stderr,
        )
        return 2
    en["headings"] -= len(EN_ONLY_SECTIONS)
    en["code_blocks"] -= EN_ONLY_CODE_BLOCKS

    problems = [
        "  %-16s EN=%-4d MN=%-4d (differ by %d)" % (LABELS[k], en[k], mn[k], abs(en[k] - mn[k]))
        for k in LABELS
        if en[k] != mn[k]
    ]
    summary = "  EN [%s]\n  MN [%s]" % (
        " ".join("%s=%d" % (k, en[k]) for k in LABELS),
        " ".join("%s=%d" % (k, mn[k]) for k in LABELS),
    )

    if not problems:
        print(
            "check-readme-parity: OK -- both halves match "
            "(%d English-only section(s) discounted, see EN_ONLY_SECTIONS)"
            % len(EN_ONLY_SECTIONS)
        )
        print(summary)
        return 0

    print("check-readme-parity: THE TWO LANGUAGE HALVES HAVE DRIFTED", file=sys.stderr)
    print("\n".join(problems), file=sys.stderr)
    print(
        "\n  A section, table or code block added on one side belongs on the other.\n"
        "  Do NOT machine-translate: the Mongolian half is written, not generated.\n"
        + summary,
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
