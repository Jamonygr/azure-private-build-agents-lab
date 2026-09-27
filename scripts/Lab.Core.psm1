#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-LabNative {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath,
          [string[]]$Arguments = @(), [string]$WorkingDirectory,
          [int[]]$AllowedExitCodes = @(0))
    $oldPreference = $ErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        if ($WorkingDirectory) { Push-Location -LiteralPath $WorkingDirectory }
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        $lines = @(& $FilePath @Arguments 2>&1)
        $code = $global:LASTEXITCODE
        $outputText = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
        if ($null -eq $code) { throw 'Native executable did not return an exit code.' }
        if ($code -notin $AllowedExitCodes) {
            # Do not include arguments/stderr: commands may handle secret material.
            throw "Native command $([IO.Path]::GetFileName($FilePath)) failed (exit $code). No command output was logged."
        }
        [pscustomobject]@{ ExitCode = [int]$code; Output = $outputText }
    } finally {
        $ErrorActionPreference = $oldPreference
        if ($WorkingDirectory) { Pop-Location }
    }
}

function Assert-LabId {
    param([Parameter(Mandatory)][string]$LabId)
    if ($LabId -cnotmatch '^[a-z][a-z0-9]{2,11}$') { throw 'LabId must be 3-12 lowercase letters or digits, beginning with a letter.' }
}

function Assert-LabConfirmation {
    param([Parameter(Mandatory)][string]$Action, [Parameter(Mandatory)][string]$LabId,
          [switch]$Execute, [string]$Confirmation)
    Assert-LabId $LabId
    if (-not $Execute -or $Confirmation -cne "$($Action.ToUpperInvariant()) $LabId") {
        throw "This action requires -Execute -Confirmation '$($Action.ToUpperInvariant()) $LabId'."
    }
}

function Get-LabConfiguration {
    param([Parameter(Mandatory)][string]$Path)
    $config = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    $required = @('lab_id','subscription_id','tenant_id','location','foundation_resource_group_name',
        'workload_resource_group_name','pool_name','azure_devops_organization_url','azure_devops_project_name',
        'agent_identity_client_id','agent_identity_principal_id','operator_principal_id','state_storage_account_name',
        'state_container_name','state_key','key_vault_name','key_vault_uri','blob_private_ip','vault_private_ip',
        'firewall_resource_id','log_analytics_workspace_id','bootstrap_secret_write_enabled')
    foreach ($key in $required) { if (-not $config.ContainsKey($key)) { throw "Lab configuration is missing $key. Export it again from the foundation root." } }
    Assert-LabId $config.lab_id
    foreach ($key in @('subscription_id','tenant_id','agent_identity_client_id','agent_identity_principal_id','operator_principal_id','log_analytics_workspace_id')) {
        $parsedGuid = [guid]::Empty
        if (-not [guid]::TryParse([string]$config[$key], [ref]$parsedGuid) -or $parsedGuid -eq [guid]::Empty) { throw "Invalid $key in lab configuration." }
    }
    if ($config.state_container_name -notmatch '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' -or $config.state_container_name.Contains('--')) { throw 'Invalid state container name.' }
    foreach ($key in @('blob_private_ip','vault_private_ip')) {
        $ip = $null
        if (-not [Net.IPAddress]::TryParse([string]$config[$key],[ref]$ip) -or $ip.AddressFamily -ne 'InterNetwork') { throw "Invalid $key." }
    }
    if ($config.state_storage_account_name -notmatch '^[a-z0-9]{3,24}$') { throw 'Invalid storage account name.' }
    if ($config.key_vault_name -notmatch '^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$') { throw 'Invalid Key Vault name.' }
    if ($config.key_vault_uri.TrimEnd('/') -cne "https://$($config.key_vault_name).vault.azure.net") { throw 'Key Vault URI does not match its name.' }
    foreach ($key in @('foundation_resource_group_name','workload_resource_group_name')) {
        if ($config[$key] -notmatch '^[a-zA-Z0-9_.()-]{1,90}$') { throw "Invalid $key." }
    }
    if ($config.foundation_resource_group_name -eq $config.workload_resource_group_name) { throw 'Foundation and workload resource groups must differ.' }
    if ($config.state_key -match '\.\.|^/|\\' -or [string]::IsNullOrWhiteSpace($config.state_key)) { throw 'Invalid state key.' }
    if ($config.firewall_resource_id -notlike "/subscriptions/$($config.subscription_id)/resourceGroups/$($config.foundation_resource_group_name)/providers/Microsoft.Network/azureFirewalls/*") { throw 'Firewall target does not match the foundation scope.' }
    if ($config.bootstrap_secret_write_enabled -isnot [bool]) { throw 'Configuration flags must be JSON booleans.' }
    return [pscustomobject]$config
}

