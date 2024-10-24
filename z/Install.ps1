param (
    [Parameter(Mandatory=$true)]
    [string] $ServerName,
    [string] $DatabaseName,
    [string] $UserName = $null,
    [string] $Password = $null
    
)
$OriginalVerbosePreference = $VerbosePreference 
if (!(Get-Module -ListAvailable -Name SqlServer)) {
    $VerbosePreference = "SilentlyContinue"
    Write-Output "SqlServer module not found. Installing..."
    Install-Module -Name SqlServer -Force -AllowClobber
}
Import-Module -Name SqlServer

class SystemDeployment {
    
    [System.Data.SqlClient.SqlConnectionStringBuilder] $ConnectionStringBuilder
    [System.Data.SqlClient.SqlConnection] $ManagementConnection
    [string] $SystemName
    [string] $DatabaseName  
    
    [Version] $SystemVersionBeforeMigration
    [Version] $SystemVersionCurrent
    [Version] $MaxFolderVersion

    [System.Int64] $BatchID = -1
    [System.Int64] $BatchLogID = -1

    [string] $CurrentFileName = ""
    [string] $CurrentFileNameShort = ""
    [string] $CurrentFileContent = ""
    [string] $CurrentFileHash = ""
    $Exception = $null
   
    [System.IO.FileSystemInfo[]] $VersionFolders
    [System.IO.FileSystemInfo] $SystemPath


    $SqlCmdParameters = @()
    $HashTable = @{}
    [bool] $CheckHashInternal = $true
    [bool] $DisableHashChecking = $false

