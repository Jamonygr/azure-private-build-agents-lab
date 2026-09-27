#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Preflight','Plan','Apply','Export','Destroy','VerifyCleanup','VerifySeedRevoked','ValidatePublicAccess')][string]$Action,
    [Parameter(Mandatory)][string]$LabId,
    [Parameter(Mandatory)][guid]$SubscriptionId,
    [string]$VarFile = '.local/lab.tfvars',
    [string]$ConfigPath = '.local/lab-config.json',
    [string]$TerraformPath,
    [string]$PrivateEvidencePath,
    [string]$EvidencePath,
    [switch]$Execute,
    [string]$Confirmation
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$root = Split-Path $PSScriptRoot -Parent
Assert-LabId $LabId
if ($SubscriptionId -eq [guid]::Empty) { throw 'A nonempty subscription ID is required.' }
$localPath = Join-Path $root '.local'
$statePath = Join-Path $localPath "state/foundation-$LabId.tfstate"
$planPath = Join-Path $localPath "foundation-$LabId.tfplan"
$metadataPath = "$planPath.json"
if (-not [IO.Path]::IsPathRooted($VarFile)) { $VarFile = Join-Path $root $VarFile }
if (-not [IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath = Join-Path $root $ConfigPath }

function Get-InputFingerprint {
    $files = @((Get-ChildItem -LiteralPath $root -Filter '*.tf' -File).FullName)
    $files += @((Get-ChildItem -LiteralPath (Join-Path $root 'modules') -Filter '*.tf' -File -Recurse).FullName)
    $files += @((Join-Path $root 'environments/lab.tfvars'),$VarFile)
    $lockFile = Join-Path $root '.terraform.lock.hcl'
    if (Test-Path -LiteralPath $lockFile) { $files += $lockFile }
    $digest = foreach ($file in ($files | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $file)) { throw "Required Terraform input missing: $file" }
        "$file`:$((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash)"
    }
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($digest -join "`n"))))
}
function Get-Commit {
    $result = Invoke-LabNative git @('rev-parse','HEAD') -WorkingDirectory $root -AllowedExitCodes @(0,128)
    if ($result.ExitCode -ne 0) { return 'uncommitted' }
    return $result.Output.Trim()
}
function Read-TargetConfig {
    $target = Get-LabConfiguration -Path $ConfigPath
    if ($target.lab_id -cne $LabId -or $target.subscription_id -ne $SubscriptionId.ToString()) { throw 'Configuration LabId or SubscriptionId differs from the requested target.' }
    return $target
}
function Initialize-Foundation {
    Clear-LabCredentialEnvironment
    $env:TF_DATA_DIR = Join-Path $localPath "foundation/$LabId/terraform-data"
    $env:TF_WORKSPACE = 'default'
    $env:ARM_SUBSCRIPTION_ID = $SubscriptionId.ToString()
    if (-not $script:TerraformPath) { $script:TerraformPath = Get-LabTerraform }
    $script:TerraformPath = (Get-Command -Name $script:TerraformPath -CommandType Application -ErrorAction Stop).Source
    $actualVersion = (Invoke-LabNative $script:TerraformPath @('version','-json')).Output | ConvertFrom-Json
    if ($actualVersion.terraform_version -ne '1.16.4') { throw 'Terraform 1.16.4 is required.' }
    New-Item -ItemType Directory -Path (Split-Path $statePath -Parent) -Force | Out-Null
    Invoke-LabNative $script:TerraformPath @('init','-input=false','-reconfigure',"-backend-config=path=$statePath") -WorkingDirectory $root | Out-Null
}
function Get-VariableArguments {
    @('-input=false',"-var-file=$(Join-Path $root 'environments/lab.tfvars')","-var-file=$VarFile","-var=lab_id=$LabId","-var=subscription_id=$SubscriptionId")
}
function Read-StateConfig {
    (Invoke-LabNative $script:TerraformPath @('output','-json','lab_configuration') -WorkingDirectory $root).Output | ConvertFrom-Json
}

