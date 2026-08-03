# Contributing to TATAR-Kuber Lab

Thanks for helping improve the test lab! 🎉 This repo is the manifest corpus and regression
baseline for the [TATAR-Kuber](https://github.com/ochmunkh/Tatar-Kuber) engine.

## Ways to contribute

- **New broken/fixed manifests** — add a vulnerable manifest under `broken/` (and its hardened
  counterpart under `fixed/`) that exercises a control the lab doesn't cover yet.
- **New scenarios** — realistic multi-resource setups.
- **Better real scanner output** — regenerate `raw/*.json` with real tools for exact parity.

## Workflow

1. Add your manifest to `broken/` (and ideally a `fixed/` version).
2. Regenerate the offline raw + normalized output and update the baseline:
   ```bash
   ./run-lab.sh
   ```
3. Update `expected/expected-findings.json` (controls + counts) to match the new baseline.
4. Confirm it passes:
   ```bash
   tatar-kuber verify-lab \
     --input normalized/tatar-findings.json \
     --expected expected/expected-findings.json     # RESULT: PASS
   ```
5. Open a PR describing the new manifest and which TATAR controls it should trigger.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Engine code changes go to the
[Tatar-Kuber](https://github.com/ochmunkh/Tatar-Kuber) repo.

---

## Монгол

Туршилтын лабораторийг сайжруулахад баярлалаа! Шинэ **эмзэг manifest** (`broken/`) + hardened
хувилбар (`fixed/`) нэмэх, эсвэл бодит scanner гаралт шинэчлэх нь хамгийн энгийн хувь нэмэр.

Ажлын урсгал: manifest нэмэх → `./run-lab.sh` → `expected/expected-findings.json`-ыг
шинэчлэх → `verify-lab` PASS → PR. Engine-ий кодын өөрчлөлт нь Tatar-Kuber repo руу.
