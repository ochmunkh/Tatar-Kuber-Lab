# Contributing to TATAR-Kuber Lab

Thanks for helping improve the test lab! 🎉 This repo is the manifest corpus and regression
baseline for the [TATAR-Kuber](https://github.com/ochmunkh/Tatar-Kuber) engine.

## Ways to contribute

- **New broken/fixed manifests** — add a vulnerable manifest under `broken/` (and its hardened
  counterpart under `fixed/`) that exercises a control the lab doesn't cover yet.
- **New scenarios** — realistic multi-resource setups.
- **Better real scanner output** — regenerate `raw/*.json` with the **pinned** real tools
  (`./scripts/regen-raw.sh`) for exact parity.

## Workflow

`./run-lab.sh` does **not** regenerate `raw/` — it only reads it, then checks the result against
the committed baselines and exits non-zero on drift. Regenerating raw scanner output is a
separate, version-pinned step.

1. Add your manifest to `broken/`, **and** its hardened twin to `fixed/`
   (`broken/secret-env.yaml` → `fixed/secure-secret-env.yaml` shows the shape).
2. Regenerate the real Checkov output for both corpora, with the version pinned:
   ```bash
   ./scripts/regen-raw.sh          # honours raw/versions.json (checkov 3.3.8)
   ```
   It refuses to run an unpinned Checkov. If you genuinely mean to bump the scanner, use
   `ALLOW_VERSION_BUMP=1` and say so in the PR — the integers in `expected/` only mean
   something for one ruleset. This step is not optional: it also stamps `corpus_sha256` into
   `<raw dir>/versions.json`, and `run-lab.sh` step 0 fails when a corpus no longer matches the
   output committed for it. Skip it and the lab tells you, instead of quietly reporting counts
   for the manifests you replaced.
3. Run the lab and **read the diff before you touch any expectation**:
   ```bash
   ./run-lab.sh                    # drift → non-zero; details in .lab-out/baseline.diff
   ```
   A count or a finding that moved *without* a manifest or `raw/` change is not a new truth —
   it is a possible engine regression. Report it in
   [Tatar-Kuber](https://github.com/ochmunkh/Tatar-Kuber); do **not** absorb it into `expected/`.
4. Only once you can explain every line of that diff, adopt it:
   ```bash
   ./run-lab.sh --update-baseline  # rewrites normalized/tatar-findings.json
   git diff normalized/tatar-findings.json
   ```
   Then update `expected/expected-findings.json` (controls + counts), and
   `expected/expected-fixed.json` too if `fixed/` moved.
5. Regenerate the README numbers — never type them:
   ```bash
   ./scripts/sync-readme-counts.sh  # badge + BOTH language halves + the gate policy comment
   ```
   `./run-lab.sh` fails if you skip this. The numbers in both halves come from
   `expected/expected-findings.json` so they cannot drift apart — but any prose you write by
   hand still has to be added to **both** halves.
6. Confirm the whole lab is green, then open a PR describing the new manifest and which TATAR
   controls it should trigger:
   ```bash
   ./run-lab.sh                    # ends with "[lab] done" when every check passed
   ```

You need the `tatar-kuber` binary on PATH (`go install
github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest`, then add `$(go env GOPATH)/bin` to
PATH). `jq` is **optional** for `./run-lab.sh` — without it the run skips the README count check
(step 8), compares the baseline line by line rather than as canonical JSON, and prints a
`[lab] DEGRADED` summary saying so — but `./scripts/sync-readme-counts.sh` and
`./scripts/regen-raw.sh` do need it, so install it before you open a PR.
`expected/expected-findings.json` records which engine version this baseline is
valid for, and `run-lab.sh` checks that first — so an old engine reports itself instead of
looking like a lab bug.

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Engine code changes go to the
[Tatar-Kuber](https://github.com/ochmunkh/Tatar-Kuber) repo.

---

## Монгол

Туршилтын лабораторийг сайжруулахад баярлалаа! Шинэ **эмзэг manifest** (`broken/`) + hardened
хувилбар (`fixed/`) нэмэх, эсвэл бодит scanner гаралт шинэчлэх нь хамгийн энгийн хувь нэмэр.

`./run-lab.sh` нь `raw/`-г ДАХИН ҮҮСГЭДЭГГҮЙ — зөвхөн уншиж, гарсан үр дүнг commit хийсэн
baseline-уудтай тулгаж шалгаад, зөрөө гарвал non-zero кодоор унана. Raw гаралтыг дахин үүсгэх
нь тусдаа, хувилбар pin-тэй үйлдэл.

Ажлын урсгал:

1. `broken/`-д manifest нэмж, `fixed/`-д hardened хосыг нь **бас** нэмнэ
   (`broken/secret-env.yaml` → `fixed/secure-secret-env.yaml` хэлбэрийг харна уу).
2. `./scripts/regen-raw.sh` — pin (checkov 3.3.8)-ыг баримталж хоёр corpus-ийн бодит Checkov
   гаралтыг шинэчилнэ. Pin-гүй Checkov ажиллуулахаас татгалзана; scanner-ыг зориуд өөрчлөх бол
   `ALLOW_VERSION_BUMP=1` ба PR-д тайлбарлана. Энэ шатыг АЛГАСАЖ болохгүй: `corpus_sha256`-ыг
   `<raw dir>/versions.json`-д бас бичдэг бөгөөд corpus нь түүнд commit хийсэн гаралттай зөрвөл
   `run-lab.sh`-ийн 0-р шат унана. Алгасвал lab чимээгүй байлгүй, хуучин manifest-ийн тоог
   мэдэгдэлгүй харуулахын оронд шууд хэлнэ.
3. `./run-lab.sh` ажиллуулж, **юу ч шинэчлэхээсээ ӨМНӨ diff-ийг унш** (`.lab-out/baseline.diff`).
   Manifest эсвэл `raw/` хөдлөөгүй атлаа тоо өөрчлөгдвөл тэр нь ШИНЭ ҮНЭН биш, engine-ийн
   regression байж мэднэ: [Tatar-Kuber](https://github.com/ochmunkh/Tatar-Kuber)-т мэдэгдэх ба
   `expected/` руу шингээж болохгүй.
4. Diff-ийн мөр бүрийг тайлбарлаж чадсаны дараа л батална:
   `./run-lab.sh --update-baseline` → `git diff normalized/tatar-findings.json`-ыг УНШИНА →
   `expected/expected-findings.json` (мөн `fixed/` хөдөлсөн бол `expected/expected-fixed.json`).
5. README-гийн тоонуудыг гараар БИЧИХГҮЙ: `./scripts/sync-readme-counts.sh` (badge, хоёр хэлний
   хэсэг, gate бодлогын тайлбар). Алгасвал `./run-lab.sh` унана. Тоонууд нэг эх сурвалжаас
   гардаг тул зөрөхгүй — харин гараар бичсэн бусад текстийг ХОЁУЛАНД нь нэмэх шаардлагатай.
6. Бүх lab ногоон болсныг батлаад PR нээнэ.

Шаардлага: `tatar-kuber` binary PATH дээр байх. `jq` нь `./run-lab.sh`-д **сонголт**: байхгүй бол
README-гийн тоонуудын шалгалт (8-р шат) алгасагдаж, baseline-ыг мөр мөрөөр тулгаад `[lab] DEGRADED`
гэж мэдэгдэнэ — харин `./scripts/sync-readme-counts.sh` ба `./scripts/regen-raw.sh` нь `jq`
шаарддаг тул PR нээхээсээ өмнө суулгана уу. Baseline нь ямар engine хувилбарт
хүчинтэйг `expected/expected-findings.json` бүртгэдэг; `run-lab.sh` үүнийг хамгийн эхэнд
шалгадаг тул хуучин engine нь lab-ийн алдаа шиг харагдахгүй, өөрөө мэдэгдэнэ.
Engine-ий кодын өөрчлөлт нь Tatar-Kuber repo руу.
