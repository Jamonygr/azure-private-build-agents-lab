# Deliberate lab choices and security exceptions

Reviewed for the initial operator-driven design on **2026-09-27**. These are explicit learning boundaries, not blanket scanner suppressions.

| Choice | Reason | Compensating practice |
| --- | --- | --- |
| Local foundation state | Independent bootstrap/recovery path | Ignore in Git; protect workstation and backups; separate lab-specific state |
| Existing private host supplied by operator | Avoid adding unrelated VM/connectivity scope | Confirm identity, DNS/route path and host ownership before tests |
| One maximum agent / no standby | Compact lab footprint | Do not claim production capacity or availability |
| Temporary secret-writing role | Seed one synthetic value without Terraform secret state | Explicit enable flag, deliberate seed, immediate removal and negative test |
| Manual operations | Requested version scope | Explicit execution, matching scope and reviewed-plan guards |
| No actual pool-job validation | No build/deployment flow in version 1 | Label private-host and control-plane evidence precisely |
| Lab-sized monitoring | Limit learning footprint | Record evidence gaps; do not claim complete operational coverage |

Public target exposure, permanent secret write and unscoped role escalation are **not** accepted exceptions.

Any future scanner exception must identify the exact check/resource, justification, compensating control, owner and review date. Do not add global skips.

## Scoped Trivy findings

Only these three scanner exceptions are accepted. All are restricted to **modules/private-services/main.tf**, reviewed **2026-09-27**; the matching configuration is recorded in the root Trivy ignore file.

| Check | Finding and rationale | Compensating control |
| --- | --- | --- |
| AZU-0010 | Trusted-services bypass is absent intentionally; enabling a bypass would broaden the private-only policy | Bypass None, public network access disabled, approved private endpoints |
| AZU-0057 | Legacy Storage logging is not configured because service diagnostics use Azure Monitor | Blob diagnostic allLogs and Transaction metrics route to the lab Log Analytics workspace |
| AZU-0060 | Customer-managed keys are outside this lab's scope to avoid a separate key-lifecycle dependency | Azure-managed encryption at rest and infrastructure encryption enabled |

Re-evaluate these exact configurations when changing storage, diagnostics, encryption or network access. No other scanner findings are covered by this section.