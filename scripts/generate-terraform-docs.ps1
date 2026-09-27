#requires -Version 7.4
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
if (-not (Get-Command terraform-docs -ErrorAction SilentlyContinue)) { throw 'terraform-docs 0.24.0 is required; install it explicitly before this command.' }
$version = (& terraform-docs --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch 'v0\.24\.0\b') { throw 'Expected terraform-docs 0.24.0.' }
$targets = @(@{Directory=$root;File='TERRAFORM.md';Title='Foundation Terraform reference'},@{Directory=(Join-Path $root 'workload');File='TERRAFORM.md';Title='Workload Terraform reference'})
foreach ($module in Get-ChildItem -LiteralPath (Join-Path $root 'modules') -Directory) {
    $targets += @{Directory=$module.FullName;File='README.md';Title=($module.Name + ' module')}
}
foreach ($target in $targets) {
    $generated = & terraform-docs markdown table --config (Join-Path $root '.terraform-docs.yml') $target.Directory 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('terraform-docs failed: ' + $target.Title) }
    $body = '# ' + $target.Title + "`n`nGenerated from Terraform source. Do not edit this reference manually.`n`n" + (($generated -join "`n").Trim()) + "`n"
    $path = Join-Path $target.Directory $target.File
    if ($Check) {
        if (-not (Test-Path -LiteralPath $path) -or (([IO.File]::ReadAllText($path) -replace "`r`n","`n") -ne $body)) { throw "Generated reference differs: $path" }
    } else { [IO.File]::WriteAllText($path,$body,[Text.UTF8Encoding]::new($false)) }
}
Write-Output ('Terraform references: ' + $(if ($Check) {'PASS'} else {'generated'}))
