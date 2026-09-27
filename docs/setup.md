# Operator setup

[Home](../README.md) · [Identity](identity.md) · [Private access](egress.md)

## 1. Prepare the scope and execution contexts

Use an Azure subscription and an existing Azure DevOps organization/project you are authorized to use. Pool creation needs the relevant project/pool administrator permissions. No job definition or service-connection configuration is included.

There are two normal execution locations and a separate public-network context for the negative endpoint test:

| Location | Operations |
| --- | --- |
| Operator workstation | Foundation management-plane preflight, plan, apply, export and destroy |
| Existing private-connected Windows host | Private DNS, Blob/Key Vault data-plane checks, sample workload and state lock tests |
| Public-network operator context | Same-operator authenticated public-endpoint denial test after fresh private positive evidence |

The private host is supplied by you. It needs a route and DNS path to the lab's private endpoints. Merely signing in to Azure or adding an RBAC assignment does not supply network connectivity. No validation VM or connectivity appliance is created by this lab.

## 2. Confirm prerequisites

- PowerShell 7.4+, Git, Azure CLI and Terraform **1.16.4**.
- For egress tests only: explicitly installed Azure CLI <code>azure-firewall</code> and <code>log-analytics</code> extensions; see [egress prerequisites](egress.md#optional-tool-prerequisites-for-the-egress-exercise).
- AzureRM **5.6.0**, as pinned by source/lockfiles.
- Region/service/image/SKU availability and quota for the pool.
- Operator rights to create foundation resources and scoped role assignments.
- A real <code>operator_principal_id</code> matching the identity you will use on the private host.
- Existing Azure DevOps organization/project and authorized pool administrators.
- DevOps infrastructure service-principal permissions on the delegated network.
- Nonoverlapping address space and a usable DNS path from the existing private host.

Managed DevOps Pools uses an exclusively delegated subnet, and its pool and VNet must share a region. See [Microsoft networking requirements](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-networking?view=azure-devops).

Complete the [prerequisite verification runbook](runbooks/prerequisites.md), including service-principal discovery and manual Azure/Azure DevOps permission checks. Automated preflight does not establish effective authorization.

## 3. Verify scope and configure inputs

~~~powershell
$PSVersionTable.PSVersion
az version
terraform version
az login
az account set --subscription '<subscription-guid>'
az account show --query '{subscription:id,tenant:tenantId,name:name}' --output table
az ad signed-in-user show --query id --output tsv
~~~

The last command returns the current user object ID for a user login. For another authorized identity, determine its principal object ID through the matching identity record instead of substituting a client/application ID.

~~~powershell
$labId = 'pbalab'
$subscriptionId = '<subscription-guid>'
New-Item -ItemType Directory -Force .local | Out-Null
Copy-Item terraform.tfvars.example .local/lab.tfvars
notepad .local/lab.tfvars
~~~

The helper automatically loads the tracked defaults in <code>environments/lab.tfvars</code>. Copy <code>terraform.tfvars.example</code> for your local overrides because it includes the required identity and project fields.

Set real values for subscription, tenant, lab ID, location, operator principal, organization/project, pool administrators and the verified DevOps infrastructure principal. Keep <code>enable_secret_seed = false</code> until the controlled seed exercise.

Never put a password, access token, PAT or secret value in Terraform variables.

## 4. Plan and deploy the foundation

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Preflight -LabId $labId -SubscriptionId $subscriptionId
./scripts/Invoke-Lab.ps1 -Action Preflight -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
# Review the plan and intended scopes before proceeding.
./scripts/Invoke-Lab.ps1 -Action Apply -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Export -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action ValidatePublicAccess -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

Live preflight checks regional pool availability, SKU restrictions and family quota as well as provider registration. Effective Azure deployment/RBAC and Azure DevOps permissions remain manual prerequisite checks; preserve their separate results.

Changing inputs or source invalidates the reviewed plan; generate a new plan. Use <code>-VarFile</code>/<code>-ConfigPath</code> explicitly for alternate local files.

## 5. Understand local artifacts

| File | Purpose |
| --- | --- |
| <code>.local/lab.tfvars</code> | Operator-specific inputs |
| <code>.local/state/foundation-&lt;lab-id&gt;.tfstate</code> | Independent foundation state |
| <code>.local/foundation-&lt;lab-id&gt;.tfplan</code> | Reviewed foundation plan |
| <code>.local/lab-config.json</code> | Nonsecret resource/identity contract |

Protect all of <code>.local/</code>. State and plans remain sensitive even though the export contains no credentials. Foundation state is not migrated into the private workload backend.

## 6. Prepare the existing private host

Place the reviewed source and the matching nonsecret export on that host using your approved transfer method. Do not copy foundation state unless intentionally transferring operator ownership with a protected backup.

Sign in as the configured operator, confirm tenant/subscription, and follow Exercises 5–9. All workload state actions happen through the private path. Public network access stays disabled throughout bootstrap and normal operation.

For the public-endpoint negative test, follow [the evidence-bound procedure](testing.md#external-public-endpoint-denial-test) after synthetic seeding and write revocation. A public-access setting check alone is configuration evidence.

## 7. Finish and verify

Follow [ordered cleanup](runbooks/cleanup.md). Retain foundation state until residual checks are complete. Update [validation status](validation-status.md) with observed evidence; do not label a private-host result as a pool-job validation.
