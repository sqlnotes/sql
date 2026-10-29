[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string] $ServerName,
    [Parameter(Mandatory=$true)][string] $DatabaseName,
    [string] $UserName,
    [string] $Password,
    [switch] $DisableHashChecking,
    [switch] $DisableTrustServerCertificate,
    [string] $RootPath = (Join-Path $PSScriptRoot 'System'),
    [switch] $ShowPlan,
    [switch] $RunTests
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Deploy.Common.ps1')

# Validate the complete tree before any database modification.
$plan = if ($RunTests) { @(Get-DeployTestPlan -RootPath $RootPath) } else { @(Get-DeployPlan -RootPath $RootPath) }
if ($ShowPlan) { $plan; return }
if ([string]::IsNullOrWhiteSpace($DatabaseName) -or $DatabaseName.Length -gt 128 -or $DatabaseName -match "['\]\r\n\$\(\)]") {
    throw 'DatabaseName must be 1-128 characters and cannot contain SQLcmd substitution delimiters, quotes, closing brackets, or line breaks.'
}
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host 'Installing the SqlServer PowerShell module for the current user...'
    Install-Module -Name SqlServer -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
}
Import-Module SqlServer -ErrorAction Stop
$connectionString = New-DeployConnectionString $ServerName $DatabaseName $UserName $Password (-not $DisableTrustServerCertificate)
$bootstrapConnectionString = New-DeployConnectionString $ServerName 'master' $UserName $Password (-not $DisableTrustServerCertificate)
Invoke-Sqlcmd -ConnectionString $bootstrapConnectionString -InputFile (Join-Path $PSScriptRoot 'Deploy.sql') -Variable @("DatabaseName=$DatabaseName") -QueryTimeout 0 -AbortOnError -ErrorAction Stop

$connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
$contexts = [hashtable]::new([StringComparer]::Ordinal)
$currentContext = $null
try {
    $connection.Open()
    $null = Invoke-DeployProcedure $connection 'z.usp_AcquireDeploymentLock'
    $versions = [hashtable]::new([StringComparer]::Ordinal)
    foreach ($system in $plan | Where-Object { -not $RunTests -and $_.Kind -eq 'Begin' }) {
        # SQL resolves identity using its own trim/lower rules and collation.
        $table = Invoke-DeployProcedure $connection 'z.usp_GetDeploymentSystems' @{ '@CodeBase'=$system.SystemName }
        if ($table.Rows.Count -gt 0) { $versions[$system.SystemName] = $table.Rows[0].Version }
    }
    # Check every subsystem's installed version before running any product script.
    if (-not $RunTests) { $plan = @(Get-DeployPlan -RootPath $RootPath -InstalledVersions $versions) }

    foreach ($step in $plan) {
        switch ($step.Kind) {
            'Begin' {
                Write-Host "Deploying $($step.SystemName) -> $($step.Version)"
                $parameters = @{ '@CodeBase'=$step.SystemName; '@Version'=$step.Version }
                $batch = Invoke-DeployProcedure $connection 'z.usp_BeginDeployment' $parameters
                $systemID = [guid]$batch.Rows[0].SystemID
                $hashes = @{}
                $hashValues = @{}
                $successfulHashes = @{}
                if (-not $RunTests) {
                    $table = Invoke-DeployProcedure $connection 'z.usp_GetDeploymentHashes' @{ '@SystemID'=$systemID }
                    foreach ($row in $table.Rows) {
                        $key=([BitConverter]::ToString($row.FileHash)).Replace('-','')
                        $hashes[$key]=$false
                        $hashValues[$key]=$row.FileHash
                        if ($row.HasSucceeded) { $successfulHashes[$key]=$true }
                    }
                }
                $contexts[$step.SystemName]=@{ SystemID=$systemID; BatchID=[long]$batch.Rows[0].BatchID; Hashes=$hashes; HashValues=$hashValues; SuccessfulHashes=$successfulHashes; Step=$step; Completed=$false }
                $currentContext=$contexts[$step.SystemName]
            }
            'File' {
                $currentContext=$contexts[$step.SystemName]
                $content = [IO.File]::ReadAllText($step.Path)
                $hash = $null
                if (-not $RunTests) {
                    $sha256=[Security.Cryptography.SHA256]::Create()
                    try { $hash=$sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)) } finally { $sha256.Dispose() }
                    # Use value keys locally; SQL parameters carry the raw 32 bytes.
                    $hashKey=([BitConverter]::ToString($hash)).Replace('-','')
                    if ($step.HashAllowed -and -not $DisableHashChecking -and $currentContext.SuccessfulHashes.ContainsKey($hashKey)) {
                        $currentContext.Hashes[$hashKey]=$true
                        Write-Host "Skipped unchanged: $($step.Path)"
                        continue
                    }
                }
                $relativePath=[IO.Path]::GetRelativePath((Split-Path -Parent (Resolve-Path -LiteralPath $RootPath).Path), $step.Path).Replace('\','/')
                $logContent = $null
                $logFileName = $null
                if (-not $RunTests) { $logContent = Get-DeployLogContent $content; $logFileName = $relativePath }
                $logParameters=@{ '@BatchID'=$currentContext.BatchID; '@BatchLogID'=[long]-1; '@SystemID'=$currentContext.SystemID; '@SystemVersion'=$step.Version; '@FileHash'=$hash; '@FileName'=$logFileName; '@FileContent'=$logContent; '@ErrorMessage'=$null }
                $logProcedure='z.usp_CreateDatabaseUpdateLog'
                $result=Invoke-DeployProcedure $connection $logProcedure $logParameters
                $logParameters['@BatchLogID']=[long]$result.Rows[0].BatchLogID
                try {
                    Write-Host "Executing $relativePath"
                    $variables=@("DatabaseName=$DatabaseName", "SystemName=$($step.SystemName.Replace("'", "''"))")
                    Invoke-DeploySql $connectionString $content $variables
                    $logParameters['@FileHash']=$null; $logParameters['@FileName']=$null; $logParameters['@FileContent']=$null
                    $null=Invoke-DeployProcedure $connection $logProcedure $logParameters
                    if (-not $RunTests) { $currentContext.Hashes[$hashKey]=$true; $currentContext.HashValues[$hashKey]=$hash; $currentContext.SuccessfulHashes[$hashKey]=$true }
                }
                catch {
                    $failure=$_
                    $logParameters['@FileHash']=$null; $logParameters['@FileName']=$null; $logParameters['@FileContent']=$null
                    $logParameters['@ErrorMessage']=$failure.Exception.Message
                    try { $null=Invoke-DeployProcedure $connection $logProcedure $logParameters } catch { Write-Warning "Could not finish error log: $($_.Exception.Message)" }
                    throw $failure
                }
            }
            'End' {
                $currentContext=$contexts[$step.SystemName]
                # Baseline and older migrations leave the plan after a completed
                # version deployment; retain their successful hash history.
                $staleHashes=@($currentContext.Hashes.Keys | Where-Object { -not $currentContext.Hashes[$_] })
                foreach ($hashKey in $staleHashes) {
                    $null=Invoke-DeployProcedure $connection 'z.usp_RemoveDeploymentHash' @{ '@SystemID'=$currentContext.SystemID; '@FileHash'=$currentContext.HashValues[$hashKey] }
                }
                $null=Invoke-DeployProcedure $connection 'z.usp_CompleteDeployment' @{ '@SystemID'=$currentContext.SystemID; '@Version'=$step.Version; '@BatchID'=$currentContext.BatchID }
                Write-Host "Completed $($step.SystemName) at $($step.Version)"
                $currentContext.Completed=$true
            }
        }
    }
}
catch {
    $failure=$_
    # Active ancestors are also incomplete if a child fails. Completed siblings
    # keep their independently successful version records.
    foreach ($context in $contexts.Values | Where-Object { -not $_.Completed }) {
        try {
            $null=Invoke-DeployProcedure $connection 'z.usp_FailDeployment' @{ '@BatchID'=$context.BatchID }
        }
        catch { Write-Warning "Could not mark deployment failure: $($_.Exception.Message)" }
    }
    throw $failure
}
finally {
    if ($connection.State -eq [Data.ConnectionState]::Open) {
        try { $null=Invoke-DeployProcedure $connection 'z.usp_ReleaseDeploymentLock' } catch { Write-Warning 'Could not release deployment lock.' }
    }
    $connection.Dispose()
}
if ($RunTests) { Write-Host 'Tests completed.' } else { Write-Host 'Deployment completed.' }