function Assert-LabSubscription {
    param([Parameter(Mandatory)]$Configuration)
    $account = (Invoke-LabNative -FilePath az -Arguments @('account','show','--output','json','--only-show-errors')).Output | ConvertFrom-Json
    if ($account.id -ne $Configuration.subscription_id -or $account.tenantId -ne $Configuration.tenant_id) { throw 'Azure CLI subscription or tenant differs from lab configuration. Select the intended account explicitly.' }
}

function Assert-LabOwnership {
    param([Parameter(Mandatory)]$Configuration, [Parameter(Mandatory)][string]$ResourceGroupName)
    if ($ResourceGroupName -notin @($Configuration.foundation_resource_group_name,$Configuration.workload_resource_group_name)) { throw 'Resource group is outside the exported lab targets.' }
    $group = (Invoke-LabNative az @('group','show','--name',$ResourceGroupName,'--subscription',$Configuration.subscription_id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
    if (-not $group.tags -or $group.tags.lab_id -ne $Configuration.lab_id) { throw 'Resource group lab_id tag does not match the exported configuration.' }
}

function Assert-LabWorkloadEmpty {
    param([Parameter(Mandatory)]$Configuration)
    Assert-LabOwnership $Configuration $Configuration.workload_resource_group_name
    $resources = (Invoke-LabNative az @('resource','list','--resource-group',$Configuration.workload_resource_group_name,'--subscription',$Configuration.subscription_id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
    if (@($resources).Count -ne 0) { throw 'Workload resource group is not empty. Destroy the workload with Invoke-Workload.ps1 before destroying the foundation.' }
}

function Assert-LabOperator {
    param([Parameter(Mandatory)]$Configuration)
    Assert-LabSubscription $Configuration
    # Decode only the identity claims of a token obtained by Azure CLI; never log the token.
    $token = (Invoke-LabNative az @('account','get-access-token','--resource','https://management.azure.com/','--output','json','--only-show-errors')).Output | ConvertFrom-Json
    try {
        $payload = $token.accessToken.Split('.')[1].Replace('-','+').Replace('_','/')
        $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        if ($claims.oid -ne $Configuration.operator_principal_id -or $claims.tid -ne $Configuration.tenant_id) {
            throw 'Azure CLI identity does not match operator_principal_id and tenant in exported configuration.'
        }
    } finally { $token = $null; $payload = $null; $claims = $null }
}
function Clear-LabCredentialEnvironment {
    foreach ($key in @('ARM_CLIENT_ID','ARM_CLIENT_ID_FILE_PATH','ARM_CLIENT_SECRET','ARM_CLIENT_SECRET_FILE_PATH','ARM_CLIENT_CERTIFICATE','ARM_CLIENT_CERTIFICATE_PATH','ARM_CLIENT_CERTIFICATE_PASSWORD','ARM_OIDC_TOKEN','ARM_OIDC_TOKEN_FILE_PATH','ARM_OIDC_REQUEST_TOKEN','ARM_OIDC_REQUEST_URL','ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID','ARM_OIDC_AZURE_SERVICE_CONNECTION_ID','ARM_ACCESS_KEY','ARM_SAS_TOKEN','ARM_MSI_ENDPOINT')) {
        [Environment]::SetEnvironmentVariable($key,$null,'Process')
    }
    foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'TF_CLI_ARGS*' -or $_ -like 'TF_LOG*' })) {
        [Environment]::SetEnvironmentVariable($key,$null,'Process')
    }
    $env:ARM_USE_CLI = 'true'
    $env:ARM_USE_AZUREAD = 'true'
    $env:ARM_USE_OIDC = 'false'
    $env:ARM_USE_MSI = 'false'
    $env:ARM_USE_AKS_WORKLOAD_IDENTITY = 'false'
}
function Set-LabCliEnvironment {
    param([Parameter(Mandatory)]$Configuration)
    Assert-LabOperator $Configuration
    Clear-LabCredentialEnvironment
    $env:ARM_SUBSCRIPTION_ID = $Configuration.subscription_id
    $env:ARM_TENANT_ID = $Configuration.tenant_id
    $env:ARM_USE_CLI = 'true'
    $env:ARM_USE_AZUREAD = 'true'
    $env:ARM_USE_OIDC = 'false'
    $env:ARM_USE_MSI = 'false'
}

function Assert-LabPrivateDns {
    param([Parameter(Mandatory)]$Configuration)
    $records = [ordered]@{}
    foreach ($endpoint in @(@{HostName="$($Configuration.state_storage_account_name).blob.core.windows.net";Expected=$Configuration.blob_private_ip},@{HostName="$($Configuration.key_vault_name).vault.azure.net";Expected=$Configuration.vault_private_ip})) {
        $addresses = @([Net.Dns]::GetHostAddresses($endpoint.HostName) | ForEach-Object IPAddressToString | Sort-Object -Unique)
        if (-not $addresses.Count -or @($addresses | Where-Object { $_ -ne $endpoint.Expected }).Count) { throw "DNS for $($endpoint.HostName) did not resolve exclusively to the exported private endpoint IP." }
        $records[$endpoint.HostName] = $addresses
    }
    return $records
}
function Get-LabTerraform {
    param([switch]$Install, [string]$ToolsDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) '.local/tools'))
    $version = '1.16.4'
    $command = Get-Command terraform -ErrorAction SilentlyContinue
    if ($command) {
        $info = (Invoke-LabNative $command.Source @('version','-json')).Output | ConvertFrom-Json
        if ($info.terraform_version -eq $version) { return $command.Source }
    }
    $target = Join-Path $ToolsDirectory "terraform-$version/terraform.exe"
    if (Test-Path -LiteralPath $target) {
        $info = (Invoke-LabNative $target @('version','-json')).Output | ConvertFrom-Json
        if ($info.terraform_version -eq $version) {
            $env:PATH = "$(Split-Path $target -Parent)$([IO.Path]::PathSeparator)$env:PATH"
            return $target
        }
    }
    if (-not $Install) { throw "Terraform $version is required. Install it explicitly, or import Lab.Core.psm1 and call Get-LabTerraform -Install." }
    if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw 'The explicit installer supports Windows x64 only.' }
    $directory = Split-Path $target -Parent
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $archiveName = "terraform_${version}_windows_amd64.zip"
    $archive = Join-Path $directory $archiveName
    $checksums = Join-Path $directory "terraform_${version}_SHA256SUMS"
    try {
        Invoke-WebRequest "https://releases.hashicorp.com/terraform/$version/$archiveName" -OutFile $archive
        Invoke-WebRequest "https://releases.hashicorp.com/terraform/$version/terraform_${version}_SHA256SUMS" -OutFile $checksums
        $match = @(Get-Content -LiteralPath $checksums | Where-Object { $_ -match "^[0-9a-fA-F]{64}\s+\*?$([regex]::Escape($archiveName))$" })
        if ($match.Count -ne 1) { throw 'Terraform checksum manifest has no unique archive match.' }
        $expected = ($match[0] -split '\s+')[0]
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $expected) { throw 'Terraform archive checksum does not match the official manifest.' }
        Expand-Archive -LiteralPath $archive -DestinationPath $directory -Force
        $info = (Invoke-LabNative $target @('version','-json')).Output | ConvertFrom-Json
        if ($info.terraform_version -ne $version) { throw 'Installed Terraform version is unexpected.' }
    } finally {
        foreach ($temporary in @($archive,$checksums)) { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
    }
    $env:PATH = "$directory$([IO.Path]::PathSeparator)$env:PATH"
    return $target
}

