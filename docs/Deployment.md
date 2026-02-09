# Install Schema z
Schema z can be installed using the PowerShell script in this repository. Please note that it only supports **PowerShell Core Edition** which can be downloaded from: https://github.com/PowerShell/PowerShell

The installation program deploys code to the database specified in the parameter. If the database does not exist, a new one with specified name will be created.

**Installation Command**

Use install.ps1 with SQL Authentication  to install Schema z:

``` ps
install.ps1 SQLServerName DatabaseName UserName Password
```

Use install.ps1 with Windows Authentication  to install Schema z:
``` ps
install.ps1 myServer MyDatabase
```
**Optional Parameter**

* -PerformTest

Add -PerformTest parameter to run test after installation.

``` ps
install.ps1 myServer MyDatabase -PerformTest
```


# Uninstall Schema z
A SQL procedure can be called to uninstall Schema z.

``` sql
exec z.usp_RemoveSchemaZ @Confirm = 1
```

# How It Works
The deployment script is developed using Powershell Core. Unlike other SQL Server deployment tools, it operates in a straightforward manner by iterating all the sql files in all sub-folders and executing them in a specific sequence. The scripts within the same folder are executed in alphabetical order. If sub-folders exist, the scripts in the sub-folders are executed first, followed by those in the parent folder. Currently, the script only supports executing SQL files, but future enhancements may include the ability to run PowerShell scripts. Below is the workflow of installation script.

1. SQL script **Install.sql** is executed on the database specified on target server. If database does not exists, it will be created. This script creates tables for versioning and installation related information.
2. SQL scripts located in the **PreScripts** folder will be executed. This folder is intended to contain  the scripts that verify server or database configurations or database level or perform tasks that must be executed for every deployment.
3. The **Objects** folder contains scripts for creating objects. 
4. Next, the deployment process executes scripts located in the version folders. There may be one or multiple version folders, named in a format such as **xxx.xx.xx.xx**(Major.Minor.Build.Revision). Any folder name that can be implicitly converted to the System.Version class in the .NET framework is treated as a version folder. NOt all version folders are deployed. For an initial deployment, scripts are executed sequentially from the lowest to highest version. If the database is already at a specific version, scripts for the earlier versions are skipped, and only those for the current version and later are deployed.
5. The **SQLModules** folder contains the scripts for objects such as procedures, functions, triggers, views, where each object is represented as an individual script. The execution order of these objects and their dependencies is  determined by the arrangement of the sub-folder.
6. Folder **PostScripts**, similar to **PreScripts**, is executed for every deployment. However, these scripts are executed at the end of the deployment process.
7. Folder **Tests** contains all the test scipts. By defualt, they will not be executed. However, if the switch parameter **-PerformTest** is enabled, the scripts in this folder will be executed.


There is an another optional parameter **-EnableHashChecking**, when enabled, it ensures that a script is not executed multiple times if it has already been deployed. For example, the procedure xyz was deployed in version 3.0. Current version is 8.0. However, this procedure has not changed. It will not be re-deployed with this switch . This parameter is typically designed to reduce number of scripts sent to the server -- if a script has already been deployed, it will not be deployed again. It can be useful particularly when there are a large number of files or a slow network connection to the server.

# Tables

1. **System Table**: This table stores the name of the system and current version. For Schema z, there will only be one record with the name "System". YOu can customize the deployment script to use this table for tracking the version of each sub-systems.
2. **SystemScriptHash**: This table stores the MD5 hash values for the content of every file except the scripts in the **PreScripts** and **PostScript** folders. If two files have the same hash value, they are considered identical, even if they are located in different folders. When the **-EnableHashChecking** switch is enabled, identical files will not be redeployed - only one is deployed. When SQL files are removed from the deployment folder, their corresponding hashes are also removed by the deployment script.
3. **SystemUpdateBatch**: Each execution of the deployment script generates a record in this table, containing information such as deployment start and end dates.
4. **SystemUPdateBatchLog**: This table contains detailed information about each deployment, including the file content, execution start and end dates, and any error messages encountered.

# Script Execution

Before running each script, following query is executed. 

``` sql
set textsize 2147483647
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on
set transaction isolation level read committed
set context_info 0x73716C6E6F7465732E696E666F
if @@trancount > 0 
    raiserror('There are open transaction before file execution', 16, 1)
go
```

After the completion of each script, following query will be executed.

``` sql
if @@trancount > 0 
    raiserror('There are open transaction after file execution', 16, 1)
go
```

A script may be deployed multiple times. For this program to function correctly, developers must ensure the script is idempotent, meaning it can be executed repeatedly without causing unintended side effects. For instance, if the script modifies data, subsequent executions should not alter the data again after the initial run. Similarly, if the script creates a table, re-executing it should not attempt to create the same table again, avoiding errors.