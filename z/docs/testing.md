# Preview and verification

[Installer guide](readme.md)

## Preview

```powershell
./z/Deploy.ps1 -ServerName localhost -DatabaseName SchemaZ_Example -ShowPlan
```

This validates traversal without a SQL connection. Because installed versions are not read, it does not predict every skip for an existing database. Review stage, owner, path and version in returned steps.

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

`RunTests` walks reserved tests folders and executes their SQL in Test batches without content hashes or subsystem version/date advancement. It still connects and bootstraps metadata and can execute arbitrary test SQL.

The published tree does not ship a regression suite. Point RootPath at a separately maintained test tree if using this facility, preview first, and use a disposable target. Test mode does not automatically create/clean a disposable database or undo test statements.