    [bool] $ShowQuestion = $true
    SystemDeployment([string] $serverName, [string] $databaseName, [string] $userName, [string] $password, [string] $systemName, [bool] $disableHashChecking = $false){

        $this.ConnectionStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
        $this.ConnectionStringBuilder.psobject.Properties["ApplicationName"].Value = 'installer.sqlnotes.info'
        $this.ConnectionStringBuilder.psobject.Properties["DataSource"].Value = $serverName
        $this.ConnectionStringBuilder.psobject.Properties["Encrypt"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["Enlist"].Value = $false
        $this.ConnectionStringBuilder.psobject.Properties["IntegratedSecurity"].Value =  [String]::IsNullOrEmpty($UserName)
        $this.ConnectionStringBuilder.psobject.Properties["Password"].Value = $password
        $this.ConnectionStringBuilder.psobject.Properties["PersistSecurityInfo"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["Pooling"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["TrustServerCertificate"].Value = $true
        $this.ConnectionStringBuilder.psobject.Properties["UserID"].Value = $userName

        $this.SystemName = $SystemName        
        $this.DatabaseName = $databaseName
        $this.DisableHashChecking = $disableHashChecking
        $this.BuildSqlCmdParammeters()
        $this.MaxFolderVersion = [System.Version]::new("0.0.0")
        $this.SystemPath = Get-Item -Path $(Join-Path -Path $PSScriptRoot -ChildPath $this.SystemName)
    }
    
    [void] BuildSqlCmdParammeters(){
        $this.SqlCmdParameters = @("DatabaseName=$($this.DatabaseName)", "SystemName=$($this.SystemName)")
    }
    [void] ChangeDatabase([string] $dbname){
        $this.ConnectionStringBuilder.psobject.Properties["InitialCatalog"].Value = $dbname
    }
    [void] PrintInfo($object){
        Write-Host -Object $object
    }
    [void] PrintWarning($object){
        Write-Host -Object $object -ForegroundColor Yellow
    }
    [void] PrintError($object){
        Write-Host -Object $object -ForegroundColor Red
    }
    [void] PrintHighlight($object){
        Write-Host -Object $object -ForegroundColor Cyan
    }

    [void] PrintDataRows($object){
        if (-not($object -is [System.Data.DataRow[]])){
            return
        }
        $i = 0
        foreach ($row in $object) {
            $i++
            Write-Host -Object  "==================== Row $i ====================" -ForegroundColor Yellow
            foreach ($column in $row.Table.Columns) {
                Write-Host -Object "$($column.ColumnName): " -ForegroundColor Yellow -NoNewline
                Write-Host -Object "$($row[$column.ColumnName])"
            }
            
        }   
    }
    [void] PrintObjectProperties($object){
        $properties = $object | Get-Member -MemberType Properties
        foreach ($property in $properties) {
            Write-Host -Object "$($property.Name): " -ForegroundColor Cyan -NoNewline
            Write-Host -Object "$($object.$($property.Name))"
        }
    }
    [void] Initialize(){
        $path = Join-Path -Path $PSScriptRoot -ChildPath "Install.sql"
        $rows = $this.ExecuteSqlCmdFile($path)

        $this.DatabaseName = $rows[0][0]
        $this.SystemVersionBeforeMigration = [Version]::new($rows[0][1])
        $this.SystemVersionCurrent = $this.SystemVersionBeforeMigration.Clone()
        $this.BuildSqlCmdParammeters()
        $this.ChangeDatabase($this.DatabaseName)

        $this.ManagementConnection = [System.Data.SqlClient.SqlConnection]::new()
        $this.ManagementConnection.ConnectionString = $this.ConnectionStringBuilder.ConnectionString
        
        $this.MaxFolderVersion = [System.Version]::new(0,0,0,0)
        $this.VersionFolders = Get-ChildItem -Path $this.SystemPath -Directory | 
            Where-Object {
                $version = [System.Version]::new(0,0,0,0)
                $isVersion = [System.Version]::TryParse($_.Name, [ref]$version)
                if($this.MaxFolderVersion -le $version){
                    $this.MaxFolderVersion = $version
                }
                $isVersion -and $version -ge $this.SystemVersionCurrent
            }|
                Sort-Object {
                    $version = [System.Version]::new(0,0,0,0)
                    [System.Version]::TryParse($_.Name, [ref]$version)
                    $version
                } 
        if($this.MaxFolderVersion -lt $this.SystemVersionCurrent){
            Write-Error "Could not downgrade $($this.SystemName) from verion $($this.SystemVersionCurrent.ToString()) to $($this.MaxFolderVersion.ToString())."
            exit(1)
        }
        $this.ReadHashFromDB()
    }
    [System.Data.DataRow[]] ExecuteSqlCmdQuery([string] $query){
        return Invoke-Sqlcmd -ConnectionString $this.ConnectionStringBuilder.ConnectionString -Query $query -QueryTimeout 0 -AbortOnError -OutputAs DataRows -Variable $this.SqlCmdParameters
    }
    [System.Data.DataRow[]] ExecuteSqlCmdFile([string] $filePath){
        return Invoke-Sqlcmd -ConnectionString $this.ConnectionStringBuilder.ConnectionString -InputFile $filePath -QueryTimeout 0 -AbortOnError -OutputAs DataRows -Variable $this.SqlCmdParameters
    }
    [void] ReadFile([string] $path){
        $this.CurrentFileName = $path
        $this.CurrentFileNameShort = $path -replace "(?i)$([regex]::Escape($PSScriptRoot))", "."
        $this.CurrentFileContent = Get-Content -Path $path -Raw
        $this.CurrentFileHash = $null
        if($this.CheckHashInternal){
            $this.CurrentFileHash = ([System.Security.Cryptography.HashAlgorithm]::Create("MD5").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($this.CurrentFileContent))
                                         | foreach-object { $_.ToString("x2") }
                                    ).ToLower() -join ""
            
        }
    }
    [void] ReadHashFromDB(){
        $this.ManagementConnection.Open()
        $cmd = $this.ManagementConnection.CreateCommand()
        $cmd.CommandType = [System.Data.CommandType]::Text
        $cmd.CommandText = "select FileHash from z.SystemScriptHash where SystemName = '$($this.SystemName)'"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $this.HashTable[($reader["FileHash"].ToString()).ToLower()] = $false
        }
        $reader.Close()
        $this.ManagementConnection.Close()
    }
    [void] WriteHashToDB()
    {
        $this.ManagementConnection.Open()
        $cmd = $this.ManagementConnection.CreateCommand()
        $cmd.CommandType = [System.Data.CommandType]::Text
        $cmd.CommandText = "delete b from string_split(@Hashes, ',') a inner loop join z.SystemScriptHash b on b.SystemName = @SystemName and FileHash = cast(a.value as varchar(256))"
        $cmd.Parameters.Add("@SystemName", [System.Data.SqlDbType]::VarChar, 128).Value = $this.SystemName;
        $cmd.Parameters.Add("@Hashes", [System.Data.SqlDbType]::VarChar, -1).Value = ($this.HashTable.GetEnumerator() | Where-object {-not $_.Value} | Select-Object -ExpandProperty Key) -join ","
        $cmd.ExecuteNonQuery()
        $this.ManagementConnection.Close()

    }
    [void] WriteLogStart(){
        $this.ManagementConnection.Open()
        $this.Exception = $null
        [string] $query = $this.CurrentFileContent
        if($query -ilike "*password*" -or $query -ilike "*encryption*"){
            $query = "***"
        }
        $cmd = $this.ManagementConnection.CreateCommand()
        $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
        $cmd.CommandText = "z.CreateDatabaseUpdateLog"
        $cmd.Parameters.Add("@BatchID", [System.Data.SqlDbType]::BigInt).Direction = [System.Data.ParameterDirection]::InputOutput
        $cmd.Parameters.Add("@BatchLogID", [System.Data.SqlDbType]::BigInt).Direction = [System.Data.ParameterDirection]::InputOutput
        $cmd.Parameters.Add("@SystemName", [System.Data.SqlDbType]::VarChar, 128).Value = $this.SystemName;
        $cmd.Parameters.Add("@SystemVersion", [System.Data.SqlDbType]::VarChar, 100).Value = $this.SystemVersionCurrent.ToString()
        $cmd.Parameters.Add("@FileHash", [System.Data.SqlDbType]::VarChar, 100).Value = $this.CurrentFileHash
        $cmd.Parameters.Add("@FileName", [System.Data.SqlDbType]::NVarChar, -1).Value = $this.CurrentFileNameShort
        $cmd.Parameters.Add("@FileContent", [System.Data.SqlDbType]::NVarChar, -1).Value = $query
        $cmd.Parameters.Add("@ErrorMessage", [System.Data.SqlDbType]::NVarChar, -1).Value = $null
        $cmd.Parameters["@BatchID"].Value = $this.BatchID
        $cmd.Parameters["@BatchLogID"].Value = -1
        $cmd.ExecuteNonQuery()
        $this.BatchID = $cmd.Parameters["@BatchID"].Value
        $this.BatchLogID = $cmd.Parameters["@BatchLogID"].Value
        $this.ManagementConnection.Close()
    }
    [void] WriteLogEnd(){
        $this.ManagementConnection.Open()
        $cmd = $this.ManagementConnection.CreateCommand()
        $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
        $cmd.CommandText = "z.CreateDatabaseUpdateLog"
        $cmd.Parameters.Add("@BatchID", [System.Data.SqlDbType]::BigInt).Direction = [System.Data.ParameterDirection]::InputOutput
        $cmd.Parameters.Add("@BatchLogID", [System.Data.SqlDbType]::BigInt).Direction = [System.Data.ParameterDirection]::InputOutput
        $cmd.Parameters.Add("@SystemName", [System.Data.SqlDbType]::VarChar, 128).Value = $this.SystemName;
        $cmd.Parameters.Add("@SystemVersion", [System.Data.SqlDbType]::VarChar, 100).Value = $this.SystemVersionCurrent.ToString()
        $cmd.Parameters.Add("@FileHash", [System.Data.SqlDbType]::VarChar, 100).Value = $null
        $cmd.Parameters.Add("@FileName", [System.Data.SqlDbType]::NVarChar, -1).Value = $null
        $cmd.Parameters.Add("@FileContent", [System.Data.SqlDbType]::NVarChar, -1).Value = $null
        $cmd.Parameters.Add("@ErrorMessage", [System.Data.SqlDbType]::NVarChar, -1).Value = ($null -eq $this.Exception) ? $null : $this.Exception.ToString()

        $cmd.Parameters["@BatchID"].Value = $this.BatchID
        $cmd.Parameters["@BatchLogID"].Value = $this.BatchLogID
        $cmd.ExecuteNonQuery()
        $this.ManagementConnection.Close()
    }
      
    [void] ExecuteFile([string] $fileName){
        try{
            $this.Exception = $null
            $this.ReadFile($fileName)
            if((-not $this.DisableHashChecking) -and $this.CheckHashInternal -and $this.HashTable.ContainsKey($this.CurrentFileHash)){
                $this.HashTable[$this.CurrentFileHash] = $true
                return
            }
            $this.PrintInfo("$($this.CurrentFileNameShort)...")
            $pre  = "set textsize 2147483647
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on
set transaction isolation level read committed
set context_info 0x73716C6E6F7465732E696E666F
if @@trancount > 0 
    raiserror('There are open transaction before file execution', 16, 1)
go
"
            $post = "
go
if @@trancount > 0 
    raiserror('There are open transaction after file execution', 16, 1)
"
            $this.WriteLogStart()
            $ret = $this.ExecuteSqlCmdQuery($pre + $this.CurrentFileContent + $post)
            $this.PrintDataRows($ret)
            $this.WriteLogEnd()
            if($this.CheckHashInternal){
                $this.HashTable[$this.CurrentFileHash] = $true
            }
            
        }
        catch {
            $this.Exception = $_
            $this.WriteLogEnd()
            throw $this.Exception
            exit 1
        }
    }
    [void] ExecuteFolder([string] $folder){
        if(-not (Test-Path $folder)){
            return
        }
        foreach($d in Get-ChildItem -Path $folder -Directory | Sort-Object {[System.Text.Encoding]::UTF8.GetBytes($_.BaseName.ToLower())|ForEach-Object ToString X4}){
            $this.ExecuteFolder($d.FullName)
        }
        foreach($f in Get-ChildItem -Path $folder -File -Filter "*.sql" | Sort-Object {[System.Text.Encoding]::UTF8.GetBytes($_.BaseName.ToLower())|ForEach-Object ToString X4}){
            $this.ExecuteFile($f.FullName)
        }
    }
    [void] Deploy(){
        
        $this.PrintHighlight("============================================================================")
        $this.PrintHighlight("Deploying [$($this.SystemName)] code to server=$($this.ConnectionStringBuilder.DataSource), database=[$($this.DatabaseName)]")
        $this.PrintHighlight("============================================================================")
        $this.Initialize()
        $this.PrintHighlight("Current version: $($this.SystemVersionBeforeMigration.ToString())")
        $this.PrintHighlight("Target version: $($this.MaxFolderVersion.ToString())")
        
        $this.CheckHashInternal = $false
        $this.PrintHighlight("Deploying...")
        $this.PrintHighlight("Pre-deploying...")
        $this.ExecuteFolder($(Join-Path -Path $this.SystemPath -ChildPath "PreScripts"))
        $this.PrintHighlight("Pre-deploying...done.")
        
        $this.CheckHashInternal = $true
        
        $this.PrintHighlight("Deploying Objects...")
        $this.ExecuteFolder($(Join-Path -Path $this.SystemPath -ChildPath "Objects"))
        $this.PrintHighlight("Deploying Objects...done.")

        $this.PrintHighlight("Deploying Version folders...")
        foreach($v in $this.VersionFolders){
            $this.SystemVersionCurrent = [System.Version]::new($v.BaseName)
            $this.ExecuteFolder($v)
        }
        $this.PrintHighlight("Deploying Version folders...done.")

        $this.PrintHighlight("Deploying SQLModules...")
        $this.ExecuteFolder($(Join-Path -Path $this.SystemPath -ChildPath "SQLModules"))
        $this.PrintHighlight("Deploying SQLModules...done.")

        $this.CheckHashInternal = $false
        $this.PrintHighlight("Post-deploying...")
        $this.ExecuteFolder($(Join-Path -Path $this.SystemPath -ChildPath "PostScripts"))
        $this.PrintHighlight("Post-deploying...done.")
        $this.WriteHashToDB()
        
        $this.PrintHighlight("Deployment to code base $($this.SystemName) is completed ")
    }
}

$ErrorActionPreference = 'Stop'

$DisableHashChecking = $true
try{
    $VerbosePreference = 'Continue'
    $([SystemDeployment]::new($ServerName, $DatabaseName, $UserName, $Password, "System", $DisableHashChecking)).Deploy()
}
finally{
    $VerbosePreference = $OriginalVerbosePreference
}

Write-Host "Done."
