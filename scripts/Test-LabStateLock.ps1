#requires -Version 7.4
[CmdletBinding()]
param([string]$ConfigPath = '.local/lab-config.json', [switch]$Execute,
      [string]$TerraformPath, [string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$config = Get-LabConfiguration $ConfigPath
if (-not $Execute) { Write-Output 'Preview: two Terraform processes will contend for a disposable tests/locks state key from this private-connected host.'; return }
if (-not $IsWindows) { throw 'The live lock test requires the documented Windows host.' }
$originalEnvironment = @{}
$environmentKeys = @('TF_DATA_DIR','TF_WORKSPACE','ARM_SUBSCRIPTION_ID','ARM_TENANT_ID','ARM_USE_CLI','ARM_USE_AZUREAD','ARM_USE_OIDC','ARM_USE_MSI','ARM_USE_AKS_WORKLOAD_IDENTITY','ARM_CLIENT_ID','ARM_CLIENT_ID_FILE_PATH','ARM_CLIENT_SECRET','ARM_CLIENT_SECRET_FILE_PATH','ARM_CLIENT_CERTIFICATE','ARM_CLIENT_CERTIFICATE_PATH','ARM_CLIENT_CERTIFICATE_PASSWORD','ARM_OIDC_TOKEN','ARM_OIDC_TOKEN_FILE_PATH','ARM_OIDC_REQUEST_TOKEN','ARM_OIDC_REQUEST_URL','ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID','ARM_OIDC_AZURE_SERVICE_CONNECTION_ID','ARM_ACCESS_KEY','ARM_SAS_TOKEN','ARM_MSI_ENDPOINT')
$environmentKeys += @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'TF_CLI_ARGS*' -or $_ -like 'TF_LOG*' })
foreach ($key in ($environmentKeys | Select-Object -Unique)) { $originalEnvironment[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
try {
$env:TF_WORKSPACE = 'default'
Set-LabCliEnvironment $config
Assert-LabPrivateDns $config | Out-Null
if (-not $TerraformPath) { $TerraformPath = Get-LabTerraform }
$TerraformPath = (Get-Command -Name $TerraformPath -CommandType Application -ErrorAction Stop).Source
$version = (Invoke-LabNative $TerraformPath @('version','-json')).Output | ConvertFrom-Json
if ($version.terraform_version -ne '1.16.4') { throw 'Terraform 1.16.4 is required.' }
$runId = [guid]::NewGuid().ToString('N')
$stateKey = "tests/locks/$($config.lab_id)/$runId.tfstate"
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ".local/lock-tests/$runId"
$first = Join-Path $scratch 'first'
$second = Join-Path $scratch 'second'
$marker = Join-Path $scratch 'ready.marker'
New-Item -ItemType Directory -Path $first,$second -Force | Out-Null
foreach ($directory in @($first,$second)) {
    Copy-Item -LiteralPath (Join-Path $root 'tests/live/locking/main.tf') -Destination (Join-Path $directory 'main.tf')
    @{marker_path=$marker;hold_seconds=30} | ConvertTo-Json | Set-Content (Join-Path $directory 'fixture.auto.tfvars.json') -Encoding utf8
    $backend = [ordered]@{storage_account_name=$config.state_storage_account_name;container_name=$config.state_container_name;key=$stateKey;use_azuread_auth='true';use_cli='true';tenant_id=$config.tenant_id;subscription_id=$config.subscription_id}
    $arguments = @('init','-input=false')
    foreach ($entry in $backend.GetEnumerator()) { $arguments += "-backend-config=$($entry.Key)=$($entry.Value)" }
    $env:TF_DATA_DIR = Join-Path $directory '.terraform'
    Invoke-LabNative $TerraformPath $arguments -WorkingDirectory $directory | Out-Null
}
$process = $null
$completed = $false
try {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $TerraformPath
    $start.WorkingDirectory = $first
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.Environment['TF_DATA_DIR'] = Join-Path $first '.terraform'
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('apply','-input=false','-auto-approve','-no-color')) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while (-not (Test-Path -LiteralPath $marker)) {
        if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'The first process did not reach the lock-held marker; this is not a passing test.' }
        Start-Sleep -Milliseconds 250
    }
    $env:TF_DATA_DIR = Join-Path $second '.terraform'
    $contender = Invoke-LabNative $TerraformPath @('plan','-input=false','-lock-timeout=2s','-no-color') -WorkingDirectory $second -AllowedExitCodes @(0,1)
    if ($contender.ExitCode -ne 1 -or $contender.Output -notmatch 'Error acquiring the state lock') { throw 'Second Terraform process did not fail with the expected state-lock diagnostic.' }
    if (-not $process.WaitForExit(60000)) { throw 'First process did not finish in its bounded window. Inspect the disposable key; no force-unlock is performed.' }
    # Drain redirected output without printing it; the fixture never contains a secret.
    $null = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) { throw 'First Terraform process failed; inspect the disposable fixture privately.' }
    Invoke-LabNative $TerraformPath @('plan','-input=false','-lock-timeout=5s','-no-color') -WorkingDirectory $second | Out-Null
    $env:TF_DATA_DIR = Join-Path $first '.terraform'
    Invoke-LabNative $TerraformPath @('destroy','-input=false','-auto-approve','-no-color') -WorkingDirectory $first | Out-Null
    $completed = $true
    Write-LabEvidence -Path $EvidencePath -Evidence ([ordered]@{lab_id=$config.lab_id;timestamp_utc=[DateTime]::UtcNow.ToString('o');test='remote-state-lock';execution_context='operator-host';state_key=$stateKey;contention='passed';released_plan='passed';fixture_destroyed=$true;mdp_job_tested=$false})
    Write-Output "State-lock test passed. Disposable fixture destroyed; empty test state remains at $stateKey for inspection."
} finally {
    if ($process) {
        if (-not $process.HasExited) {
            # Let the bounded fixture finish naturally. Never kill a writer or force-unlock its state.
            $null = $process.WaitForExit(60000)
        }
        $process.Dispose()
    }
    if (-not $completed) { Write-Warning "Test did not complete. Preserve $scratch and inspect only disposable key $stateKey; no production state was unlocked or removed." }
}

} finally {
    foreach ($key in $originalEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key,$originalEnvironment[$key],'Process') }
}
