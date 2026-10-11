# Shared traversal and connection helpers for deployment and test execution.
Set-StrictMode -Version Latest

function Get-DeployChildren {
    param([string] $Path, [switch] $Files)
    $items = if ($Files) { @(Get-ChildItem -LiteralPath $Path -File -Filter '*.sql') } else { @(Get-ChildItem -LiteralPath $Path -Directory) }
    $names = [string[]]@($items | ForEach-Object Name)
    [Array]::Sort($names, [StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $names) { $items | Where-Object Name -CEQ $name }
}

function Get-DeployPlan {
    param([string] $RootPath, [hashtable] $InstalledVersions = @{}, [switch] $TestMode)
    $reserved = @('pre', 'baseline', 'versions', 'modules', 'post', 'tests', 'docs')
    $steps = [System.Collections.Generic.List[object]]::new()
    $root = Get-Item -LiteralPath $RootPath -ErrorAction Stop
    if (-not $root.PSIsContainer) { throw 'RootPath must be a directory.' }
    $activePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    function Add-PlanFolder {
        param($Folder, [string] $SystemName, [bool] $IsSystem, [string] $Phase, [string] $Version, [bool] $HashAllowed, [bool] $VersionContainer=$false)
        if ($Folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw "Linked folders are not supported: $($Folder.FullName)" }
        if (-not $activePaths.Add($Folder.FullName)) { throw "Recursive folder path: $($Folder.FullName)" }
        try {
            $current = if ($InstalledVersions.ContainsKey($SystemName)) { [version]$InstalledVersions[$SystemName] } else { [version]'0.0.0' }
            $target = $current
            if ($IsSystem) {
                if ($SystemName.Length -gt 4000) { throw "Subsystem path exceeds 4000 characters: $SystemName" }
                $versionPath = Join-Path $Folder.FullName 'versions'
                if (Test-Path -LiteralPath $versionPath -PathType Container) {
                    $versionDirs = @(Get-DeployChildren $versionPath | Where-Object { $_.Name -notin $reserved })
                    foreach ($directory in $versionDirs) {
                        $parsed = $null
                        if (-not [version]::TryParse($directory.Name, [ref]$parsed)) { throw "Invalid version folder: $($directory.FullName)" }
                    }
                    if ($versionDirs.Count -gt 0) {
                        $target = ($versionDirs | ForEach-Object { [version]$_.Name } | Sort-Object | Select-Object -Last 1)
                        if (-not $TestMode -and $target -lt $current) { throw "Downgrade rejected for ${SystemName}: installed $current, available $target." }
                    }
                }
                $Version = $target.ToString()
                if (-not $TestMode) { $steps.Add([pscustomobject]@{ Kind='Begin'; SystemName=$SystemName; Version=$Version; Path=$Folder.FullName; Phase='system'; HashAllowed=$false }) }
                else {
                    $testPath = Join-Path $Folder.FullName 'tests'
                    if (Test-Path -LiteralPath $testPath -PathType Container) { Add-PlanFolder (Get-Item -LiteralPath $testPath) $SystemName $false 'tests' $Version $false }
                    foreach ($child in Get-DeployChildren $Folder.FullName | Where-Object { $_.Name -notin $reserved }) {
                        Add-PlanFolder $child "$SystemName/$($child.Name)" $true 'system' '0.0.0' $true
                    }
                    return
                }
            }

            foreach ($stage in @('pre', 'baseline', 'versions', 'modules')) {
                $stagePath = Join-Path $Folder.FullName $stage
                if (-not (Test-Path -LiteralPath $stagePath -PathType Container)) { continue }
                # Baseline is the foundation before the first completed version.
                # Skip the entire subtree, including its own pre/post stages.
                if (-not $TestMode -and $stage -eq 'baseline' -and $current -gt [version]'0.0.0') { continue }
                $stageHash = $HashAllowed -and $stage -ne 'pre'
                if ($stage -eq 'versions') {
                    Add-PlanFolder (Get-Item -LiteralPath $stagePath) $SystemName $false $stage $Version $stageHash $true
                }
                else { Add-PlanFolder (Get-Item -LiteralPath $stagePath) $SystemName $false $stage $Version $stageHash }
            }
            foreach ($file in Get-DeployChildren $Folder.FullName -Files) {
                $steps.Add([pscustomobject]@{ Kind='File'; SystemName=$SystemName; Version=$Version; Path=$file.FullName; Phase=$Phase; HashAllowed=$HashAllowed })
            }
            $children=@(Get-DeployChildren $Folder.FullName | Where-Object { $_.Name -notin $reserved })
            if ($VersionContainer) {
                foreach ($child in $children) {
                    $parsed=$null
                    if (-not [version]::TryParse($child.Name, [ref]$parsed)) { throw "Invalid version folder: $($child.FullName)" }
                }
                foreach ($child in $children | Sort-Object { [version]$_.Name }) {
                    if ($TestMode -or [version]$child.Name -ge $current) { Add-PlanFolder $child $SystemName $false $Phase $child.Name $HashAllowed }
                }
            }
            else { foreach ($child in $children) {
                Add-PlanFolder $child $(if ($IsSystem) { "$SystemName/$($child.Name)" } else { $SystemName }) $IsSystem $Phase $Version $HashAllowed
            } }
            $postPath = Join-Path $Folder.FullName 'post'
            if (Test-Path -LiteralPath $postPath -PathType Container) { Add-PlanFolder (Get-Item -LiteralPath $postPath) $SystemName $false 'post' $Version $false }
            if ($IsSystem) { $steps.Add([pscustomobject]@{ Kind='End'; SystemName=$SystemName; Version=$Version; Path=$Folder.FullName; Phase='system'; HashAllowed=$false }) }
        }
        finally { $null = $activePaths.Remove($Folder.FullName) }
    }
    function Find-PlanTests {
        param($Folder, [string] $SystemName, [bool] $IsSystem)
        if ($Folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked folders are not supported: $($Folder.FullName)" }
        $testsPath=Join-Path $Folder.FullName 'tests'
        if (Test-Path -LiteralPath $testsPath -PathType Container) { Add-PlanFolder (Get-Item -LiteralPath $testsPath) $SystemName $false 'tests' '0.0.0' $false }
        foreach ($child in Get-DeployChildren $Folder.FullName | Where-Object { $_.Name -notin @('tests', 'docs') }) {
            $childIsSystem=$IsSystem -and $child.Name -notin $reserved
            $childName=if ($childIsSystem) { "$SystemName/$($child.Name)" } else { $SystemName }
            Find-PlanTests $child $childName $childIsSystem
        }
    }
    if ($TestMode) { Find-PlanTests $root "/$($root.Name)" $true }
    else { Add-PlanFolder $root "/$($root.Name)" $true 'system' '0.0.0' $true }
    $steps.ToArray()
}

function Get-DeployTestPlan {
    param([string] $RootPath)
    $files = @(Get-DeployPlan -RootPath $RootPath -TestMode)
    $first = [hashtable]::new([StringComparer]::Ordinal)
    $last = [hashtable]::new([StringComparer]::Ordinal)
    for ($index = 0; $index -lt $files.Count; $index++) {
        $owner = $files[$index].SystemName
        if (-not $first.ContainsKey($owner)) { $first[$owner] = $index }
        $last[$owner] = $index
    }
    for ($index = 0; $index -lt $files.Count; $index++) {
        $file = $files[$index]
        if ($first[$file.SystemName] -eq $index) {
            [pscustomobject]@{ Kind='Begin'; SystemName=$file.SystemName; Version='Test'; Path=$file.Path; Phase='tests'; HashAllowed=$false }
        }
        $file.Version = 'Test'
        $file
        if ($last[$file.SystemName] -eq $index) {
            [pscustomobject]@{ Kind='End'; SystemName=$file.SystemName; Version='Test'; Path=$file.Path; Phase='tests'; HashAllowed=$false }
        }
    }
}

function New-DeployConnectionString {
    param([string] $ServerName, [string] $DatabaseName, [string] $UserName, [string] $Password, [bool] $TrustServerCertificate)
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder.psobject.Properties['DataSource'].Value = $ServerName
    $builder.psobject.Properties['InitialCatalog'].Value = $DatabaseName
    $builder.psobject.Properties['IntegratedSecurity'].Value = [string]::IsNullOrEmpty($UserName)
    if (-not [string]::IsNullOrEmpty($UserName)) {
        $builder.psobject.Properties['UserID'].Value=$UserName
        $builder.psobject.Properties['Password'].Value=$Password
    }
    $builder.psobject.Properties['Encrypt'].Value = $true
    $builder.psobject.Properties['TrustServerCertificate'].Value = $TrustServerCertificate
    $builder.psobject.Properties['PersistSecurityInfo'].Value = $false
    $builder.psobject.Properties['ConnectTimeout'].Value = 15
    $builder.psobject.Properties['ApplicationName'].Value = 'SchemaZ.Deploy'
    $builder.ConnectionString
}

function Invoke-DeployMetadata {
    param([System.Data.SqlClient.SqlConnection] $Connection, [string] $Query, [hashtable] $Parameters = @{}, [System.Data.CommandType] $CommandType = [System.Data.CommandType]::Text)
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText=$Query; $command.CommandType=$CommandType; $command.CommandTimeout=30
        foreach ($name in $Parameters.Keys) {
            $value = $Parameters[$name]
            if ($CommandType -eq [System.Data.CommandType]::StoredProcedure) {
                $parameter = switch ($name) {
                    { $_ -in '@BatchID', '@BatchLogID' } { $command.Parameters.Add($name, [System.Data.SqlDbType]::BigInt) }
                    '@CodeBase' { $command.Parameters.Add($name, [System.Data.SqlDbType]::NVarChar, 4000) }
                    '@SystemID' { $command.Parameters.Add($name, [System.Data.SqlDbType]::UniqueIdentifier) }
                    { $_ -in '@Version', '@SystemVersion' } { $command.Parameters.Add($name, [System.Data.SqlDbType]::VarChar, 100) }
                    '@FileHash' { $command.Parameters.Add($name, [System.Data.SqlDbType]::VarBinary, 32) }
                    default { $command.Parameters.Add($name, [System.Data.SqlDbType]::NVarChar, -1) }
                }
                if ($Query -eq 'z.usp_CreateDatabaseUpdateLog' -and $name -in '@BatchID', '@BatchLogID') {
                    $parameter.Direction = [System.Data.ParameterDirection]::InputOutput
                }
            }
            else {
                $parameter = if ($value -is [byte[]]) { $command.Parameters.Add($name, [System.Data.SqlDbType]::VarBinary, -1) } elseif ($value -is [guid]) { $command.Parameters.Add($name, [System.Data.SqlDbType]::UniqueIdentifier) } elseif ($value -is [long] -or $value -is [int]) { $command.Parameters.Add($name, [System.Data.SqlDbType]::BigInt) } else { $command.Parameters.Add($name, [System.Data.SqlDbType]::NVarChar, -1) }
            }
            if ($null -eq $value) { $parameter.Value = [DBNull]::Value }
            else { $parameter.Value = $value }
        }
        $table = [System.Data.DataTable]::new()
        $adapter = [System.Data.SqlClient.SqlDataAdapter]::new($command)
        try { $null=$adapter.Fill($table) } finally { $adapter.Dispose() }
        return ,$table
    }
    finally { $command.Dispose() }
}

function Invoke-DeployProcedure {
    param([System.Data.SqlClient.SqlConnection] $Connection, [string] $Procedure, [hashtable] $Parameters = @{})
    Invoke-DeployMetadata $Connection $Procedure $Parameters -CommandType StoredProcedure
}

function Get-DeployLogContent {
    param([string] $Content)
    # Mask before metadata RPC: server-side masking cannot protect the request.
    if ($Content -match '(?i)password|encryption') { return '***' }
    return $Content
}

function Invoke-DeploySql {
    param([string] $ConnectionString, [string] $Query, [string[]] $Variables = @())
    # sqlcmd expands the complete string before SQL runs. Reject unresolved mode
    # in the bootstrap; all scripts share the same pre/post transaction guards.
    $prefix = @'
set nocount, xact_abort on;
set textsize 2147483647;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on;
set transaction isolation level read committed;
set context_info 0x73716C6E6F7465732E696E666F;
if @@trancount > 0 throw 51000, 'Open transaction before script execution.', 1;
go
'@
    $suffix = @'

go
if @@trancount > 0
begin
    rollback;
    throw 51000, 'Open transaction after script execution.', 1;
end
'@
    Invoke-Sqlcmd -ConnectionString $ConnectionString -Query ($prefix + "`r`n" + $Query + $suffix) -Variable $Variables -QueryTimeout 0 -AbortOnError -ErrorAction Stop
}