function Get-LabArmCollection {
    param([Parameter(Mandatory)][uri]$Uri)
    if ($Uri.Scheme -ne 'https' -or $Uri.Host -ne 'management.azure.com' -or -not $Uri.IsDefaultPort -or $Uri.UserInfo) { throw 'ARM collection URI must use the public Azure Resource Manager HTTPS endpoint.' }
    $expectedPath = $Uri.AbsolutePath
    $next = $Uri.AbsoluteUri
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $items = [Collections.Generic.List[object]]::new()
    while ($next) {
        $pageUri = [uri]$next
        if ($pageUri.Scheme -ne 'https' -or $pageUri.Host -ne 'management.azure.com' -or -not $pageUri.IsDefaultPort -or $pageUri.UserInfo -or $pageUri.AbsolutePath -ine $expectedPath) { throw 'ARM pagination returned an unexpected host or resource path.' }
        if (-not $seen.Add($next) -or $seen.Count -gt 1000) { throw 'ARM pagination repeated a page or exceeded its safety bound.' }
        $page = (Invoke-LabNative az @('rest','--method','get','--url',$next,'--output','json','--only-show-errors')).Output | ConvertFrom-Json -AsHashtable
        if (-not $page.ContainsKey('value') -or $null -eq $page.value) { throw 'ARM response has no collection value.' }
        foreach ($item in $page.value) { $items.Add($item) }
        $next = if ($page.ContainsKey('nextLink')) { [string]$page.nextLink } else { '' }
    }
    return $items.ToArray()
}

