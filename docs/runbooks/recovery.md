# Recovery without weakening the boundary

[Home](../../README.md) · [Troubleshooting](../troubleshooting.md)

## Foundation interrupted

1. Confirm tenant/subscription and local state path.
2. Preserve a protected copy of the current state before troubleshooting.
3. Inspect the precise failed Azure resource operation.
4. Resolve the prerequisite or transient dependency.
5. Generate a new plan and inspect reconciliation with the recorded state.
6. Apply only the reviewed plan.

Never delete the local state to “start fresh” while owned resources remain.

## Private DNS failure

1. Record the queried hostname, returned addresses and configured resolver.
2. Compare with <code>blob_private_ip</code>/<code>vault_private_ip</code>.
3. Inspect zone links and endpoint DNS records.
4. Inspect the host's resolver and route to the lab DNS path.
5. Repair one configuration error and rerun the same query/TLS test.

Do not change public network access as a DNS repair.

## RBAC failure

1. Record the exact principal, operation and scope.
2. Inspect inherited and directly assigned roles.
3. Compare the expected data-plane role with management-plane roles.
4. Correct only the intended assignment through foundation inputs.
5. Allow bounded propagation; obtain a fresh authorized session if needed.
6. Rerun the original positive/negative test.

## Public endpoint negative test is inconclusive

Regenerate private evidence with both Blob and secret reads after restoring DNS/RBAC. It must bind the same lab, resources and operator and be at most 24 hours old. On the public context, verify public-only DNS and the same authenticated operator. Timeout, stale evidence, generic authentication failure or unrelated role denial must remain incomplete; only the helper-checked service network-denial codes establish the intended result.

## Known test lease interrupted

The state-lock exercise owns a specific bounded test lease. The lock test uses a disposable key under <code>tests/locks/&lt;lab-id&gt;/&lt;run-id&gt;.tfstate</code>, not the sample state key. Its empty test blob can remain until foundation cleanup; the helper never force-unlocks production state. Inspect that lease and running Terraform processes. Release only a lease proven to belong to your interrupted test. Never force-unlock an unknown active operation.

Repeat the normal no-op plan after recovery to prove backend availability.

## Lost private-host access

Keep the foundation and its state intact. Recover the approved host/network path before workload cleanup. Removing the private backend while the sample exists makes recovery harder and can leave unmanaged resources.


## Local foundation backup

Run from the repository root **after stopping all concurrent Terraform operations**. This copies only the exact foundation state and matching export into the already ignored local area; it does not upload data or replace the active state.

~~~powershell
$statePath = ".local/state/foundation-$labId.tfstate"
$exportPath = '.local/lab-config.json'
foreach ($path in @($statePath, $exportPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required backup source is missing: $path"
    }
}
$backupConfig = Get-Content -LiteralPath $exportPath -Raw | ConvertFrom-Json
if ($backupConfig.lab_id -ne $labId -or $backupConfig.subscription_id -ne $subscriptionId) {
    throw 'Backup configuration does not match the requested lab and subscription.'
}
$backupStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backupDirectory = Join-Path ".local/backups/$labId" $backupStamp
New-Item -ItemType Directory -Path $backupDirectory | Out-Null
$stateCopy = Join-Path $backupDirectory "foundation-$labId.tfstate"
$exportCopy = Join-Path $backupDirectory 'lab-config.json'
Copy-Item -LiteralPath $statePath -Destination $stateCopy
Copy-Item -LiteralPath $exportPath -Destination $exportCopy
foreach ($pair in @(@($statePath,$stateCopy),@($exportPath,$exportCopy))) {
    if (-not (Test-Path -LiteralPath $pair[1] -PathType Leaf) -or
        (Get-FileHash -LiteralPath $pair[0]).Hash -ne (Get-FileHash -LiteralPath $pair[1]).Hash) {
        throw 'Backup copy verification failed.'
    }
}
Write-Host "Protected local backup copy created: $backupDirectory"
~~~

This is a local recovery copy, not protection against losing the workstation. Apply approved encryption/access controls and any approved external backup process yourself. Never commit these files or put them in a public artifact.

## Restore a specifically verified foundation backup

Stop concurrent operations. Select one **exact** backup directory and inspect its nonsecret lab/subscription metadata and state lineage before overwriting active state. If the active state exists, compare lineage; different lineages mean stop and investigate. Also compare serial/history and known operations—matching lineage alone does not make an old snapshot current.

~~~powershell
$statePath = ".local/state/foundation-$labId.tfstate"
$backupDirectory = ".local/backups/$labId/<exact-UTC-backup-directory>"
$restoreConfig = Get-Content -LiteralPath (Join-Path $backupDirectory 'lab-config.json') -Raw | ConvertFrom-Json
$restoreStatePath = Join-Path $backupDirectory "foundation-$labId.tfstate"
$restoreState = Get-Content -LiteralPath $restoreStatePath -Raw | ConvertFrom-Json
if ($restoreConfig.lab_id -ne $labId -or $restoreConfig.subscription_id -ne $subscriptionId) {
    throw 'Backup target mismatch.'
}
$restoreState | Select-Object lineage, serial, terraform_version
if (Test-Path -LiteralPath $statePath) {
    $activeState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($activeState.lineage -ne $restoreState.lineage) { throw 'State lineage differs; stop.' }
    $activeState | Select-Object lineage, serial, terraform_version
}
~~~

Before restoring, preserve the current active copy in a separate verified timestamped backup where available. After confirming exact lab/subscription, lineage and operation history, copy the selected files:

~~~powershell
Copy-Item -LiteralPath $restoreStatePath -Destination $statePath
Copy-Item -LiteralPath (Join-Path $backupDirectory 'lab-config.json') -Destination '.local/lab-config.json'
./scripts/Invoke-Lab.ps1 -Action Plan -LabId $labId -SubscriptionId $subscriptionId -Execute
~~~

Inspect reconciliation before apply. Do not run a blind state push, choose the newest file by name alone, or apply an old state snapshot when newer Azure changes are unaccounted for. Recovering a missing active state requires independently verified lineage/ownership from the backup record and known deployment history.

## Lost local foundation state

Recover a protected copy and reconcile exact Azure IDs before any destructive action. Stop if ownership is uncertain. Do not import or delete by guessed names.
