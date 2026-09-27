# 1 — Prerequisites, permissions and cost

[Exercise index](README.md) · [Next](02-foundation.md)

**Location:** operator workstation. **Cloud writes:** none.

## Objective

Explain the architecture, identify the actual operator scope, and establish whether you have the prerequisites for a meaningful live session.

## Steps

1. Read [architecture](../architecture/overview.md) and [costs](../../docs/costs.md). Identify the foundation, sample workload, private services and existing validation host.
2. Verify the local toolchain.

~~~powershell
$PSVersionTable.PSVersion
git --version
terraform version
az version
~~~

3. Confirm the intended subscription and tenant. Sign in only to an account authorized for this lab.

~~~powershell
az login
az account set --subscription $subscriptionId
az account show --query '{subscription:id,tenant:tenantId,name:name}' --output table
az ad signed-in-user show --query id --output tsv
~~~

4. Complete the [prerequisite verification runbook](../../docs/runbooks/prerequisites.md). Discover the exact service-principal record and manually verify effective Azure and DevOps permissions. Then create the local input file and set the IDs documented in [setup](../../docs/setup.md).

~~~powershell
New-Item -ItemType Directory -Force .local | Out-Null
Copy-Item terraform.tfvars.example .local/lab.tfvars
notepad .local/lab.tfvars
./scripts/Invoke-Lab.ps1 -Action Preflight -LabId $labId -SubscriptionId $subscriptionId
~~~

5. Run offline validation, then a live read-only preflight.

~~~powershell
./scripts/offline-validation.ps1 -RequireAllTools
./scripts/Invoke-Lab.ps1 -Action Preflight -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

6. Record how the existing Windows host will reach the private endpoints. For later Firewall testing, separately record how its outbound traffic will traverse this Firewall.

## Expected observations

PowerShell is at least 7.4 and Terraform is 1.16.4; your IDs match the configuration; prerequisites are either verified or explicitly unresolved. Live preflight checks provider registration, region, SKU and family quota. It labels effective deployment/RBAC and Azure DevOps permissions NOT_RUN; record the separate manual results. An offline preview is not a live preflight. A quota/service permission failure blocks provisioning until corrected.

Create a current cost estimate using the selected region and anticipated session length. Record the Firewall as an idle cost driver.

## Troubleshooting

A user object ID differs from an application/client ID. If using a non-user identity, inspect its principal record. If private host connectivity is unavailable, complete source/control-plane study but mark private-host exercises not run.

## Cleanup and evidence

No Azure resources were created. Keep sanitized tool/scope results and the cost assumptions; do not record credentials.
