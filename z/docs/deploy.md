# Install and update

[Installer guide](readme.md) · [System guide](../System/docs/readme.md)

`Deploy.ps1` installs or updates Schema Z in the SQL Server database you name. Start with `-ShowPlan` to see the files it would consider, then run the same command without that switch to apply the update. An absent database is created during execution.

## Prerequisites

Use PowerShell 7 (the traversal uses modern .NET path APIs). If the `SqlServer` PowerShell module is missing, the installer automatically downloads it from PSGallery using `Install-Module -Scope CurrentUser`; this requires PowerShellGet and gallery access, but no administrator elevation. An available module is reused. Download or import failures stop before database access. `-ShowPlan` does not install or import the module.

Use a login allowed to create a database if needed, create/alter schema and module/table objects, maintain deployment metadata and execute the supplied administrative post scripts. System root post creates or reconciles the hourly general-maintenance SQL Agent job and removes orphaned schedules on every deployment. The installer needs the corresponding msdb job/schedule and default sa job-owner permissions; SQL Agent must be available for this operational setup. New jobs are enabled, while existing enabled state is preserved. Other feature use may require Broker, server DMV, backup or security rights.

The minimum supported version is SQL Server 2019 (15.x). [Compatibility limits](../System/docs/troubleshooting.md).

## Commands

Run from the public repository root, substituting the intended target:

```powershell
./z/Deploy.ps1 -ServerName localhost -DatabaseName SchemaZ_Example -ShowPlan
./z/Deploy.ps1 -ServerName localhost -DatabaseName SchemaZ_Example
```

Preview returns the filesystem plan without connecting or reading installed versions. Execution bootstraps via SQLcmd-capable `Invoke-Sqlcmd`, obtains metadata lock, reads installed versions and recalculates the plan.

## Parameters

[Source](../Deploy.ps1)

| Parameter | Default and behavior |
| --- | --- |
| ServerName | Required. SQL Server instance to connect to. |
| DatabaseName | Required. Database to install or update. Names must be 1–128 characters and cannot contain delimiters that interfere with SQLcmd substitution. |
| UserName, Password | Optional SQL login credentials. Omit the user name, or pass an empty one, to use Windows authentication. |
| DisableHashChecking | Off by default. Run eligible scripts even when their contents have not changed. It does not override version eligibility. |
| DisableTrustServerCertificate | Off by default. Require validation of the server's certificate instead of trusting it. |
| RootPath | Folder tree to deploy; defaults to the `System` folder beside the installer. The path also determines deployment ownership. |
| ShowPlan | Preview the ordered files and their owners without connecting to SQL Server. It does not read the target's installed versions. |
| RunTests | Run SQL from reserved test folders instead of a normal update. Records Test batches without updating subsystem versions. See [test-only mode](testing.md#test-only-mode). |

Connections encrypt; certificate trust is enabled by default. Supply SQL credentials at runtime without committing values. Script execution has unlimited query timeout; metadata calls use 30 seconds and connection opening uses 15 seconds.

## Existing databases

Current-schema bootstrap is repeatable and retains existing metadata. It does not upgrade older incompatible metadata schemas. Numbered child paths gain independent histories: moved guarded baselines replay under the new child owner while earlier System history remains.

Root post executes on repeats: initialization preserves existing generic retention policies, naming enforcement can rename existing objects, and service-job setup reconciles the hourly maintenance job and removes orphaned schedules. This is consequential even when shared module hashes are unchanged.

Review [execution semantics](deployment-process.md) and take an appropriate recovery path before applying changes to an important database. A failed deployment is not automatically rolled back as a whole.
