# TATAR-Kuber Lab

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-security-326CE5?logo=kubernetes&logoColor=white)
![Scanners](https://img.shields.io/badge/scanners-Checkov%20%C2%B7%20Trivy%20%C2%B7%20Kubescape%20%C2%B7%20Popeye-2A4D69)
![Controls](https://img.shields.io/badge/expected-19%20canonical%20controls-1F6F54)
![MITRE](https://img.shields.io/badge/MITRE%20ATT%26CK-for%20Containers-4a2c6f)
![verify--lab](https://img.shields.io/badge/verify--lab-PASS-brightgreen)

Reproducible **vulnerable** and **hardened** Kubernetes manifests — the official test,
demo and regression corpus for the [**TATAR-Kuber**](https://github.com/ochmunkh/tatar-kuber)
security engine.

**Author:** Enkhbat.O — Security Analyst

> Two repositories, one product:
> - **[tatar-kuber](https://github.com/ochmunkh/tatar-kuber)** — the engine (scanner
>   orchestration, canonical mapping, dedup, risk, MITRE ATT&CK, reports).
> - **tatar-kuber-lab** (this repo) — the manifests + expected results that prove it works.
>
> The engine also ships a tiny `examples/demo` (a **different**, self-contained dataset for its
> own CI/Pages, story: privileged on `deployment/api`). This lab is the **full** corpus +
> `verify-lab` regression baseline — not a duplicate, a different scope.

Running the lab through TATAR-Kuber:

**🇬🇧 English report**

![TATAR-Kuber report — English](docs/img/report-en.jpg)

**🇲🇳 Монгол тайлан**

![TATAR-Kuber тайлан — Монгол](docs/img/report-mn.jpg)

## Pipeline this repo demonstrates

```
raw/                          normalized/                report
 ├─ checkov.json      ─┐       tatar-findings.json  ─►    report.html
 ├─ trivy.json        ─┤ ─►  (canonical + dedup +          (JSON / SARIF / HTML)
 ├─ kubescape.json    ─┤       risk + blind-shot)
 └─ popeye.json       ─┘             │
   (raw scanner output)              └─►  expected/expected-findings.json  (verify-lab)
```

- `broken/` — intentionally violates security controls
- `fixed/` — hardened equivalents (should produce no container findings)
- `raw/` — real/representative scanner output so you can run **offline** (no cluster, no install)
- `normalized/tatar-findings.json` — the unified TATAR output (raw → normalized)
- `expected/expected-findings.json` — regression baseline for `tatar-kuber verify-lab`

## 30-second demo (offline)

The canonical registry is **embedded in the binary** — no engine checkout needed.

```bash
go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
git clone https://github.com/ochmunkh/tatar-kuber-lab && cd tatar-kuber-lab
./run-lab.sh            # or: ./run-lab.sh mn   for a Mongolian report
```

`run-lab.sh` exercises the **full** feature set against this corpus:
`doctor` → `scan` (canonical + dedup + confidence + risk + **MITRE ATT&CK**) →
`report` (HTML · SARIF · JSON) → `gate` (policy [`.tatar-kuber.yaml`](.tatar-kuber.yaml)) →
`verify-lab` (regression baseline).

Expected:

```
verify-lab: offline multi-scanner (broken/): checkov + trivy + kubescape + popeye
  controls: expected 19, missing 0
  findings: actual 69
  CRITICAL  expected 1,  actual 1   [ok]
  HIGH      expected 16, actual 16  [ok]
  MEDIUM    expected 33, actual 33  [ok]
  LOW       expected 19, actual 19  [ok]
RESULT: PASS
```

## Full run (real scanners, local — no cluster)

Checkov and Trivy scan **manifest files** directly:

```bash
checkov -d broken --framework kubernetes -o json > raw/checkov.json
trivy   config broken --format json               > raw/trivy.json
./run-lab.sh          # regenerates + verifies
```

Popeye is runtime-only (needs a live cluster) — `raw/popeye.json` here is a representative sample.

## Live cluster (Kind)

```bash
kind create cluster && kubectl create namespace production
kubectl apply -f broken/
# collect scanner output → tatar-kuber scan
```

## Broken → expected canonical controls (19)

| File | Expected TATAR controls | Detected by |
|---|---|---|
| `privileged.yaml` | CON-001, NET-001 | Trivy · Kubescape · Checkov |
| `root-user.yaml` | CON-002, CON-003 | Checkov · Trivy · Kubescape |
| `latest-tag.yaml` | IMG-003, CON-010, OPS-001/002/005 | Checkov · Trivy · Popeye |
| `wildcard-rbac.yaml` | RBAC-001, RBAC-002, RBAC-003 | Checkov · Kubescape |
| `secret-env.yaml` | SEC-001 | **Trivy secret** (Checkov misses plaintext) |
| `host-namespaces.yaml` | CON-005, CON-006 | Checkov · Trivy · Kubescape |
| _(hardening gaps)_ | CON-004, CON-008, CON-009, CON-011, SEC-003 | Checkov |

Multi-scanner wins: `SEC-001` (Trivy secret) and `NET-001` (Kubescape) are **missed by
Checkov alone** — the unified TATAR view catches them. `CON-001` privileged is found by
**all three static scanners** → `found_by=[checkov,kubescape,trivy]`, `confidence=HIGH`.

`wildcard-rbac.yaml` also shows why mapping precision matters: Checkov's `CKV_K8S_49`
(wildcard verbs) and Kubescape's `C-0272` (administrative roles) are **different findings on the
same ClusterRole** — RBAC-002 (HIGH) and RBAC-001 (CRITICAL). Until the v1.0.2 mapping audit,
`C-0272` was mis-mapped onto "wildcard permissions" and the two collapsed into one.

> `raw/popeye.json` deliberately uses Popeye's **legacy `sanitizers` schema** (<= 0.21, matching
> `raw/versions.json`). Popeye 0.22 renamed it to `sections`; keeping the old shape here proves
> tatar-kuber still reads both.

## Why this lab

1. **Demo** — clone, scan, done in a minute (no cluster).
2. **Regression** — `verify-lab` fails loudly if a release drops an expected control or
   changes counts (e.g. dedup regression: 19 controls → 8).
3. **CI** — `.github/workflows/lab.yml` builds the engine and verifies on every push.
4. **Benchmark** — a shared, honest corpus to compare Trivy vs Kubescape vs Checkov vs
   the unified TATAR view.

## Notes

`raw/checkov.json` is **real Checkov 3.3.8** output. `trivy.json` / `kubescape.json` /
`popeye.json` are representative samples matching the manifests — regenerate with the real
tools for exact parity. Scanner rule IDs are PROVISIONAL; this lab keeps them honest.

## License

Apache-2.0

---

## Монгол хэл дээр

[**TATAR-Kuber**](https://github.com/ochmunkh/tatar-kuber) engine-ийг турших, demo хийх,
regression шалгах зориулалттай **эмзэг** ба **hardened** Kubernetes manifest-ийн цуглуулга.

- `broken/` — аюулгүй байдлын control-уудыг зориудаар зөрчсөн
- `fixed/` — hardening зөв хийсэн хувилбарууд
- `raw/` — бодит/төлөөлөх scanner гаралт (checkov бодит; trivy/kubescape/popeye жишээ) —
  cluster эсвэл суулгацгүйгээр **offline** ажиллуулах боломжтой
- `normalized/tatar-findings.json` — TATAR-ийн нэгтгэсэн гаралт (raw → normalized)
- `expected/expected-findings.json` — `tatar-kuber verify-lab`-ийн regression baseline

### 30 секундийн demo (offline)

Canonical registry нь binary дотор **шигтгэсэн** тул engine-ийг clone хийх шаардлагагүй.

```bash
go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
git clone https://github.com/ochmunkh/tatar-kuber-lab && cd tatar-kuber-lab
./run-lab.sh mn         # монгол тайлан
```

`run-lab.sh` нь энэ corpus дээр **бүх** боломжийг ажиллуулна:
`doctor` → `scan` (canonical + dedup + confidence + risk + **MITRE ATT&CK**) →
`report` (HTML · SARIF · JSON) → `gate` (бодлого [`.tatar-kuber.yaml`](.tatar-kuber.yaml)) →
`verify-lab` (regression baseline).

### Эмзэг manifest → хүлээгдэх canonical control (19)

| Файл | Хүлээгдэх TATAR control | Илрүүлэгч |
|---|---|---|
| `privileged.yaml` | CON-001, NET-001 | Trivy · Kubescape · Checkov |
| `root-user.yaml` | CON-002, CON-003 | Checkov · Trivy · Kubescape |
| `latest-tag.yaml` | IMG-003, CON-010, OPS-001/002/005 | Checkov · Trivy · Popeye |
| `wildcard-rbac.yaml` | RBAC-001, RBAC-002, RBAC-003 | Checkov · Kubescape |
| `secret-env.yaml` | SEC-001 | **Trivy secret** (Checkov plaintext-ыг барихгүй) |
| `host-namespaces.yaml` | CON-005, CON-006 | Checkov · Trivy · Kubescape |
| _(hardening дутуу)_ | CON-004, CON-008, CON-009, CON-011, SEC-003 | Checkov |

`wildcard-rbac.yaml` нь зураглалын нарийвчлал яагаад чухал болохыг бас харуулна: Checkov-ийн
`CKV_K8S_49` (wildcard verb) ба Kubescape-ийн `C-0272` (administrative roles) нь **нэг ClusterRole
дээрх ӨӨР ХОЁР finding** — RBAC-002 (HIGH) ба RBAC-001 (CRITICAL). v1.0.2-ын зураглалын аудит
хүртэл `C-0272` нь "wildcard permissions" руу буруу зурагдаж, хоёр нь нэг болж нийлж байв.

> `raw/popeye.json` нь ЗОРИУДААР Popeye-ийн **legacy `sanitizers` схемтэй** (<= 0.21,
> `raw/versions.json`-той нийцсэн). Popeye 0.22 түүнийг `sections` болгож сольсон; хуучин
> хэлбэрийг энд үлдээснээр tatar-kuber хоёуланг уншиж чадахыг батална.

**Multi-scanner давуу тал:** `SEC-001` (Trivy secret) ба `NET-001` (Kubescape)-ыг **Checkov
ганцаараа алддаг** — нэгтгэсэн TATAR харагдац барьдаг. `CON-001` privileged-ыг **гурван
static scanner** олдог → `found_by=[checkov,kubescape,trivy]`, `confidence=HIGH`.

### Яагаад хэрэгтэй вэ

1. **Demo** — clone хийгээд, scan хийж, нэг минутад дуусна (cluster хэрэггүй).
2. **Regression** — `verify-lab` нь хүлээгдсэн control алга болох, эсвэл тоо өөрчлөгдвөл
   шууд FAIL болно (ж: dedup эвдэрч 16 control → 8).
3. **CI** — push бүрт engine-ийг build хийж баталгаажуулна.
4. **Benchmark** — Trivy vs Kubescape vs Checkov vs нэгтгэсэн TATAR-ийг харьцуулах нийтлэг суурь.

**Зохиогч:** Enkhbat.O — Security Analyst
