# 9 — DNS/RBAC recovery and deterministic state locking

[Previous](08-egress.md) · [Index](README.md) · [Next](10-cleanup.md)

**Location:** private host and foundation workstation. **Cloud writes:** one reversible lab read-role removal and Terraform restoration; bounded lease operations.

## Objective

Create a known failure, observe the correct layer, restore it, and prove backend locking without racing full applies.

## A. Isolated DNS failure

On the private host, deliberately send a single query to a reserved documentation address used here as a nonworking resolver. This does not change NIC settings.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$blobHost = "$($c.state_storage_account_name).blob.core.windows.net"
$dnsFailed = $false
try {
    Resolve-DnsName $blobHost -Server 192.0.2.53 -DnsOnly -QuickTimeout -ErrorAction Stop
} catch {
    $dnsFailed = $true
    Write-Host $_.Exception.Message
}
if (-not $dnsFailed) { throw 'Unexpected answer: choose an approved isolated nonworking test resolver.' }
Resolve-DnsName $blobHost -Type A
~~~

Expected: the deliberately wrong resolver fails; the normal approved path returns the private endpoint. Inspect the actual error, not merely whether the catch block ran.

## B. Controlled Key Vault read-role failure

Do this only in the disposable lab, with recovery rights on the foundation workstation, no concurrent use, and no inherited secret-read/write permission that defeats the test.

1. On the foundation workstation, identify exactly one direct role assignment.

~~~powershell
$c = Get-Content .local/lab-config.json -Raw | ConvertFrom-Json
$kvId = az keyvault show --name $c.key_vault_name --query id --output tsv
$roles = @(az role assignment list --assignee $c.operator_principal_id --scope $kvId --role 'Key Vault Secrets User' --output json | ConvertFrom-Json)
$direct = @($roles | Where-Object { $_.scope -eq $kvId })
if ($direct.Count -ne 1) { throw 'Expected exactly one direct lab read-role assignment.' }
$direct | Select-Object id, principalId, roleDefinitionName, scope
~~~

2. Verify the displayed lab scope, then remove only that assignment.

~~~powershell
az role assignment delete --ids $direct[0].id
~~~

3. On the private host, rerun private access after bounded propagation. Expect secret read failure while DNS/transport still work.

~~~powershell
./scripts/Test-LabPrivateAccess.ps1 -ConfigPath .local/lab-config.json -Execute
~~~

4. **Always restore through Terraform**, even if the negative test was inconclusive.

~~~powershell
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
./scripts/Invoke-Lab.ps1 -Action Apply -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

5. Rerun the private-host check and verify successful read plus denied write. If you cannot perform a controlled role removal safely, skip it and record why.

## C. Deterministic lease test

Ensure no other workload operation is active. The lock test uses a disposable key under <code>tests/locks/&lt;lab-id&gt;/&lt;run-id&gt;.tfstate</code>, not the sample state key. Its empty test blob can remain until foundation cleanup; the helper never force-unlocks production state.

~~~powershell
./scripts/Test-LabStateLock.ps1 -ConfigPath .local/lab-config.json -Execute
./scripts/Invoke-Workload.ps1 -Action Verify -ConfigPath .local/lab-config.json -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

Expected: the helper owns a known lease, the competing Terraform operation fails to acquire it, the helper releases its lease, and normal no-op verification succeeds.

## Troubleshooting and cleanup

Never force-unlock an unknown operation. If interrupted, use [recovery](../../docs/runbooks/recovery.md) to inspect/release only your test lease. Restore the removed read role and prove the normal path before leaving this exercise.
