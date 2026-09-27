# Validation status

| Evidence class | Status |
| --- | --- |
| Offline validation | **PASSED — 2026-09-27** |
| Azure foundation / pool provisioning | **LIVE NOT RUN** |
| Existing private-host DNS and data-plane tests | **LIVE NOT RUN** |
| Secret seed and write-revocation tests | **LIVE NOT RUN** |
| Authenticated public-endpoint network denials | **LIVE NOT RUN** |
| Allowed/blocked egress with Firewall evidence | **LIVE NOT RUN** |
| Workload apply, no-op plan and lease conflict | **LIVE NOT RUN** |
| Live failure recovery and cleanup | **LIVE NOT RUN** |
| Actual Managed DevOps agent job | **OUT OF SCOPE — NOT RUN** |
| Repository publication | **PUBLIC — [GitHub repository](https://github.com/Jamonygr/azure-private-build-agents-lab)** |

The combined offline command completed successfully on Windows at **2026-09-27 10:14 UTC**, against the initial authored working tree before its local baseline commit. No Azure deployment, live probe or account change was performed. Update this record only with observed results.

Source validation does not establish Azure deployment success. A private-host check proves that host's path and operator access, not that a Managed DevOps agent has successfully executed a job.

## Offline evidence

| Check | Observed result |
| --- | --- |
| Terraform formatting | Passed recursively |
| Foundation initialization and validation | Passed without a backend |
| Workload initialization and validation | Passed without a backend |
| Mocked Terraform tests | **9 passed**: 7 foundation/module contracts and 2 workload tests |
| Windows PowerShell / Pester | **65 passed**, 0 failed, 0 skipped |
| Python validator behavior | **21 passed** |
| Conftest policy behavior | **19 passed**; positive fixture accepted and negative fixture rejected |
| TFLint | Passed |
| Trivy configuration scan | Passed for MEDIUM/HIGH/CRITICAL, with the three documented scoped exceptions |
| Gitleaks source scan | Passed; no leaks reported |
| Generated Terraform documentation | All 8 references match source |
| Markdown, local links, heading anchors and SVG accessibility | Passed |
| Curriculum / excluded automation files | Ten exercises present; no pipeline or workflow definitions |
| Workflow lint | Not applicable; no workflows included |
| Architecture diagrams | Six SVGs rendered and visually reviewed, including the documentation map |

The security scan uses the installed Trivy check bundle with updates disabled for the offline run. Its accepted exceptions are explained in [security exceptions](../SECURITY_EXCEPTIONS.md). Link validation covers repository-local links and anchors; it does not claim that every external URL was tested.

Provider locks contain verified Windows amd64 and Linux amd64 checksums for AzureRM 5.6.0. Tests were **executed on Windows**; Linux execution was not performed.

## Reproduce

Install the versions in <code>toolchain.json</code> deliberately and make the quality tools available on PATH. Use PowerShell 7.4 or newer:

~~~powershell
./scripts/offline-validation.ps1 -RequireAllTools -TerraformPath '<absolute-path-to-terraform-1.16.4-executable>'
~~~

Observed tools: PowerShell 7.6.6, Terraform 1.16.4, AzureRM 5.6.0, Pester 5.7.1, Python 3.8.10, TFLint 0.63.1, Trivy 0.72.0, Gitleaks 8.28.0, Conftest 0.68.2 and terraform-docs 0.24.0.

The command writes sanitized results to ignored <code>.local/evidence/offline-validation.json</code> and <code>.local/evidence/pester-summary.json</code>. A future run replaces these local summaries; retain the UTC time and source commit when collecting new evidence.

“Offline” means credential-free source validation with no Azure operations. A fresh machine may need network access to obtain the pinned provider and tool dependencies. Nothing in the validator deploys infrastructure or silently installs quality tools.

## Live acceptance

Follow [the live sequence](testing.md) on your own authorized subscription and existing private Windows host. Runtime image/tool versions, private/public data paths, role revocation, state locking, egress and resource cleanup remain **NOT RUN**. Actual Managed DevOps agent job execution is outside this operator-only delivery.

Never attach raw state, binary plans, access tokens or Key Vault values.
