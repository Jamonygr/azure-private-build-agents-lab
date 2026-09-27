#requires -Version 7.4
[CmdletBinding()]
param([string]$ConfigPath = '.local/lab-config.json', [switch]$Execute,
      [string]$ProbeSubnetId, [string]$SourceIp, [string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Lab.Core.psm1') -Force -DisableNameChecking
$config = Get-LabConfiguration $ConfigPath
if (-not $Execute) { Write-Output 'Preview: verify this host subnet routes through the lab firewall, then correlate HTTP probes with firewall logs. This never validates an MDP job.'; return }
Assert-LabOperator $config
$evidence = [ordered]@{lab_id=$config.lab_id;timestamp_utc=[DateTime]::UtcNow.ToString('o');execution_context='operator-host';mdp_job_tested=$false;status='NOT_RUN'}
if (-not $ProbeSubnetId -or -not $SourceIp) {
    Write-LabEvidence -Path $EvidencePath -Evidence $evidence
    Write-Output 'NOT_RUN: supply -ProbeSubnetId and -SourceIp for an existing Windows validation host routed through this firewall. Private connectivity alone does not establish that route.'
    return
}
if (-not $IsWindows) { throw 'This host-route validation requires Windows.' }
foreach ($extensionName in @('azure-firewall','log-analytics')) {
    if (-not (Test-LabCliExtensionInstalled -Name $extensionName)) {
        $evidence.status = 'INCOMPLETE'
        $evidence.unavailable_extension = $extensionName
        Write-LabEvidence -Path $EvidencePath -Evidence $evidence
        Write-Output "INCOMPLETE: Azure CLI extension '$extensionName' is missing or could not be inspected. Install it deliberately with az extension add --name $extensionName, then rerun. No extension installation or network probe was attempted."
        return
    }
}
if ($ProbeSubnetId -notmatch "^/subscriptions/$([regex]::Escape($config.subscription_id))/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$") { throw 'ProbeSubnetId must be a subnet ARM ID in the selected subscription.' }
$address = [Net.IPAddress]::Parse($SourceIp)
if ($address.AddressFamily -ne 'InterNetwork') { throw 'SourceIp must be IPv4.' }
if ($SourceIp -notin @(Get-NetIPAddress -AddressFamily IPv4 | ForEach-Object IPAddress)) { throw 'SourceIp is not assigned to this Windows host.' }
$subnet = (Invoke-LabNative az @('network','vnet','subnet','show','--ids',$ProbeSubnetId,'--output','json','--only-show-errors')).Output | ConvertFrom-Json -AsHashtable
foreach ($delegation in @($subnet.delegations)) {
    if ($delegation -and $delegation.serviceName -eq 'Microsoft.DevOpsInfrastructure/pools') { throw 'Do not put a validation host in the exclusive MDP delegated subnet.' }
}
function Test-AddressInPrefix([string]$Ip,[string]$Prefix) {
    $parts = $Prefix.Split('/')
    if ($parts.Length -ne 2) { return $false }
    $prefixLength = [int]$parts[1]
    if ($prefixLength -lt 0 -or $prefixLength -gt 32) { return $false }
    $ipBytes = [Net.IPAddress]::Parse($Ip).GetAddressBytes()
    $networkBytes = [Net.IPAddress]::Parse($parts[0]).GetAddressBytes()
    if ($networkBytes.Length -ne 4) { return $false }
    for ($bit=0; $bit -lt $prefixLength; $bit++) {
        $index = [int][Math]::Floor($bit / 8)
        $mask = 1 -shl (7 - ($bit % 8))
        if (($ipBytes[$index] -band $mask) -ne ($networkBytes[$index] -band $mask)) { return $false }
    }
    return $true
}
$prefixes = @()
if ($subnet.ContainsKey('addressPrefix')) { $prefixes += $subnet.addressPrefix }
if ($subnet.ContainsKey('addressPrefixes')) { $prefixes += $subnet.addressPrefixes }
if (-not @($prefixes | Where-Object { Test-AddressInPrefix $SourceIp $_ }).Count) { throw 'SourceIp is outside the supplied subnet.' }
if (-not $subnet.routeTable -or -not $subnet.routeTable.id) { throw 'The validation subnet has no explicit route table.' }
$firewall = (Invoke-LabNative az @('network','firewall','show','--ids',$config.firewall_resource_id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
$firewallIp = $firewall.ipConfigurations[0].privateIPAddress
$routes = (Invoke-LabNative az @('network','route-table','show','--ids',$subnet.routeTable.id,'--output','json','--only-show-errors')).Output | ConvertFrom-Json
if (-not @($routes.routes | Where-Object { $_.addressPrefix -eq '0.0.0.0/0' -and $_.nextHopType -eq 'VirtualAppliance' -and $_.nextHopIpAddress -eq $firewallIp }).Count) { throw 'The validation subnet default route does not point to the selected lab firewall.' }
$started = [DateTime]::UtcNow
$handler = [Net.Http.HttpClientHandler]::new()
$handler.UseProxy = $false
$http = [Net.Http.HttpClient]::new($handler)
$http.Timeout = [TimeSpan]::FromSeconds(20)
try {
    $allowed = $http.GetAsync('https://management.azure.com/').GetAwaiter().GetResult()
    if ([int]$allowed.StatusCode -eq 470) { throw 'Allowed endpoint received a firewall denial.' }
    $allowed.Dispose()
    $blocked = $false
    try {
        $denied = $http.GetAsync('https://example.com/').GetAwaiter().GetResult()
        $blocked = ([int]$denied.StatusCode -eq 470)
        $denied.Dispose()
    } catch [Net.Http.HttpRequestException] { $blocked = $true }
      catch [Threading.Tasks.TaskCanceledException] { $blocked = $true }
    if (-not $blocked) { throw 'The unapproved HTTPS destination was reachable.' }
} finally { $http.Dispose(); $handler.Dispose() }
$resourceId = $config.firewall_resource_id.Replace("'","''")
$source = $SourceIp.Replace("'","''")
$startLiteral = $started.AddSeconds(-5).ToString('o')
$query = "AZFWApplicationRule | where TimeGenerated >= datetime($startLiteral) | where _ResourceId =~ '$resourceId' | where SourceIp == '$source' | where Fqdn =~ 'example.com' and Action =~ 'Deny' | project TimeGenerated, SourceIp, Fqdn, Action, _ResourceId | take 5"
$evidence.source_ip = $SourceIp
$evidence.probe_subnet_id = $ProbeSubnetId
$evidence.firewall_resource_id = $config.firewall_resource_id
$evidence.route_verified = $true
$evidence.allowed_transport = 'passed'
$evidence.denied_transport = 'observed'
$evidence.log_query = $query
# Log ingestion is asynchronous. A single bounded query is deliberate; rerun the
# query in evidence after ingestion rather than claiming a timeout proves denial.
$result = Invoke-LabNative az @('monitor','log-analytics','query','--workspace',$config.log_analytics_workspace_id,'--analytics-query',$query,'--output','json','--only-show-errors') -AllowedExitCodes @(0,1,2)
if ($result.ExitCode -ne 0) {
    $evidence.status = 'INCOMPLETE'
    Write-LabEvidence -Path $EvidencePath -Evidence $evidence
    Write-Output 'INCOMPLETE: transport denial observed but firewall logs could not be queried. An authorized operator must run the saved query; no MDP claim is made.'
    return
}
$logs = @($result.Output | ConvertFrom-Json)
if (-not $logs.Count) {
    $evidence.status = 'INCOMPLETE'
    Write-LabEvidence -Path $EvidencePath -Evidence $evidence
    Write-Output 'INCOMPLETE: no matching firewall deny log yet. Allow ingestion, then run the saved query and retain its matching event with the evidence.'
    return
}
$evidence.status = 'PASSED'
$evidence.deny_events = $logs
Write-LabEvidence -Path $EvidencePath -Evidence $evidence
Write-Output 'Operator-host egress check passed with a matching firewall deny event. MDP agent startup and job execution remain untested.'
