#requires -Version 7.4
[CmdletBinding()]
param([string]$ConfigPath = '.local/lab-config.json',[string]$PrivateEvidencePath,
      [switch]$Execute,[string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$config = Get-LabConfiguration $ConfigPath
if (-not $Execute) { Write-Output 'Preview: same-operator authenticated Blob and Key Vault network-denial probes from a public-network host. Requires private positive evidence from the last 24 hours.'; return }
if (-not $PrivateEvidencePath) { throw 'Supply -PrivateEvidencePath from Test-LabPrivateAccess with both Blob and secret reads passed in the last 24 hours.' }
$privateEvidence = Get-Content -LiteralPath $PrivateEvidencePath -Raw | ConvertFrom-Json
Assert-LabPrivateEvidence -Configuration $config -Evidence $privateEvidence
Assert-LabOperator $config
Assert-LabPublicConfiguration $config
$addresses = [ordered]@{}
foreach ($hostName in @("$($config.state_storage_account_name).blob.core.windows.net","$($config.key_vault_name).vault.azure.net")) {
    $resolved = @([Net.Dns]::GetHostAddresses($hostName) | ForEach-Object IPAddressToString | Sort-Object -Unique)
    Assert-LabPublicAddresses -HostName $hostName -Addresses $resolved
    $addresses[$hostName] = $resolved
}
$checks = [ordered]@{}
foreach ($service in @('Blob','KeyVault')) {
    $result = Invoke-LabAuthenticatedGet -Service $service -Configuration $config
    Assert-LabNetworkDenial -Service $service -StatusCode $result.StatusCode -ErrorCode $result.ErrorCode -InnerErrorCode $result.InnerErrorCode
    $checks[$service] = $result
}
$evidence = [ordered]@{
    lab_id=$config.lab_id;subscription_id=$config.subscription_id;tenant_id=$config.tenant_id
    operator_principal_id=$config.operator_principal_id;timestamp_utc=[DateTime]::UtcNow.ToString('o')
    execution_context='public-operator-host';private_positive_timestamp=$privateEvidence.timestamp_utc
    dns=$addresses;checks=$checks;status='PASSED';mdp_job_tested=$false
}
Write-LabEvidence -Evidence $evidence -Path $EvidencePath
Write-Output 'Public endpoint network denials passed for the same operator that read both private endpoints. Service error codes and public DNS were checked; no MDP job was executed.'
