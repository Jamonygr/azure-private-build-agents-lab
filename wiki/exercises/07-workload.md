# 7 — Private backend, sample apply and no-op verification

[Previous](06-secret-seed.md) · [Index](README.md) · [Next](08-egress.md)

**Location:** existing private Windows host. **Cloud writes:** sample network resources and private state.

## Objective

Use Azure CLI / Microsoft Entra authentication to operate the independent workload root without storage keys or a public network exception.

## Steps

1. Confirm the sample group already exists and inspect current contents.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
az resource list --resource-group $c.workload_resource_group_name --query '[].{name:name,type:type}' --output table
~~~

2. Create a plan through the helper.

~~~powershell
./scripts/Invoke-Workload.ps1 -Action Plan -ConfigPath .local/lab-config.json -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

3. Inspect the proposed VNet/subnet/NSG resources, resource-group target and private backend. The helper stores its plan and metadata under <code>.local/workload/&lt;lab-id&gt;/</code>; keep them private.
4. Apply only the matching reviewed plan.

~~~powershell
./scripts/Invoke-Workload.ps1 -Action Apply -ConfigPath .local/lab-config.json -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

5. Verify deployed convergence.

~~~powershell
./scripts/Invoke-Workload.ps1 -Action Verify -ConfigPath .local/lab-config.json -LabId $labId -SubscriptionId $subscriptionId -Execute
az resource list --resource-group $c.workload_resource_group_name --query '[].{name:name,type:type}' --output table
~~~

## Expected observations

The helper initializes private Blob state using the signed-in operator, applies the small sample and then obtains a no-change plan. Outputs identify the sample VNet, subnet and NSG.

Verify means **deployed and converged**. It is not the cleanup check to run after destroy.

## Troubleshooting

A private backend timeout first requires DNS/route inspection. An authorization error needs container data-role inspection. A changed source/config/lockfile/commit invalidates a reviewed plan; regenerate it. Do not add resource-group creation permissions to work around incorrect workload ownership.

## Cleanup and evidence

Keep the sample for the lease exercise. Retain plan/apply summaries and a no-op result; never publish the binary plan or state.
