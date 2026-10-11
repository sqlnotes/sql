# Using Deploy.ps1

## Prepare

SQL Server 2017 or later is supported. Basic `trim(expression)` is available
since SQL Server 2017. The SQL Server 2022-only
`leading`, `trailing`, and `both` positional syntax is not used.
See [Microsoft's TRIM documentation](https://learn.microsoft.com/en-us/sql/t-sql/functions/trim-transact-sql).

Use PowerShell 7 with the `SqlServer` module installed. To install it for your user:

```powershell
Install-Module SqlServer -Scope CurrentUser
```

Use a login with permission to create the database when needed and to create or
alter the objects used by your modules. The deployer creates a missing database;
when the database exists, it initializes missing metadata and deploys into it.
Bootstrap assumes the current metadata schema; legacy schema migration is not supported.
It does not delete and recreate an existing database.

## Preview and deploy

From the `z` directory, preview the execution plan:

```powershell
./Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase -ShowPlan
```

Preview does not connect to SQL Server or load installed versions. It assumes a
new installation and includes all numbered versions; it is a folder-plan preview,
not a validation of SQL syntax, database permissions, or existing database state.

Deploy using the current Windows identity:

```powershell
./Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase
```

SQL authentication is also supported. Supply credentials at runtime:

```powershell
$credential = Get-Credential
./Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase `
    -UserName $credential.UserName -Password $credential.GetNetworkCredential().Password
```

Connections are encrypted. `TrustServerCertificate` defaults to `True`. To require
certificate validation by the client, pass `-DisableTrustServerCertificate`.

## Parameters

| Parameter | Meaning |
| --- | --- |
| `ServerName` | Required SQL Server target |
| `DatabaseName` | Required database; 1–128 characters, without single quotes, closing brackets, line breaks, `$`, or parentheses |
| `UserName`, `Password` | Optional SQL authentication; omit `UserName` for Windows authentication |
| `DisableHashChecking` | Disable hash comparison and rerun eligible scripts; omit to enable hash checking |
| `DisableTrustServerCertificate` | Require a certificate trusted by the client; omit to trust the server certificate |
| `RootPath` | Module root; defaults to `System` next to `Deploy.ps1` |
| `ShowPlan` | Return the initial-install plan without database access |
| `RunTests` | Execute only reserved test folders; omitted by default |

An alternate root can be supplied explicitly:

```powershell
./Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase -RootPath ./AnotherModule
```

The root folder's name becomes its canonical path, for example `/AnotherModule`.

## Redeploy

```powershell
./Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase
```

Hash checking is enabled by default. Successful content hashes can skip scripts;
eligible `pre` and `post` always run without hash comparison. To rerun all eligible
scripts, pass `-DisableHashChecking`. A subsystem's entire `baseline` is
skipped once it has a completed version above `0.0.0`, even with hashing disabled.
Current-version
migrations remain eligible, so write scripts to tolerate repeated execution.
See [process details](deployment-process.md) for version and hash behavior.

## Verify and investigate errors

Run these read-only queries in the deployed database:

```sql
select SystemID, CodeBase, Version, Date from z.Systems order by CodeBase;
select BatchID, SystemID, SystemVersion, HasError, StartDate, EndDate
from z.SystemUpdateBatch order by BatchID desc;
select BatchID, BatchLogID, SystemID, FileHash, ErrorMessage, StartDate, EndDate
from z.SystemUpdateBatchLog where ErrorMessage is not null order by BatchLogID desc;
```

On failure, inspect the failing script and its error before retrying. The deployer
stops, but successful earlier scripts are not automatically undone. An unfinished
subsystem retains its previously completed version. The console reports completed
subsystems and prints `Deployment completed.` only when the full plan succeeds.
Logs reference `z.SystemScriptHash` by SystemID/FileHash for script details. They
do not duplicate filename/content. Unhashed test entries have batch/log IDs only.
