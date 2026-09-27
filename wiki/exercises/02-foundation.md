# 2 — Deploy foundation and inspect local state

[Previous](01-prerequisites.md) · [Index](README.md) · [Next](03-identity.md)

**Location:** operator workstation. **Cloud writes:** foundation resources.

## Objective

Deploy the shared infrastructure while preserving its independent local state and understanding what Terraform owns.

## Preconditions

Exercise 1 passes; the local inputs identify your disposable scope; temporary secret seeding is disabled.

## Steps

1. Generate a plan.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

2. Inspect the plan summary and intended resource/role scopes. Confirm one pool, the intended image/SKU, Firewall Standard, private target access, and an empty sample resource group. Do not publish a raw binary plan.
Use the same pinned Terraform 1.16.4 binary to inspect the saved plan locally:

~~~powershell
$previousTfDataDir = $env:TF_DATA_DIR
$env:TF_DATA_DIR = ".local/foundation/$labId/terraform-data"
try { terraform show ".local/foundation-$labId.tfplan" }
finally { $env:TF_DATA_DIR = $previousTfDataDir }
~~~

3. Apply the reviewed matching plan, then export nonsecret metadata.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Apply -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Export -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

4. Inspect state **addresses**, not raw values.

~~~powershell
$previousTfDataDir = $env:TF_DATA_DIR
$env:TF_DATA_DIR = ".local/foundation/$labId/terraform-data"
try { terraform state list "-state=.local/state/foundation-$labId.tfstate" }
finally { $env:TF_DATA_DIR = $previousTfDataDir }
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$c | Select-Object lab_id, foundation_resource_group_name, workload_resource_group_name, pool_name
az resource list --resource-group $c.foundation_resource_group_name --query '[].{name:name,type:type}' --output table
az resource list --resource-group $c.workload_resource_group_name --query 'length(@)' --output tsv
~~~

5. Check public access posture.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action ValidatePublicAccess -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

## Expected observations

The local state contains foundation addresses; the sample group is empty; Blob/Key Vault public network access remains disabled. No secret value was seeded and no private workload state operation was needed.

## Troubleshooting

A changed configuration invalidates a saved plan: re-plan and inspect it. If a resource fails, preserve state and inspect that operation; do not delete state and retry from scratch.

## Cleanup and evidence

Keep resources for the next exercise. Record resource names/types and the local state location. Create a verified recovery copy using the [exact local backup procedure](../../docs/runbooks/recovery.md#local-foundation-backup). If stopping now, use [Exercise 10](10-cleanup.md).
