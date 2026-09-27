#requires -Version 7.4
[CmdletBinding()]
param([string]$ConfigPath = '.local/lab-config.json', [switch]$Execute,
      [switch]$SkipSecretTests, [string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$config = Get-LabConfiguration $ConfigPath
if (-not $Execute) { Write-Output 'Preview: private DNS, Blob and optional Key Vault probes from this host. Use -Execute on your authorized private-connected Windows host.'; return }
Assert-LabOperator $config
$checks = Assert-LabPrivateDns $config
Invoke-LabNative az @('storage','blob','list','--account-name',$config.state_storage_account_name,'--container-name',$config.state_container_name,'--auth-mode','login','--num-results','1','--query','length(@)','--output','tsv','--only-show-errors') | Out-Null
$checks.blob_read = 'passed'
if (-not $SkipSecretTests) {
    if ($config.bootstrap_secret_write_enabled) { throw 'Disable bootstrap write, apply and export before testing the read-only operator role.' }
    Invoke-LabNative az @('keyvault','secret','show','--vault-name',$config.key_vault_name,'--name','lab-validation','--query','id','--output','tsv','--only-show-errors') | Out-Null
    $probeName = 'denied-write-' + [guid]::NewGuid().ToString('N')
    $probe = Invoke-LabNative az @('keyvault','secret','set','--vault-name',$config.key_vault_name,'--name',$probeName,'--value','synthetic-permission-probe','--output','none','--only-show-errors') -AllowedExitCodes @(0,1)
    if ($probe.ExitCode -eq 0) { throw "Unexpected write permission. Synthetic secret '$probeName' was created; investigate inherited roles and remove that exact test secret when finished." }
    if ($probe.Output -notmatch 'ForbiddenByRbac') { throw 'Secret write failed for a reason other than the expected RBAC denial; this is not a passing permission test.' }
    $checks.secret_read = 'passed'
    $checks.secret_write_rbac_denial = 'passed'
}
Write-LabEvidence -Path $EvidencePath -Evidence ([ordered]@{lab_id=$config.lab_id;subscription_id=$config.subscription_id;tenant_id=$config.tenant_id;operator_principal_id=$config.operator_principal_id;state_storage_account_name=$config.state_storage_account_name;state_container_name=$config.state_container_name;key_vault_name=$config.key_vault_name;timestamp_utc=[DateTime]::UtcNow.ToString('o');execution_context='operator-host';checks=$checks;mdp_job_tested=$false})
Write-Output 'Private data-path checks passed from this operator host. No MDP agent job was started or validated.'
