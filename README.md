# TATAR-Kuber Lab

Reproducible **vulnerable** and **hardened** Kubernetes manifests for testing, demoing
and benchmarking [TATAR-Kuber](https://github.com/ochmunkh/tatar-kuber).

- `broken/` — intentionally violates security controls
- `fixed/` — hardened equivalents (should produce no container findings)
- `raw/` — real scanner output (Checkov) so you can try the pipeline **offline**
- `expected-findings.json` — regression baseline for `tatar-kuber verify-lab`

## 30-second demo (no scanner install)

```bash
go install github.com/ochmunkh/tatar-kuber/cmd/tatar-kuber@latest
git clone https://github.com/ochmunkh/tatar-kuber-lab && cd tatar-kuber-lab

# engine ships the canonical registry; point --registry at it (or $TATAR_REGISTRY)
tatar-kuber scan --raw-dir raw --registry <engine>/schema/canonical-controls.yaml -o out
tatar-kuber report --input out/scan-result.json -o html --out out/report.html
tatar-kuber verify-lab --input out/scan-result.json --expected expected-findings.json
```

## Full run (real scanners, local — no cluster)

```bash
checkov -d broken --framework kubernetes -o json > raw/checkov.json
trivy   config broken --format json               > raw/trivy.json
tatar-kuber scan --raw-dir raw -o out
```

## Live cluster (Kind)

```bash
kind create cluster
kubectl create namespace production
kubectl apply -f broken/
# collect scanner output → tatar-kuber scan
```

## Broken → expected canonical controls

| File | Expected TATAR controls | Detected by |
|---|---|---|
| `privileged.yaml` | CON-001 | Trivy · Kubescape · Checkov |
| `root-user.yaml` | CON-002, CON-003 | Checkov · Trivy · Kubescape |
| `latest-tag.yaml` | IMG-003, CON-010, OPS-001/002/005 | Checkov · Trivy |
| `wildcard-rbac.yaml` | RBAC-002 | Checkov · Kubescape |
| `secret-env.yaml` | SEC-001 | **Trivy secret** (Checkov CKV_K8S_35 does not fire on plaintext) |
| `host-namespaces.yaml` | CON-005, CON-006 | Checkov · Trivy · Kubescape |
| _(missing NetworkPolicy)_ | NET-001/002 | **Kubescape / live cluster** |

## Why this lab

1. **Demo** — clone, scan, done in a minute.
2. **Regression** — `verify-lab` fails loudly if a release drops an expected control
   (e.g. dedup regression: 14 controls → 8).
3. **CI** — `.github/workflows/lab.yml` builds the engine and verifies on every push.
4. **Benchmark** — a shared, honest corpus to compare Trivy vs Kubescape vs Checkov vs
   the unified TATAR view.

## Validated

Real **Checkov 3.3.8** over `broken/` produces `CKV_K8S_16/17/19/20/22/23/31/43/49/8/9/10/11/15/38`,
which TATAR-Kuber unifies into **14 canonical controls** (`expected-findings.json`).

> Scanner rule IDs are PROVISIONAL — this lab is the regression harness that keeps them honest.

## License

Apache-2.0
