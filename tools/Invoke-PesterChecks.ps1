#requires -Version 7.4
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Import-Module Pester -RequiredVersion 5.7.1 -Force
$configuration = New-PesterConfiguration
$configuration.Run.Path = @((Join-Path $root 'tests/powershell'),(Join-Path $root 'tests/workload'))
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $false
$result = Invoke-Pester -Configuration $configuration
$directory = Join-Path $root '.local/evidence'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
@{total=$result.TotalCount;passed=$result.PassedCount;failed=$result.FailedCount;skipped=$result.SkippedCount;result=[string]$result.Result;timestamp_utc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $directory 'pester-summary.json') -Encoding utf8
if ($result.FailedCount -gt 0 -or $result.PassedCount -eq 0 -or $result.SkippedCount -gt 0 -or $result.Result -ne 'Passed') { exit 1 }
