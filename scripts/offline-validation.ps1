#requires -Version 7.4
[CmdletBinding()]
param([switch]$RequireAllTools, [string]$TerraformPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$root = Split-Path $PSScriptRoot -Parent
$evidenceDirectory = Join-Path $root '.local/evidence'
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$checks = [Collections.Generic.List[object]]::new()
$versions = [ordered]@{ powershell = $PSVersionTable.PSVersion.ToString() }
$pins = Get-Content (Join-Path $root 'toolchain.json') -Raw | ConvertFrom-Json -AsHashtable
$snapshot = @{}
$checkpointBefore = [Environment]::GetEnvironmentVariable('CHECKPOINT_DISABLE','Process')
foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) {
    $snapshot[$key] = [Environment]::GetEnvironmentVariable($key,'Process')
}
function Invoke-OfflineNative {
    param([string]$File, [string[]]$Arguments, [int]$ExpectedExitCode = 0)
    $global:LASTEXITCODE = $null
    $output = @(& $File @Arguments 2>&1)
    if ($global:LASTEXITCODE -ne $ExpectedExitCode) {
        # Keep reports free of full plans, source excerpts and potential secret findings.
        throw "Expected exit $ExpectedExitCode; received $global:LASTEXITCODE. Rerun this check locally for diagnostics."
    }
    return ($output | ForEach-Object ToString) -join "`n"
}
function Add-OfflineCheck {
    param([string]$CheckName, [scriptblock]$Body, [string]$Missing)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $status = 'PASSED'
    $detail = 'Completed successfully.'
    if ($Missing) { $status = 'SKIPPED'; $detail = $Missing }
    else {
        try { $null = & $Body }
        catch { $status = 'FAILED'; $detail = $_.Exception.Message }
    }
    $watch.Stop()
    $checks.Add([pscustomobject]@{name=$CheckName;status=$status;detail=$detail;seconds=[Math]::Round($watch.Elapsed.TotalSeconds,2)})
    Write-Output "[$status] $CheckName — $detail"
}
function Resolve-OfflineTool {
    param([string]$Name, [string]$ExplicitPath, [string[]]$VersionArguments = @('--version'))
    $command = if ($ExplicitPath) { Get-Command $ExplicitPath -ErrorAction SilentlyContinue } else { Get-Command $Name -ErrorAction SilentlyContinue }
    if (-not $command) { return $null }
    $versionOutput = Invoke-OfflineNative $command.Source $VersionArguments
    $expected = $pins[$Name]
    if ($expected -match '^\d+\.\d+\.\d+$' -and $versionOutput -notmatch "(?<![\d.])v?$([regex]::Escape($expected))(?![\d.])") {
        throw "$Name must match toolchain.json version $expected."
    }
    if ($Name -eq 'python' -and $versionOutput -notmatch 'Python 3\.(8|9|[1-9][0-9])\.') { throw 'Python 3.8 or newer is required.' }
    $versions[$Name] = ($versionOutput -split "`n")[0].Trim()
    return $command.Source
}
Push-Location -LiteralPath $root
try {
    # Tests use mock providers. Do not let inherited CLI flags or credentials select a live backend.
    foreach ($key in $snapshot.Keys) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
    $env:TF_IN_AUTOMATION = 'true'
    $env:CHECKPOINT_DISABLE = '1'
    $available = @{}
    foreach ($name in @('terraform','python','tflint','trivy','gitleaks','conftest','terraform-docs')) {
        $explicit = if ($name -eq 'terraform') { $TerraformPath } else { '' }
        $versionArguments = if ($name -eq 'terraform') { @('version') } elseif ($name -eq 'gitleaks') { @('version') } else { @('--version') }
        $lookup = if ($explicit) { $explicit } else { $name }
        $unavailable = if (-not $RequireAllTools -and -not (Get-Command $lookup -ErrorAction SilentlyContinue)) { "$name is missing; this run will be INCOMPLETE. Nothing was installed." } else { '' }
        Add-OfflineCheck "tool:$name" {
            $available[$name] = Resolve-OfflineTool $name $explicit $versionArguments
            if (-not $available[$name]) { throw "$name is missing; install the pinned tool explicitly. Nothing was installed." }
        } $unavailable
    }
    function Missing-Tool([string]$Name) { if (-not $available.ContainsKey($Name) -or -not $available[$Name]) { return "Required tool $Name is unavailable or has the wrong version." }; return '' }
    Add-OfflineCheck 'terraform:format' { Invoke-OfflineNative $available.terraform @('fmt','-check','-recursive','-no-color') } (Missing-Tool terraform)
    foreach ($relative in @('.','workload')) {
        $directory = Join-Path $root $relative
        $testDirectory = if ($relative -eq '.') { 'tests/terraform' } else { 'tests' }
        Add-OfflineCheck "terraform:${relative}:init-validate-test" {
            Invoke-OfflineNative $available.terraform @("-chdir=$directory",'init','-backend=false','-input=false','-lockfile=readonly',"-test-directory=$testDirectory",'-no-color') | Out-Null
            Invoke-OfflineNative $available.terraform @("-chdir=$directory",'validate','-no-color') | Out-Null
            $result = Invoke-OfflineNative $available.terraform @("-chdir=$directory",'test',"-test-directory=$testDirectory",'-no-color')
            if ($result -notmatch 'Success! \d+ passed, 0 failed\.') { throw 'Terraform did not report a passing mocked test suite.' }
        } (Missing-Tool terraform)
    }
    Add-OfflineCheck 'pester:windows' {
        if (-not $IsWindows) { throw 'Windows execution is required for this Windows-first test suite.' }
        $module = Get-Module -ListAvailable Pester | Where-Object Version -EQ $pins.pester | Select-Object -First 1
        if (-not $module) { throw "Pester $($pins.pester) is required. Nothing was installed." }
        Invoke-OfflineNative (Join-Path $PSHOME 'pwsh.exe') @('-NoProfile','-NonInteractive','-File',(Join-Path $root 'tools/Invoke-PesterChecks.ps1'))
        $versions['pester'] = $pins.pester
    }
    Add-OfflineCheck 'python:validator-tests' { Invoke-OfflineNative $available.python @('-m','unittest','discover','-s','tests/tools','-v') } (Missing-Tool python)
    Add-OfflineCheck 'repository:markdown-links-svg-contracts' { Invoke-OfflineNative $available.python @('tools/validate_repository.py','--check','--anchors') } (Missing-Tool python)
    Add-OfflineCheck 'tflint' { Invoke-OfflineNative $available.tflint @('--recursive','--format','compact') } (Missing-Tool tflint)
    Add-OfflineCheck 'trivy:configuration' {
        Invoke-OfflineNative $available.trivy @('config','--severity','MEDIUM,HIGH,CRITICAL','--skip-check-update','--skip-version-check','--ignorefile','.trivyignore.yaml','--skip-dirs','.terraform','--skip-dirs','.local','--skip-dirs','tests','--skip-dirs','workload/tests','--exit-code','1','.')
    } (Missing-Tool trivy)
    Add-OfflineCheck 'gitleaks:source' { Invoke-OfflineNative $available.gitleaks @('dir','.','--config','.gitleaks.toml','--redact','--no-banner','--exit-code','1') } (Missing-Tool gitleaks)
    Add-OfflineCheck 'conftest:policy-tests' { Invoke-OfflineNative $available.conftest @('verify','--policy','policies') } (Missing-Tool conftest)
    Add-OfflineCheck 'conftest:positive-fixture' { Invoke-OfflineNative $available.conftest @('test','policies/fixtures/allowed.json','--policy','policies') } (Missing-Tool conftest)
    Add-OfflineCheck 'conftest:negative-fixture' { Invoke-OfflineNative $available.conftest @('test','policies/fixtures/denied.json','--policy','policies') 1 } (Missing-Tool conftest)
    Add-OfflineCheck 'documentation:generated-references' { & (Join-Path $PSScriptRoot 'generate-terraform-docs.ps1') -Check } (Missing-Tool terraform-docs)
    $checks.Add([pscustomobject]@{name='workflow-validation';status='NOT_APPLICABLE';detail='No pipeline or workflow definitions are included.';seconds=0})
    $git = Get-Command git -ErrorAction SilentlyContinue
    $commit = 'uncommitted'
    if ($git) {
        $resolved = @(& $git.Source rev-parse --verify HEAD 2>$null)
        if ($LASTEXITCODE -eq 0) { $commit = ($resolved -join '').Trim() }
    }
    $failures = @($checks | Where-Object status -EQ FAILED).Count
    $skipped = @($checks | Where-Object status -EQ SKIPPED).Count
    $status = if ($failures) { 'FAILED' } elseif ($skipped) { 'INCOMPLETE' } else { 'PASSED' }
    [ordered]@{timestamp_utc=[DateTime]::UtcNow.ToString('o');status=$status;source_commit=$commit;operating_system=[Runtime.InteropServices.RuntimeInformation]::OSDescription;tools=$versions;checks=$checks;azure_contacted=$false;live_validation='NOT_RUN'} |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'offline-validation.json') -Encoding utf8
    Write-Output "Offline validation: $status. Sanitized evidence: .local/evidence/offline-validation.json"
    if ($failures -or ($RequireAllTools -and $skipped)) { throw 'Offline validation did not pass; see the check summary above.' }
} finally {
    foreach ($key in @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -like 'ARM_*' -or $_ -like 'TF_*' })) { [Environment]::SetEnvironmentVariable($key,$null,'Process') }
    foreach ($key in $snapshot.Keys) { [Environment]::SetEnvironmentVariable($key,$snapshot[$key],'Process') }
    [Environment]::SetEnvironmentVariable('CHECKPOINT_DISABLE',$checkpointBefore,'Process')
    Pop-Location
}
