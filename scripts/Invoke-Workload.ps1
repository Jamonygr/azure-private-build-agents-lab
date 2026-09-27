#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Plan', 'Apply', 'Destroy', 'Verify')][string]$Action,
    [Parameter(Mandatory)][string]$LabId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [string]$ConfigPath = '.local/lab-config.json',
    [string]$TerraformPath,
    [switch]$Execute,
    [string]$Confirmation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking

function Get-WorkloadFingerprint {
    param([Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)][string]$ConfigurationPath)
    $files = @((Get-ChildItem -LiteralPath $Directory -Filter '*.tf' -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/]\.terraform[\\/]' }).FullName)
    $files += Join-Path $Directory '.terraform.lock.hcl'
    $files += $ConfigurationPath
    $entries = foreach ($file in ($files | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'A required workload source, configuration or provider lock is missing.' }
        "$file`:$((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash)"
    }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))))
}

function Assert-WorkloadSavedPlan {
    param(
        [Parameter(Mandatory)][string]$PlanPath,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ExpectedFingerprint,
        [Parameter(Mandatory)][string]$ExpectedLabId,
        [Parameter(Mandatory)][string]$ExpectedSubscriptionId,
        [Parameter(Mandatory)][string]$ExpectedStateKey,
        [Parameter(Mandatory)][string]$ExpectedCommit,
        [bool]$Destroy = $false
    )
    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf) -or -not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw 'A reviewed saved plan and manifest are required. Run Plan first.'
    }
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.lab_id -cne $ExpectedLabId -or $manifest.subscription_id -ne $ExpectedSubscriptionId -or
        $manifest.state_key -cne $ExpectedStateKey -or $manifest.source_commit -cne $ExpectedCommit -or
        $manifest.input_hash -cne $ExpectedFingerprint -or $manifest.destroy -ne $Destroy -or
        $manifest.plan_sha256 -cne (Get-FileHash -LiteralPath $PlanPath -Algorithm SHA256).Hash) {
        throw 'Saved plan content, target, source or configuration changed. Generate and review a new plan.'
    }
}