function Assert-LabMdpCapacity {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$SkuItems,
          [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$UsageItems,
          [Parameter(Mandatory)][string]$Location)
    $skuName = 'Standard_D2ads_v5'
    $family = 'standardDADSv5Family'
    $matches = @($SkuItems | Where-Object { $_.name -eq $skuName })
    if ($matches.Count -ne 1) { throw "MDP SKU $skuName is missing or ambiguous in region $Location." }
    $sku = $matches[0] | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    if (-not $sku.ContainsKey('properties')) { throw 'MDP SKU response is missing its properties.' }
    $properties = $sku.properties
    if (-not $properties.ContainsKey('restrictions') -or $null -eq $properties.restrictions) { throw 'MDP SKU restriction status is unknown.' }
    if (@($properties.restrictions).Count) { throw "MDP SKU $skuName has subscription/location restrictions; inspect the MDP SKU response before proceeding." }
    if ($properties.family -ine $family -or $Location -notin @($properties.locations)) { throw 'MDP SKU family or advertised locations differ from the requested baseline.' }
    $quotaMatches = @($UsageItems | Where-Object { $_.name.value -eq $family })
    if ($quotaMatches.Count -ne 1) { throw "MDP quota family $family is missing or ambiguous; no capacity is assumed." }
    $quota = $quotaMatches[0] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
    $limit = 0L
    $current = 0L
    if (-not [long]::TryParse([string]$quota.limit,[ref]$limit) -or -not [long]::TryParse([string]$quota.currentValue,[ref]$current) -or $limit -lt 0 -or $current -lt 0) { throw 'MDP quota values are invalid.' }
    $remaining = $limit - $current
    if ($remaining -lt 2) { throw "MDP quota has $remaining available cores in $family; this one-agent baseline requires 2." }
    return [pscustomobject]@{SkuName=$skuName;Family=$family;Location=$Location;RequiredCores=2;AvailableCores=$remaining}
}

