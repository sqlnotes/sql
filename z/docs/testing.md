# Preview and verification

[Installer guide](readme.md)

Use a preview to review the planned files before an installation, then query deployment history to check what ran and where an update failed. These checks describe installation progress; verify the feature you intend to use separately.

## Preview

```powershell
./z/Deploy.ps1 -ServerName localhost -DatabaseName SchemaZ_Example -ShowPlan
```

The command returns ordered steps showing each file's stage, owner, path and version. It does not connect to SQL Server. Because it cannot read installed versions, an actual update may skip files included in this preview.

## Inspect installed state

Execute read-only checks in the deployed database:

```sql
select SystemID, CodeBase, Version, Date
from z.Systems
order by CodeBase;

select BatchID, SystemID, SystemVersion, HasError, StartDate, EndDate
from z.SystemUpdateBatch
order by BatchID desc;

select BatchID, BatchLogID, ErrorMessage, StartDate, EndDate
from z.SystemUpdateBatchLog
where ErrorMessage is not null or EndDate is null
order by BatchID, BatchLogID;
```

A successful deployment log demonstrates script execution, not complete correctness of every administrative feature. Verify the specific feature and target permissions needed by the application.

## Test-only mode

Use `-RunTests` to run a separately maintained SQL test tree. It runs SQL in reserved `tests` folders and records the results as Test batches, without changing installed subsystem versions or dates. This mode still connects to the database, prepares deployment metadata and executes the supplied SQL.

The published tree does not ship a regression suite. Point RootPath at a separately maintained test tree if using this facility, preview first, and use a disposable target. Test mode does not automatically create/clean a disposable database or undo test statements.
