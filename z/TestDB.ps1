param (
    [Parameter(Mandatory=$true)]
    [string] $ServerName,
    [string] $DatabaseName,
    [string] $UserName = $null,
    [string] $Password = $null,
    [switch] $All = $false
)

Import-Module -Name SqlServer

function PrintInfo($object){
    Write-Host -Object $object
}
function PrintWarning($object){
    Write-Host -Object $object -ForegroundColor Yellow
}
function PrintError($object){
    Write-Host -Object $object -ForegroundColor Red
}
function PrintHighlight($object){
    Write-Host -Object $object -ForegroundColor Cyan
}
function PrintDataRows($object){
    if (-not($object -is [System.Data.DataRow[]])){
        return
    }
    $i = 0
    foreach ($row in $object) {
        $i++
        Write-Host -Object  "========== Row $i ==========" -ForegroundColor Yellow
        foreach ($column in $row.Table.Columns) {
            Write-Host -Object "$($column.ColumnName): " -ForegroundColor Cyan -NoNewline
            Write-Host -Object "$($row[$column.ColumnName])"
        }
        
    }   
}
function PrintObjectProperties($object){
    $properties = $object | Get-Member -MemberType Properties
    foreach ($property in $properties) {
        Write-Host -Object "$($property.Name): " -ForegroundColor Cyan -NoNewline
        Write-Host -Object "$($object.$($property.Name))"
    }
}

function PromptInput([string] $msg){
    Write-Host -Object $msg -ForegroundColor Yellow -NoNewline
    return Read-Host
}

class TestDatabase{
    [System.Data.SqlClient.SqlConnectionStringBuilder] $ConnectionStringBuilder
    [string] $ServerName
    [string] $DatabaseName
    [string] $UserName
    [string] $Password
    [bool] $RunAllTests

    [string] $CurrentFileName = ""
    [string] $CurrentFileNameShort = ""
    [string] $CurrentFileContent = ""
    [string] $BasePath = ""
    $Exception = $null