function Get-LabMdpCapacity {
    param([Parameter(Mandatory)][guid]$SubscriptionId,[Parameter(Mandatory)][string]$Location)
    if ($SubscriptionId -eq [guid]::Empty -or $Location -notmatch '^[a-z0-9-]+$') { throw 'Invalid subscription or normalized Azure location.' }
    $baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.DevOpsInfrastructure/locations/$Location"
    $skus = @(Get-LabArmCollection -Uri "$baseUri/skus?api-version=2025-09-20")
    $usages = @(Get-LabArmCollection -Uri "$baseUri/usages?api-version=2025-09-20")
    Assert-LabMdpCapacity -SkuItems $skus -UsageItems $usages -Location $Location
}
function Write-LabEvidence {
    param([Parameter(Mandatory)]$Evidence, [string]$Path)
    if ($Path) {
        $parent = Split-Path ([IO.Path]::GetFullPath($Path)) -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $Evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8
    }
}

function Assert-LabPublicAddresses {
    param([Parameter(Mandatory)][string]$HostName,[Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Addresses)
    if (-not $Addresses.Count) { throw "No DNS addresses were returned for $HostName." }
    foreach ($address in $Addresses) {
        $ip = $null
        if (-not [Net.IPAddress]::TryParse($address,[ref]$ip)) { throw 'Public probe DNS returned an invalid address.' }
        $bytes = $ip.GetAddressBytes()
        if ($ip.AddressFamily -eq 'InterNetwork') {
            $nonPublic = $bytes[0] -in @(0,10,127) -or $bytes[0] -ge 224 -or
                ($bytes[0] -eq 100 -and $bytes[1] -ge 64 -and $bytes[1] -le 127) -or
                ($bytes[0] -eq 169 -and $bytes[1] -eq 254) -or
                ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or
                ($bytes[0] -eq 192 -and $bytes[1] -eq 168) -or
                ($bytes[0] -eq 192 -and $bytes[1] -eq 88 -and $bytes[2] -eq 99) -or
                ($bytes[0] -eq 192 -and $bytes[1] -eq 0 -and $bytes[2] -in @(0,2)) -or
                ($bytes[0] -eq 198 -and $bytes[1] -in @(18,19)) -or
                ($bytes[0] -eq 198 -and $bytes[1] -eq 51 -and $bytes[2] -eq 100) -or
                ($bytes[0] -eq 203 -and $bytes[1] -eq 0 -and $bytes[2] -eq 113)
        } else {
            # The lab tests IPv4 only. Conservatively refuse all IPv6 results
            # rather than misclassifying a special-purpose range as public.
            $nonPublic = $true
        }
        if ($nonPublic) { throw "$HostName does not resolve exclusively to public IPv4 addresses. This IPv4 lab conservatively refuses IPv6. Run the external probe from a public-network context with public DNS." }
    }
}

function Assert-LabPrivateEvidence {
    param([Parameter(Mandatory)]$Configuration,[Parameter(Mandatory)]$Evidence)
    $record = $Evidence | ConvertTo-Json -Depth 12 | ConvertFrom-Json -AsHashtable
    foreach ($key in @('lab_id','subscription_id','tenant_id','operator_principal_id','state_storage_account_name','state_container_name','key_vault_name')) {
        if (-not $record.ContainsKey($key) -or $record[$key] -cne $Configuration.$key) { throw "Private evidence does not match this operator/lab target: $key." }
    }
    $timestamp = [DateTimeOffset]::MinValue
    if (-not $record.ContainsKey('timestamp_utc') -or -not [DateTimeOffset]::TryParse([string]$record.timestamp_utc,[ref]$timestamp)) { throw 'Private evidence has no valid timestamp.' }
    $age = [DateTimeOffset]::UtcNow - $timestamp
    if ($age.TotalHours -gt 24 -or $age.TotalMinutes -lt -5) { throw 'Private evidence must be from the last 24 hours and not future-dated. Repeat the private positive tests.' }
    if (-not $record.ContainsKey('checks') -or -not $record.checks.ContainsKey('blob_read') -or -not $record.checks.ContainsKey('secret_read') -or $record.checks.blob_read -ne 'passed' -or $record.checks.secret_read -ne 'passed') { throw 'Private evidence must show successful authenticated Blob and secret reads; SkipSecretTests evidence is insufficient.' }
    foreach ($target in @(@("$($Configuration.state_storage_account_name).blob.core.windows.net",$Configuration.blob_private_ip),@("$($Configuration.key_vault_name).vault.azure.net",$Configuration.vault_private_ip))) {
        if (-not $record.checks.ContainsKey($target[0]) -or @($record.checks[$target[0]]).Count -ne 1 -or @($record.checks[$target[0]])[0] -ne $target[1]) { throw 'Private evidence does not contain the expected private endpoint DNS result.' }
    }
}

function Assert-LabPublicConfiguration {
    param([Parameter(Mandatory)]$Configuration)
    $storage = (Invoke-LabNative az @('storage','account','show','--name',$Configuration.state_storage_account_name,'--resource-group',$Configuration.foundation_resource_group_name,'--subscription',$Configuration.subscription_id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
    $vault = (Invoke-LabNative az @('keyvault','show','--name',$Configuration.key_vault_name,'--subscription',$Configuration.subscription_id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
    if ($storage.publicNetworkAccess -ne 'Disabled' -or $storage.allowSharedKeyAccess -ne $false -or $vault.properties.publicNetworkAccess -ne 'Disabled') { throw 'Storage/Key Vault public access or shared-key settings are not in the expected state.' }
}

function Invoke-LabAuthenticatedGet {
    param([Parameter(Mandatory)][ValidateSet('Blob','KeyVault')][string]$Service,
          [Parameter(Mandatory)]$Configuration)
    # Targets are derived from validated configuration; bearer tokens are never
    # arguments to another process, logs, evidence, or exception messages.
    if ($Service -eq 'Blob') {
        $audience = 'https://storage.azure.com/'
        $uri = "https://$($Configuration.state_storage_account_name).blob.core.windows.net/$($Configuration.state_container_name)?restype=container&comp=list&maxresults=1"
    } else {
        $audience = 'https://vault.azure.net'
        $uri = "https://$($Configuration.key_vault_name).vault.azure.net/secrets/lab-validation?api-version=7.4"
    }
    $token = (Invoke-LabNative az @('account','get-access-token','--resource',$audience,'--tenant',$Configuration.tenant_id,'--query','accessToken','--output','tsv','--only-show-errors')).Output.Trim()
    if (-not $token) { throw 'Azure CLI did not return a data-plane access token.' }
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $handler.AllowAutoRedirect = $false
    $http = [Net.Http.HttpClient]::new($handler)
    $http.Timeout = [TimeSpan]::FromSeconds(30)
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get,$uri)
    $request.Headers.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$token)
    if ($Service -eq 'Blob') {
        $request.Headers.Add('x-ms-version','2023-11-03')
        $request.Headers.Add('x-ms-date',[DateTime]::UtcNow.ToString('R',[Globalization.CultureInfo]::InvariantCulture))
    }
    $response = $null
    try {
        try { $response = $http.SendAsync($request,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult() }
        catch { throw 'Authenticated data-plane transport failed. DNS, timeout, TLS or local firewall failures do not prove service network denial.' }
        $result = [ordered]@{Service=$Service;StatusCode=[int]$response.StatusCode;ErrorCode='';InnerErrorCode=''}
        # Never read a successful secret response body.
        if (-not $response.IsSuccessStatusCode) {
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            if ($Service -eq 'Blob') {
                if ($response.Headers.Contains('x-ms-error-code')) { $result.ErrorCode = ($response.Headers.GetValues('x-ms-error-code') | Select-Object -First 1) }
                elseif ($body -match '<Code>([a-zA-Z0-9]+)</Code>') { $result.ErrorCode = $Matches[1] }
            } else {
                try {
                    $errorRecord = $body | ConvertFrom-Json -AsHashtable
                    if ($errorRecord.ContainsKey('error')) {
                        $result.ErrorCode = [string]$errorRecord.error.code
                        if ($errorRecord.error.ContainsKey('innererror')) { $result.InnerErrorCode = [string]$errorRecord.error.innererror.code }
                    }
                } catch { throw 'Key Vault returned an unrecognized error response; no negative-test pass can be recorded.' }
            }
            $body = $null
        }
        return [pscustomobject]$result
    } finally {
        $token = $null
        if ($response) { $response.Dispose() }
        $request.Dispose(); $http.Dispose(); $handler.Dispose()
    }
}

function Assert-LabNetworkDenial {
    param([Parameter(Mandatory)][ValidateSet('Blob','KeyVault')][string]$Service,
          [Parameter(Mandatory)][int]$StatusCode,[string]$ErrorCode,[string]$InnerErrorCode)
    if ($StatusCode -ne 403) { throw "$Service returned HTTP $StatusCode; an expected service network denial was not observed." }
    if ($Service -eq 'Blob' -and $ErrorCode -cne 'AuthorizationFailure') { throw 'Blob failed without the expected network AuthorizationFailure. Authentication or RBAC failures do not pass.' }
    if ($Service -eq 'KeyVault' -and ($ErrorCode -cne 'Forbidden' -or $InnerErrorCode -cnotin @('ForbiddenByConnection','ForbiddenByFirewall'))) { throw 'Key Vault failed without a network-specific inner error. Authentication or RBAC failures do not pass.' }
}

function Get-LabDeletedVault {
    param([Parameter(Mandatory)]$Configuration)
    $result = Invoke-LabNative az @('keyvault','show-deleted','--name',$Configuration.key_vault_name,'--location',$Configuration.location,'--subscription',$Configuration.subscription_id,'--output','json','--only-show-errors') -AllowedExitCodes @(0,1,2)
    if ($result.ExitCode -ne 0) {
        if ($result.Output -match '\b(DeletedVaultNotFound|VaultNotFound|ResourceNotFound)\b') { return [pscustomobject]@{Status='ABSENT';Name=$Configuration.key_vault_name} }
        throw 'The lab-specific deleted Key Vault record could not be queried. Cleanup verification is incomplete; permission or transport failures are not absence.'
    }
    $deleted = $result.Output | ConvertFrom-Json
    $expectedId = "/subscriptions/$($Configuration.subscription_id)/resourceGroups/$($Configuration.foundation_resource_group_name)/providers/Microsoft.KeyVault/vaults/$($Configuration.key_vault_name)"
    if ($deleted.name -ine $Configuration.key_vault_name -or $deleted.properties.vaultId -ine $expectedId) { throw 'Deleted vault response does not match the exact exported lab vault.' }
    [pscustomobject]@{Status='RETAINED';Name=$deleted.name;DeletionDate=$deleted.properties.deletionDate;ScheduledPurgeDate=$deleted.properties.scheduledPurgeDate}
}
function Test-LabCliExtensionInstalled {
    param([Parameter(Mandatory)][ValidateSet('log-analytics','azure-firewall')][string]$Name)
    # extension show is a core read-only command and does not trigger installation.
    $result = Invoke-LabNative az @('extension','show','--name',$Name,'--query','name','--output','tsv','--only-show-errors') -AllowedExitCodes @(0,1,2)
    return ($result.ExitCode -eq 0 -and $result.Output.Trim() -ceq $Name)
}
Export-ModuleMember -Function Invoke-LabNative,Assert-LabId,Assert-LabConfirmation,Get-LabConfiguration,Assert-LabSubscription,Assert-LabOwnership,Assert-LabWorkloadEmpty,Assert-LabOperator,Clear-LabCredentialEnvironment,Set-LabCliEnvironment,Assert-LabPrivateDns,Get-LabTerraform,Get-LabArmCollection,Assert-LabMdpCapacity,Get-LabMdpCapacity,Write-LabEvidence,Assert-LabPublicAddresses,Assert-LabPrivateEvidence,Assert-LabPublicConfiguration,Invoke-LabAuthenticatedGet,Assert-LabNetworkDenial,Get-LabDeletedVault,Test-LabCliExtensionInstalled
