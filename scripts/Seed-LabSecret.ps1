#requires -Version 7.4
[CmdletBinding()]
param([string]$ConfigPath = '.local/lab-config.json', [switch]$Execute, [string]$Confirmation)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$config = Get-LabConfiguration $ConfigPath
if (-not $Execute) { Write-Output 'Preview: create the synthetic lab-validation secret from this private-connected operator host.'; return }
if ($Confirmation -cne "SEED $($config.lab_id)") { throw "Seeding requires -Confirmation 'SEED $($config.lab_id)'." }
if (-not $config.bootstrap_secret_write_enabled) { throw 'Temporarily enable the operator seed role, apply and export before seeding.' }
if (-not $IsWindows) { throw 'This secret file protection implementation requires Windows.' }
Assert-LabOperator $config
$ips = @([Net.Dns]::GetHostAddresses("$($config.key_vault_name).vault.azure.net") | ForEach-Object IPAddressToString)
if (-not $ips.Count -or @($ips | Where-Object { $_ -ne $config.vault_private_ip }).Count) { throw 'The vault does not resolve to its expected private IP from this host.' }
$directory = Join-Path ([IO.Path]::GetTempPath()) ('azure-lab-seed-' + [guid]::NewGuid().ToString('N'))
$file = Join-Path $directory 'synthetic.txt'
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    $acl = Get-Acl -LiteralPath $directory
    $acl.SetAccessRuleProtection($true,$false)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $directory -AclObject $acl
    $value = 'synthetic-lab-only-' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
    [IO.File]::WriteAllText($file,$value,[Text.UTF8Encoding]::new($false))
    Invoke-LabNative az @('keyvault','secret','set','--vault-name',$config.key_vault_name,'--name','lab-validation','--file',$file,'--encoding','utf-8','--output','none','--only-show-errors') | Out-Null
} finally {
    $value = $null
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Force }
}
Write-Output 'Synthetic secret created without printing its value. Disable the seed role, apply, export and verify revocation before normal tests.'