    TestDatabase([string] $serverName, [string] $databaseName, [string] $userName = $null, [string] $password = $null, [bool] $runAllTests = $false) {
        $this.ServerName = $serverName
        $this.DatabaseName = $databaseName
        $this.UserName = $userName
        $this.Password = $password
        $this.RunAllTests = $runAllTests
        $this.BasePath = (Get-Location).Path

        $this.ConnectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
        $this.ConnectionStringBuilder.psobject.Properties["ApplicationName"].Value = 'OmegaTester'
        $this.ConnectionStringBuilder.psobject.Properties["DataSource"].Value = $serverName
        $this.ConnectionStringBuilder.psobject.Properties["Encrypt"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["Enlist"].Value = $false
        $this.ConnectionStringBuilder.psobject.Properties["IntegratedSecurity"].Value =  [String]::IsNullOrEmpty($UserName)
        $this.ConnectionStringBuilder.psobject.Properties["Password"].Value = $password
        $this.ConnectionStringBuilder.psobject.Properties["PersistSecurityInfo"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["Pooling"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["TrustServerCertificate"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["UserID"].Value = $userName
        $this.ConnectionStringBuilder.psobject.Properties["InitialCatalog"].Value = $this.DatabaseName
    }
    [bool] IsUnitTestPath([string] $path){
        return  [bool]($($path -split '[\\/]') -match '^UnitTests?$')
    }
    [System.IO.DirectoryInfo[]] GetUnitTestRoots(){
        $roots = Get-ChildItem -Path $this.BasePath -Directory -Recurse |
            Where-Object { $_.Name -match '^UnitTests?$' }
        return $roots
    }

    [System.Data.DataRow[]] ExecuteSqlCmdQuery([string] $query){
        return Invoke-Sqlcmd -ConnectionString $this.ConnectionStringBuilder.ConnectionString -Query $query -QueryTimeout 0 -AbortOnError -OutputAs DataRows
    }
    [System.Data.DataRow[]] ExecuteSqlCmdFile([string] $filePath){
        return Invoke-Sqlcmd -ConnectionString $this.ConnectionStringBuilder.ConnectionString -InputFile $filePath -QueryTimeout 0 -AbortOnError -OutputAs DataRows
    }
    [void] ExecuteFile([string] $fileName){
        try{
            $this.CurrentFileName = $fileName
            $this.CurrentFileNameShort = $fileName -replace "(?i)$([regex]::Escape($PSScriptRoot))", "."
            if(-not $this.IsUnitTestPath($fileName)){
                #PrintInfo "Skip $($this.CurrentFileNameShort)..."
                return
            }
            PrintInfo "$($this.CurrentFileNameShort)..."
            $this.CurrentFileContent = Get-Content -Path $fileName -Raw
            $pre  = "set textsize 2147483647
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on
set transaction isolation level read committed
set context_info 0x446F6E742774204B696C6C
if @@trancount > 0 
    raiserror('There are open transaction before file execution', 16, 1)
go
"
            $post = "
go
if @@trancount > 0 
    raiserror('There are open transaction after file execution', 16, 1)
"
            $ret = $this.ExecuteSqlCmdQuery($pre + $this.CurrentFileContent + $post)
            PrintDataRows($ret)
        }
        catch {
            $this.Exception = $_
            throw $this.Exception
            exit 1
        }
    }
    [void] ExecuteFolder([string] $folder){
        if(-not (Test-Path $folder)){
            return
        }
        $this.ExecuteFolder($(Join-Path -Path $folder -ChildPath "PreScripts"))

        foreach($d in Get-ChildItem -Path $folder -Directory | Where-Object { $_.Name -ne 'PreScripts' -and $_.Name -ne 'PostScripts' } | Sort-Object {[System.Text.Encoding]::UTF8.GetBytes($_.BaseName.ToLower())|ForEach-Object ToString X4}){
            $this.ExecuteFolder($d.FullName)
        }
        foreach($f in Get-ChildItem -Path $folder -File -Filter "*.sql" | Sort-Object {[System.Text.Encoding]::UTF8.GetBytes($_.BaseName.ToLower())|ForEach-Object ToString X4}){
            $this.ExecuteFile($f.FullName)
        }
        $this.ExecuteFolder($(Join-Path -Path $folder -ChildPath "PostScripts"))
    }
    [void] RunTests(){
        $unitTestRoots = $this.GetUnitTestRoots()
        if($unitTestRoots.Count -eq 0){
            PrintWarning "Could not find any UnitTests folders under $($this.BasePath)"
            return
        }

        PrintHighlight "Running tests under: $($this.BasePath)"
        foreach($root in $unitTestRoots){
            $this.ExecuteFolder($root.FullName)
        }
        if($this.RunAllTests){
            [System.Data.DataRow[]] $ETLs = $this.ExecuteSqlCmdQuery("exec maint.usp_GetETLDeploymentInfo") 
            if($ETLs.Length -eq 0){
                return
            }
            PrintInfo "============================================================================"
            PrintHighlight "Test ETL..."
            foreach ($etl in $ETLs ){
                if($etl["IsActive"]){
                    $etlBasePath = Join-Path -Path $PSScriptRoot -ChildPath $etl["ETLCodeBase"]
                    if(-not (Test-Path $etlBasePath)){
                        PrintWarning "ETL code base not found: $etlBasePath"
                        continue
                    }
                    Push-Location -Path $etlBasePath
                    try{
                        $([TestDatabase]::new($etl["ServerName"], $etl["DatabaseName"], $etl["UserName"], $etl["Password"], $true)).RunTests()
                    }
                    finally{
                        Pop-Location
                    }
                }
            }
        }
    }
}

 $([TestDatabase]::new($ServerName, $DatabaseName, $UserName, $Password, $All)).RunTests()
