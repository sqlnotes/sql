# Install and update

[Installer guide](readme.md) · [System guide](../System/docs/readme.md)

## Prerequisites

Use PowerShell 7 (the traversal uses modern .NET path APIs). If the `SqlServer` PowerShell module is missing, the installer automatically downloads it from PSGallery using `Install-Module -Scope CurrentUser`; this requires PowerShellGet and gallery access, but no administrator elevation. An available module is reused. Download or import failures stop before database access. `-ShowPlan` does not install or import the module.

Use a login allowed to create a database if needed, create/alter schema and module/table objects, maintain deployment metadata and execute the supplied administrative post scripts. Feature use may require separate Agent, Broker, server DMV, backup or security rights.

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
| ServerName | Required string |
| DatabaseName | Required string; 1–128 characters; restricted SQLcmd/quote/bracket/newline delimiters rejected |
| UserName, Password | Optional strings; omitted/empty user selects Windows authentication |
| DisableHashChecking | Switch, false; true executes eligible unchanged scripts |
| DisableTrustServerCertificate | Switch, false; true requires certificate validation |
| RootPath | Script-adjacent System directory; selects deployment tree and root CodeBase |
| ShowPlan | Switch, false; returns ordered validated plan without SQL |
| RunTests | Switch, false; executes reserved test folders only in unhashed Test batches |

Connections encrypt; certificate trust is enabled by default. Supply SQL credentials at runtime without committing values. Script execution has unlimited query timeout; metadata calls use 30 seconds and connection opening uses 15 seconds.

## Existing databases

Current-schema bootstrap is repeatable and retains existing metadata. It does not upgrade older incompatible metadata schemas. Numbered child paths gain independent histories: moved guarded baselines replay under the new child owner while earlier System history remains.

Root post executes on repeats: initialization can reset the generic retention policy and naming enforcement can rename existing objects. This is consequential even when shared module hashes are unchanged.

Review [execution semantics](deployment-process.md) and take an appropriate recovery path before applying changes to an important database. A failed deployment is not automatically rolled back as a whole.
