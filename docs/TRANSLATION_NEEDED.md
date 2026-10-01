# Translation needed — Mongolian

A worklist, not a translation. **Nothing here has been machine-translated**, and
nothing should be.

Generated 2026-09-30 by classifying every tracked `.md` as entirely English,
bilingual (has a `Монгол хэл дээр` half), or mixed.

---

## Low — contributor-facing

| Section | File | Words | Note |
|---|---|---:|---|
| Our Pledge / Our Standards / Enforcement Responsibilities / Scope / Enforcement / Attribution | `CODE_OF_CONDUCT.md` | 313 | **Do not hand-translate.** It is the Contributor Covenant, which has an official Mongolian translation — use that rather than writing a second, divergent wording of a document whose exact phrasing is the point. |

That is the only entirely-English file in this repo.

---

## Closed 2026-09-30 — the README's two halves are now symmetric

`scripts/check-readme-parity.py` held an `EN_ONLY_SECTIONS` allowlist naming
five sections that existed only in English, roughly 950 words. All five are now
written and the allowlist is **empty**, so nothing is discounted and the parity
check watches the whole file.

| Section | Written as |
|---|---|
| Pipeline this repo demonstrates | Энэ repo-гийн харуулдаг pipeline — diagram included, with its two prose labels in Mongolian |
| Full run (real scanners, local — no cluster) | Бүтэн ажиллалт (бодит scanner, локал — cluster хэрэггүй) |
| Live cluster (Kind) | Амьд cluster (Kind) |
| Notes | Тэмдэглэл |
| License | Лиценз |

`EN_ONLY_CODE_BLOCKS` dropped from 5 to **1**. The one left is the `Expected:`
sample of `verify-lab` output under the 30-second demo: it is generated into the
English half by `scripts/sync-readme-counts.sh`, which has no Mongolian marker,
and the engine prints that table in whichever language it was asked for. A
second copy would be a hand-maintained duplicate of generated text.

**`License` was a judgement call**, and the answer was to write it. The section
is one line (`Apache-2.0`), the licence text itself is English regardless, and
`LICENSE` is the authority either way — so the Mongolian adds no information.
It was written anyway for two reasons: a reader who reaches the bottom of the
Mongolian half otherwise finds no licence statement at all, and leaving one name
on the allowlist keeps one section permanently outside the parity check. An
empty allowlist has no blind spot; a one-entry allowlist has one.

The set and the constant both stay in the script. They are the honest place to
record the next such decision, and the script already fails loudly when an entry
names a section that no longer exists, so a stale allowlist cannot mask drift.

## If you translate one thing

Nothing in this repo is urgent — `CODE_OF_CONDUCT.md` above is the only file
left, and it wants the official Contributor Covenant translation rather than a
new one. It is a fixture corpus for Tatar-Kuber, read by maintainers rather than
operators; put the time into Tatar-Shield's issue templates or Tatar-Relay's
Burp inject guide first.