if (-not $Execute) {
    Write-Output "Preview: $Action for lab '$LabId' in subscription '$SubscriptionId'. No Azure or Terraform commands executed."
    Write-Output "State: $statePath"
    if ($Action -eq 'Destroy') { Write-Output "Live destroy requires -Execute -Confirmation 'DESTROY $LabId' and an empty workload resource group." }
    return
}
if ($Action -eq 'Destroy') {
    if ($env:TF_BUILD -eq 'True') { throw 'Foundation destruction must run in the independent operator context, never on this lab agent.' }
    if ($Confirmation -cne "DESTROY $LabId") { throw "Destruction requires exact -Confirmation 'DESTROY $LabId'." }
}
$originalEnvironment = @{}
foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) {
    $originalEnvironment[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
}
try {
if ($Action -in @('Preflight','Plan','Apply','Export')) {
    $account = (Invoke-LabNative az @('account','show','--output','json','--only-show-errors')).Output | ConvertFrom-Json
    if ($account.id -ne $SubscriptionId.ToString()) { throw 'Azure CLI subscription differs from -SubscriptionId. Select it explicitly before continuing.' }
}

switch ($Action) {
    'Preflight' {
        if (-not $TerraformPath) { $TerraformPath = Get-LabTerraform }
        $TerraformPath = (Get-Command -Name $TerraformPath -CommandType Application -ErrorAction Stop).Source
        if (((Invoke-LabNative $TerraformPath @('version','-json')).Output | ConvertFrom-Json).terraform_version -ne '1.16.4') { throw 'Terraform 1.16.4 is required.' }
        if (-not (Test-Path -LiteralPath $VarFile)) { throw 'Create your ignored lab.tfvars from the example before preflight.' }
        foreach ($provider in @('Microsoft.DevOpsInfrastructure','Microsoft.DevCenter','Microsoft.ManagedIdentity','Microsoft.Network','Microsoft.Storage','Microsoft.KeyVault','Microsoft.OperationalInsights','Microsoft.Insights')) {
            $status = (Invoke-LabNative az @('provider','show','--namespace',$provider,'--query','registrationState','--output','tsv','--subscription',$SubscriptionId.ToString(),'--only-show-errors')).Output.Trim()
            if ($status -ne 'Registered') { throw "Required provider $provider is not registered. Complete prerequisites explicitly." }
        }
        $selectedRegion = $null
        foreach ($inputFile in @((Join-Path $root 'environments/lab.tfvars'),$VarFile)) {
            $assignments = @([regex]::Matches((Get-Content -LiteralPath $inputFile -Raw),'(?m)^\s*location\s*=\s*"([a-zA-Z0-9 -]+)"\s*(?:#.*)?$'))
            if ($assignments.Count -gt 1) { throw 'Location has multiple assignments in one input file.' }
            if ($assignments.Count -eq 1) { $selectedRegion = $assignments[0].Groups[1].Value }
        }
        if (-not $selectedRegion) { throw 'Preflight requires a literal location in environments/lab.tfvars or the selected user varfile.' }
        $providerInfo = (Invoke-LabNative az @('provider','show','--namespace','Microsoft.DevOpsInfrastructure','--output','json','--subscription',$SubscriptionId.ToString(),'--only-show-errors')).Output | ConvertFrom-Json
        $poolType = @($providerInfo.resourceTypes | Where-Object resourceType -eq 'pools')
        $normalizedRegion = ($selectedRegion -replace '\s','').ToLowerInvariant()
        $availableRegions = @($poolType | ForEach-Object locations | ForEach-Object { ($_ -replace '\s','').ToLowerInvariant() })
        if ($normalizedRegion -notin $availableRegions) { throw "Managed DevOps Pools does not advertise availability in region $selectedRegion for this subscription." }
        $capacity = Get-LabMdpCapacity -SubscriptionId $SubscriptionId -Location $normalizedRegion
        Write-Output "CHECKED: selected subscription, resource-provider registrations, MDP region $selectedRegion, unrestricted $($capacity.SkuName), and $($capacity.AvailableCores) available family vCPUs (2 required)."
        Write-Output 'NOT_RUN: effective deployment/RBAC permissions and Azure DevOps pool permissions still require the prerequisite runbook checks. This is not a complete deployment readiness result.'
    }
    'Plan' {
        Initialize-Foundation
        Invoke-LabNative $TerraformPath (@('plan') + @(Get-VariableArguments) + @("-out=$planPath")) -WorkingDirectory $root | Out-Null
        [ordered]@{lab_id=$LabId;subscription_id=$SubscriptionId.ToString();state_path=$statePath;input_hash=(Get-InputFingerprint);commit=(Get-Commit);plan_hash=(Get-FileHash $planPath -Algorithm SHA256).Hash} |
            ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8
        Write-Output "Foundation plan saved locally: $planPath. Review with terraform show; do not publish the plan or its JSON."
    }
    'Apply' {
        Initialize-Foundation
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        if ($metadata.lab_id -cne $LabId -or $metadata.subscription_id -ne $SubscriptionId.ToString() -or $metadata.state_path -ne $statePath -or
            $metadata.input_hash -ne (Get-InputFingerprint) -or $metadata.commit -ne (Get-Commit) -or $metadata.plan_hash -ne (Get-FileHash $planPath -Algorithm SHA256).Hash) {
            throw 'Saved plan target, inputs, commit or hash changed. Run Plan again and review the new plan.'
        }
        Invoke-LabNative $TerraformPath @('apply','-input=false',$planPath) -WorkingDirectory $root | Out-Null
        Write-Output 'Foundation apply completed. Run Export to refresh the local configuration.'
    }
    'Export' {
        Initialize-Foundation
        $stateConfig = Read-StateConfig
        if ($stateConfig.lab_id -cne $LabId -or $stateConfig.subscription_id -ne $SubscriptionId.ToString()) { throw 'Terraform state is for a different lab or subscription.' }
        New-Item -ItemType Directory -Path (Split-Path ([IO.Path]::GetFullPath($ConfigPath)) -Parent) -Force | Out-Null
        $stateConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ConfigPath -Encoding utf8
        Get-LabConfiguration $ConfigPath | Out-Null
        Write-Output "Exported nonsecret lab configuration to $ConfigPath."
    }
    'Destroy' {
        $config = Read-TargetConfig
        Assert-LabSubscription $config
        Assert-LabOwnership $config $config.foundation_resource_group_name
        Assert-LabWorkloadEmpty $config
        Initialize-Foundation
        $stateConfig = Read-StateConfig
        foreach ($key in @('lab_id','subscription_id','tenant_id','foundation_resource_group_name','workload_resource_group_name','state_storage_account_name','key_vault_name')) {
            if ($stateConfig.$key -ne $config.$key) { throw "Exported target differs from the selected Terraform state: $key." }
        }
        $destroyPlan = Join-Path $localPath "foundation-$LabId.destroy.tfplan"
        Invoke-LabNative $TerraformPath (@('plan','-destroy') + @(Get-VariableArguments) + @("-out=$destroyPlan")) -WorkingDirectory $root | Out-Null
        Invoke-LabNative $TerraformPath @('apply','-input=false',$destroyPlan) -WorkingDirectory $root | Out-Null
        Write-Output 'Foundation destroy completed. Run VerifyCleanup. This script never purges soft-deleted vaults.'
    }
    'VerifyCleanup' {
        $config = Read-TargetConfig
        Assert-LabSubscription $config
        foreach ($group in @($config.foundation_resource_group_name,$config.workload_resource_group_name)) {
            $exists = (Invoke-LabNative az @('group','exists','--name',$group,'--subscription',$config.subscription_id,'--output','tsv','--only-show-errors')).Output.Trim()
            if ($exists -ne 'false') { throw "Resource group still exists or could not be verified: $group." }
        }
        Write-Output 'ACTIVE RESOURCES: both exact lab resource groups are absent.'
        $deletedVault = Get-LabDeletedVault $config
        if ($deletedVault.Status -eq 'RETAINED') {
            Write-Output "SOFT-DELETED VAULT: $($deletedVault.Name) retained; deleted $($deletedVault.DeletionDate); scheduled purge $($deletedVault.ScheduledPurgeDate). Retention is separate from active resource cleanup."
        } else {
            Write-Output "SOFT-DELETED VAULT: no retained record for exact lab vault $($deletedVault.Name)."
        }
        Write-Output 'Local state is preserved. No vault purge or unrelated-resource deletion was attempted.'
    }
    'VerifySeedRevoked' {
        $config = Read-TargetConfig
        Assert-LabSubscription $config
        if ($config.bootstrap_secret_write_enabled) { throw 'Configuration still enables bootstrap secret write. Apply the disabled flag and export again.' }
        $scope = "/subscriptions/$($config.subscription_id)/resourceGroups/$($config.foundation_resource_group_name)/providers/Microsoft.KeyVault/vaults/$($config.key_vault_name)"
        $roles = (Invoke-LabNative az @('role','assignment','list','--assignee-object-id',$config.operator_principal_id,'--scope',$scope,'--include-inherited','--all','--output','json','--only-show-errors')).Output | ConvertFrom-Json
        if (@($roles | Where-Object { $_.roleDefinitionName -in @('Key Vault Secrets Officer','Key Vault Administrator') }).Count) { throw 'The operator identity still has a Key Vault data write role. Remove it before normal validation.' }
        Write-Output 'Bootstrap disabled and no inherited/direct built-in Key Vault write role remains. A private-context denied-write test is still needed to verify effective permissions after propagation.'
    }
    'ValidatePublicAccess' {
        $config = Read-TargetConfig
        Assert-LabSubscription $config
        Assert-LabPublicConfiguration $config
        if ($PrivateEvidencePath) {
            & (Join-Path $PSScriptRoot 'Test-LabPublicAccess.ps1') -ConfigPath $ConfigPath -PrivateEvidencePath $PrivateEvidencePath -EvidencePath $EvidencePath -Execute
        } else {
            Write-Output 'CONFIGURATION_ONLY: ARM confirms disabled public data access and Storage shared keys. External data-plane verification is NOT_RUN. Supply -PrivateEvidencePath from the private positive test and run on a public-network host to execute authenticated negative probes.'
        }
    }
}



} finally {
    foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) {
        if (-not $originalEnvironment.ContainsKey($key)) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
    }
    foreach ($key in $originalEnvironment.Keys) { [Environment]::SetEnvironmentVariable($key,$originalEnvironment[$key],'Process') }
}
