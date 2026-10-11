[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string] $ServerName,
    [Parameter(Mandatory=$true)][string] $DatabaseName,
    [string] $UserName,
    [string] $Password,
    [switch] $DisableTrustServerCertificate,
    [string] $RootPath = (Join-Path $PSScriptRoot 'System'),
    [switch] $ShowPlan
)

$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Deploy.Common.ps1')
$plan=@(Get-DeployPlan -RootPath $RootPath -TestMode)
if ($ShowPlan) { $plan; return }
if ($plan.Count -eq 0) { Write-Host 'No tests folders found.'; return }
Import-Module SqlServer -ErrorAction Stop
$connectionString=New-DeployConnectionString $ServerName $DatabaseName $UserName $Password (-not $DisableTrustServerCertificate)
foreach ($step in $plan) {
    Write-Host "Testing $($step.SystemName): $($step.Path)"
    $variables=@("DatabaseName=$DatabaseName", "SystemName=$($step.SystemName.Replace("'", "''"))")
    Invoke-DeploySql $connectionString ([IO.File]::ReadAllText($step.Path)) $variables
}
Write-Host 'Tests completed.'
