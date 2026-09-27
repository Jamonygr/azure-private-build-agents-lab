# 10 — Workload, foundation and residual cleanup

[Previous](09-recovery-locking.md) · [Index](README.md) · [Runbook](../../docs/runbooks/cleanup.md)

**Location:** private host first, foundation workstation second. **Cloud writes:** deletion of the disposable lab.

## Objective

Remove resources in dependency order and retain enough evidence to know when cleanup is actually complete.

## Steps

1. Stop other Terraform operations. Confirm the lab ID/subscription and preserve the foundation state/export.
2. On the private host, destroy the sample using its private backend.

~~~powershell
./scripts/Invoke-Workload.ps1 -Action Destroy -ConfigPath .local/lab-config.json -LabId $labId -SubscriptionId $subscriptionId -Execute -Confirmation "DESTROY $labId"
~~~

The destroy helper verifies empty workload state and an empty sample resource group. Its Verify action is for deployed convergence, so do not run Verify after destruction.

3. Independently inspect the group.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
az resource list --resource-group $c.workload_resource_group_name --query 'length(@)' --output tsv
~~~

4. On the foundation workstation, remove the foundation and verify residuals.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Destroy -LabId $labId -SubscriptionId $subscriptionId -Execute -Confirmation "DESTROY $labId"
./scripts/Invoke-Lab.ps1 -Action VerifyCleanup -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

5. Read both ACTIVE RESOURCES and SOFT-DELETED VAULT output. The exact retained vault record includes deletion/scheduled-purge dates, or reports no record. A failed query is incomplete verification; the helper never purges. Review retained records using exact IDs. Do not purge or remove a similarly named unrelated resource.
6. Record cleanup time and check Azure cost reporting later.

## Expected observations

The sample group becomes empty before foundation teardown. Foundation residual checks complete without unexpected active lab resources. Any intended retention is explicitly recorded. The external validation host remains outside Terraform ownership.

## Troubleshooting

A nonempty sample group blocks foundation teardown. Recover the private path and workload state instead of deleting the backend. A managed service association can take time to disappear; inspect its status and retry only after understanding the dependency.

## Final evidence

Record command/commit/time, empty sample group, foundation cleanup results, retained items, and unresolved failures. Keep protected recovery state until absence is established. Update [validation status](../../docs/validation-status.md).