Assert-LabId $LabId
if ($SubscriptionId -eq [guid]::Empty) { throw 'A nonempty subscription ID is required.' }
if (-not $Execute) {
    Write-Output "Preview: workload $Action for lab '$LabId' in subscription '$SubscriptionId'. No Azure or Terraform commands executed."
    return
}
if ($Action -eq 'Destroy' -and $Confirmation -cne "DESTROY $LabId") {
    throw "Destruction requires exact -Confirmation 'DESTROY $LabId'."
}
if (-not [IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath = Join-Path $repository $ConfigPath }
$configuration = Get-LabConfiguration -Path $ConfigPath
if ($configuration.lab_id -cne $LabId -or $configuration.subscription_id -ne $SubscriptionId.ToString()) {
    throw 'Exported configuration differs from the explicitly requested lab or subscription.'
}
if ($configuration.state_key -cne "workload/$LabId.tfstate" -or $configuration.workload_resource_group_name -cne "rg-$LabId-workload") {
    throw 'Workload state key or resource group does not match this lab.'
}
if ($configuration.bootstrap_secret_write_enabled -and $Action -ne 'Destroy') {
    throw 'Remove temporary secret-write permission and export configuration before normal workload operations.'
}
Assert-LabSubscription -Configuration $configuration
Assert-LabOwnership -Configuration $configuration -ResourceGroupName $configuration.workload_resource_group_name
$null = Assert-LabPrivateDns -Configuration $configuration
if (-not $TerraformPath) { $TerraformPath = Get-LabTerraform }
elseif (Test-Path -LiteralPath $TerraformPath -PathType Leaf) { $TerraformPath = (Resolve-Path -LiteralPath $TerraformPath).Path }
$version = (Invoke-LabNative -FilePath $TerraformPath -Arguments @('version', '-json')).Output | ConvertFrom-Json
if ($version.terraform_version -ne '1.16.4') { throw 'Terraform 1.16.4 is required.' }

$workloadDirectory = Join-Path $repository 'workload'
$runtimeDirectory = Join-Path $repository ".local/workload/$LabId"
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
$planPath = Join-Path $runtimeDirectory 'workload.tfplan'
$manifestPath = Join-Path $runtimeDirectory 'workload-plan.json'
$variablesPath = Join-Path $runtimeDirectory 'workload.tfvars.json'
$variables = [ordered]@{
    subscription_id = $configuration.subscription_id
    tenant_id = $configuration.tenant_id
    lab_id = $configuration.lab_id
    location = $configuration.location
    resource_group_name = $configuration.workload_resource_group_name
    vnet_address_space = $configuration.workload_vnet_cidr
}
$variables | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $variablesPath -Encoding utf8
$fingerprint = Get-WorkloadFingerprint -Directory $workloadDirectory -ConfigurationPath $ConfigPath
$git = Invoke-LabNative -FilePath git -Arguments @('rev-parse', 'HEAD') -WorkingDirectory $repository -AllowedExitCodes @(0, 128)
$commit = if ($git.ExitCode -eq 0) { $git.Output.Trim() } else { 'uncommitted' }

# Make authentication explicit for both provider and backend. Restore the caller's
# process environment afterwards. Token values are never written to files.
$environmentValues = @{
    ARM_SUBSCRIPTION_ID = $configuration.subscription_id
    ARM_TENANT_ID = $configuration.tenant_id
    ARM_USE_AZUREAD = 'true'
    ARM_USE_CLI = 'true'
    ARM_USE_OIDC = 'false'
    ARM_USE_MSI = 'false'
    ARM_USE_AKS_WORKLOAD_IDENTITY = 'false'
    TF_DATA_DIR = (Join-Path $runtimeDirectory 'terraform-data')
    TF_WORKSPACE = 'default'
    TF_IN_AUTOMATION = 'true'
    TF_INPUT = 'false'
}
$clearEnvironment = @('ARM_CLIENT_ID', 'ARM_CLIENT_ID_FILE_PATH', 'ARM_CLIENT_SECRET', 'ARM_CLIENT_SECRET_FILE_PATH',
    'ARM_CLIENT_CERTIFICATE', 'ARM_CLIENT_CERTIFICATE_PATH', 'ARM_CLIENT_CERTIFICATE_PASSWORD',
    'ARM_OIDC_TOKEN', 'ARM_OIDC_TOKEN_FILE_PATH', 'ARM_OIDC_REQUEST_TOKEN', 'ARM_OIDC_REQUEST_URL',
    'ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID', 'ARM_OIDC_AZURE_SERVICE_CONNECTION_ID', 'ARM_MSI_ENDPOINT',
    'ARM_ACCESS_KEY', 'ARM_SAS_TOKEN', 'TF_LOG', 'TF_LOG_PATH')
$clearEnvironment += @(Get-ChildItem Env: | Where-Object { $_.Name -eq 'TF_CLI_ARGS' -or $_.Name -like 'TF_CLI_ARGS_*' } | Select-Object -ExpandProperty Name)
$clearEnvironment += @(Get-ChildItem Env: | Where-Object { $_.Name -like 'TF_LOG*' } | Select-Object -ExpandProperty Name)
$originalEnvironment = @{}
foreach ($name in @($environmentValues.Keys) + $clearEnvironment) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    foreach ($name in $clearEnvironment) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
    foreach ($name in $environmentValues.Keys) { [Environment]::SetEnvironmentVariable($name, $environmentValues[$name], 'Process') }
    Set-LabCliEnvironment -Configuration $configuration
    $initArguments = @('init', '-input=false', '-no-color', '-reconfigure', '-lockfile=readonly',
        "-backend-config=storage_account_name=$($configuration.state_storage_account_name)",
        "-backend-config=container_name=$($configuration.state_container_name)",
        "-backend-config=key=$($configuration.state_key)",
        '-backend-config=use_azuread_auth=true', '-backend-config=use_cli=true', '-backend-config=use_oidc=false')
    $null = Invoke-LabNative -FilePath $TerraformPath -Arguments $initArguments -WorkingDirectory $workloadDirectory

    if ($Action -in @('Plan', 'Destroy')) {
        $arguments = @('plan', '-input=false', '-no-color', '-lock-timeout=60s', "-out=$planPath", "-var-file=$variablesPath")
        if ($Action -eq 'Destroy') { $arguments += '-destroy' }
        $null = Invoke-LabNative -FilePath $TerraformPath -Arguments $arguments -WorkingDirectory $workloadDirectory
        [ordered]@{
            lab_id = $LabId
            subscription_id = $SubscriptionId.ToString()
            state_key = $configuration.state_key
            source_commit = $commit
            input_hash = $fingerprint
            plan_sha256 = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash
            destroy = ($Action -eq 'Destroy')
        } | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
        Write-Output "Saved private workload plan: $planPath. Review locally with terraform show; do not publish the plan."
    }
    if ($Action -in @('Apply', 'Destroy')) {
        Assert-WorkloadSavedPlan -PlanPath $planPath -ManifestPath $manifestPath -ExpectedFingerprint $fingerprint -ExpectedLabId $LabId `
            -ExpectedSubscriptionId $SubscriptionId.ToString() -ExpectedStateKey $configuration.state_key -ExpectedCommit $commit -Destroy ($Action -eq 'Destroy')
        $null = Invoke-LabNative -FilePath $TerraformPath -Arguments @('apply', '-input=false', '-no-color', '-lock-timeout=60s', $planPath) -WorkingDirectory $workloadDirectory
        Write-Output "Workload $Action completed."
    }
    if ($Action -eq 'Verify') {
        $result = Invoke-LabNative -FilePath $TerraformPath -Arguments @('plan', '-input=false', '-no-color', '-lock-timeout=60s', '-detailed-exitcode', "-var-file=$variablesPath") -WorkingDirectory $workloadDirectory -AllowedExitCodes @(0, 2)
        if ($result.ExitCode -ne 0) { throw 'The post-apply plan contains changes. Workload convergence validation failed.' }
        Write-Output 'Passed: workload remote state initialized privately and the second plan contains no changes.'
    }
    if ($Action -eq 'Destroy') {
        $state = Invoke-LabNative -FilePath $TerraformPath -Arguments @('state', 'list') -WorkingDirectory $workloadDirectory
        if (-not [string]::IsNullOrWhiteSpace($state.Output)) { throw 'Workload state still contains resources after destruction.' }
        Assert-LabWorkloadEmpty -Configuration $configuration
        Write-Output 'Passed: workload state and resource group are empty. Foundation cleanup may now run from the independent operator context.'
    }
} finally {
    foreach ($name in $originalEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process') }
}
