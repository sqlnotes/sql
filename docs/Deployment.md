# Deploy Schema Z

For detailed commands, testing instructions, and implementation guidance, start
with the [deployment developer guide](../z/docs/readme.md).

Run `z/Deploy.ps1` with PowerShell 7 and the `SqlServer` module installed.
The supported SQL Server versions are 2017 and later.
The former `Install.ps1` and `Install.sql` entry points are replaced by
`Deploy.ps1` and `Deploy.sql`.

```powershell
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase
```

Windows authentication is used when `UserName` is omitted. For SQL authentication,
supply `-UserName` and `-Password` at runtime. Do not store credentials in scripts.
`TrustServerCertificate` defaults to `True`; pass `-DisableTrustServerCertificate`
when using a certificate trusted by the client.

## Options

| Parameter | Purpose |
| --- | --- |
| `ServerName`, `DatabaseName` | Required target server and database |
| `UserName`, `Password` | Optional SQL authentication credentials |
| `DisableHashChecking` | Rerun eligible scripts without hash comparison; hash checking is enabled when omitted |
| `RootPath` | Root module folder; defaults to `System` beside the deployer |
| `ShowPlan` | Return the traversal plan without contacting SQL Server; assumes initial versions |
| `RunTests` | Execute only reserved tests folders; off by default |
| `DisableTrustServerCertificate` | Require a certificate trusted by the client; server certificate trust is enabled when omitted |

```powershell
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase -ShowPlan
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyDatabase -DisableHashChecking
```

## Folder structure and order

```text
System/
  pre/
  baseline/
  versions/
    0.0.1/
    0.0.2/
  modules/
  *.sql
  ChildSubsystem/
    ...same structure...
  post/
  tests/
  docs/
```

Every folder executes in this order:

1. `pre`
2. `baseline`
3. `versions`
4. `modules`
5. Direct `.sql` files, sorted by name
6. Other child folders, sorted by name
7. `post`

Missing stages are skipped. The same ordering applies inside organizational
folders, including nested `pre` and `post`. Name ordering is ordinal and case
insensitive. Version folders are sorted numerically, so `0.0.2` precedes `0.0.10`.
Within a `versions` container, nonreserved child folders must be valid .NET
version names. Its own reserved stages and direct SQL files use the same order.
Linked folders are rejected to avoid escaping the deployment tree.

Baseline establishes the starting point for versions. Once the owning subsystem
has a completed version above `0.0.0`, its entire baseline subtree is skipped,
including nested pre/post. This applies even when hash checking is disabled.
New or unversioned subsystems at `0.0.0` retain baseline eligibility independently
of their parent's version.

Only nonreserved child folders of a subsystem are independent subsystems.
Descendants inside `pre`, `baseline`, `versions`, `modules`, `post`, or `tests`
are organizational folders and never receive separate version records.
`tests` is excluded from installation everywhere.

Every subsystem can have a `docs` folder for its documentation. It is reserved:
its contents are excluded from both deployment and test discovery, including SQL
examples and nested folders. It never receives a subsystem version record.

## Version tracking

`z.Systems` stores one row per subsystem, with canonical forward-slash paths
such as `/System`, `/System/ChildSubsystem`, and `/System/ChildSubsystem/Nested`.
`CodeBase` supports 4000 Unicode characters. `SystemID` is a `uniqueidentifier`
derived from the MD5 hash of `trim(lower(CodeBase))`, so case and surrounding
spaces do not create different subsystem identities. Other metadata tables
reference this compact ID instead of repeating the codebase string.

Each subsystem uses its own installed version. Deployment includes the current
version folder and newer folders. An installed version greater than the highest
available numbered version is rejected before product scripts run. With no
numbered versions, the existing version is retained, or `0.0.0` for a new subsystem.
The completed version is saved only after the subsystem's scripts, children, and
post stage succeed. Successfully completed children keep their independent versions
if a later parent stage fails.

## Bootstrap, hashes, and logs

`Deploy.sql` creates the target database if needed and initializes metadata using
the current schema. Repeating bootstrap preserves current version, hash, and
execution history. Legacy metadata migration is not supported.

Eligible `pre` and `post` always execute, including their descendants, without
comparing hashes. All normally executed script content is hashed with SHA-256 and
stored as `FileHash varbinary(32)`.
Hash checking is enabled by default: an already successful hash in the
same subsystem is skipped only while current, including identical content at
another path. Hashes register before execution; failed records are retained.
Identical contents retain the first filename as canonical. Hashes are independent
between subsystems. Removed content outside baseline/version
folders is marked inactive after successful completion, preserving historical log
references; successful baseline/version hashes remain active. Removed/replaced
failed records retire even in those folders while keeping their rows. The hash
inventory includes current records with success status; only successful entries
permit skips. Use `-DisableHashChecking` to rerun eligible
scripts without hash skipping.

`z.SystemUpdateBatch` records each subsystem attempt; `z.SystemUpdateBatchLog`
records individual script start, completion, and error details, referencing
SystemID/FileHash instead of duplicating filename/content. The logging
procedure does not advance subsystem versions. Metadata writes use parameters.
All metadata reads, writes, locking, and logging use stored-procedure RPC calls
after bootstrap. SQL Server raises metadata validation errors. Developer SQL
files continue to execute directly without modification.
Scripts run with standard session options and transaction-leak checks. A script
error stops deployment; previously completed scripts are not globally rolled back.
Deployments acquire an exclusive database-local lock while running product scripts.

## Tests

`Deploy.ps1 -RunTests` discovers only reserved `tests` folders recursively and
runs them in folder execution order. This mode is off by default. It records
version `Test` batches without advancing subsystem version/date and never
calculates, compares, or stores hashes. Test log entries use batch/log IDs only.

```powershell
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests
```

Supply your own test tree and run test mode against an appropriate
test database. Test scripts are not bundled with the public project:

```powershell
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests -ShowPlan
./z/Deploy.ps1 -ServerName MyServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests
```

It discovers `tests` folders in subsystems and organizational folders, then executes
only test scripts. It does not deploy modules or follow ETL configuration to other
servers. Review test side effects before execution; administrative tests may operate on
server traces. The former `-All` and documented `-PerformTest` options are not used.

## Remove Schema Z

```sql
exec z.usp_RemoveSchemaZ @Confirm = 1;
```
