# Deployment metadata reference

[Installer guide](readme.md) · [Source](../Deploy.sql)

Deployment metadata answers three questions: which subsystem versions are installed, which files have already succeeded unchanged, and what happened during each update. Use the tables to inspect that history. The procedures are the installer's interface for recording progress; applications normally call `Deploy.ps1` rather than these procedures directly.

## Tables

Bootstrap creates missing current-schema tables inside a transaction; it does not migrate old schemas. All dates are UTC datetime values. Foreign keys retain owner/batch/hash relationships. Installer login needs schema/DDL and metadata access; there are no automatically granted application roles.

| Object | What it tells you | Important fields |
| --- | --- | --- |
| `z.Systems` | The installed version of each subsystem. | `SystemID` identifies the owner, `CodeBase` is its folder path, and `Version`/`Date` describe the last successful completion. |
| `z.SystemUpdateBatch` | One deployment or Test batch and whether it finished with an error. | `BatchID`, `SystemID`, `SystemVersion`, `HasError`, `StartDate`, `EndDate`. An unfinished batch has no end date. |
| `z.SystemScriptHash` | The contents known for a subsystem and whether they have succeeded. | `FileHash` is the 32-byte content hash; `FileName`/`FileContent` hold the recorded source. `IsCurrent` and `HasSucceeded` control normal skip decisions. |
| `z.SystemUpdateBatchLog` | When an individual file ran and any error it produced. | `BatchID`/`BatchLogID` identify the entry; `FileHash` connects it to the recorded file, and `ErrorMessage`/`StartDate`/`EndDate` describe its outcome. Tests have no file hash. |

Join by subsystem, batch and hash identifiers to follow an update from owner to file result. Filename/content live in hash rows rather than being repeated in every log. History does not expire automatically; pruning marks obsolete hashes inactive while retaining prior records. The [source](../Deploy.sql) defines exact column types, constraints and indexes.

## Procedure contracts

Metadata procedures are intended for the installer. Calling them individually does not acquire the deployment lock automatically. Write procedures use nocount/xact_abort and local transactions where shown in source; rollback can affect a caller transaction. Access is not a general user-facing administrative API.

### z.usp_CreateDatabaseUpdateLog

Starts or finishes a file's deployment-log entry. The installer also uses it to create a batch when needed, and receives identifiers for later completion calls.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_CreateDatabaseUpdateLog
(
	@BatchID bigint output,
	@BatchLogID bigint output,
	@SystemID uniqueidentifier,
	@SystemVersion varchar(100) = null,
	@FileHash varbinary(32) = null,
	@FileName nvarchar(max) = null,
	@FileContent nvarchar(max) = null,
	@ErrorMessage nvarchar(max) = null
)
```

Pass `@BatchID = -1` to create a batch and `@BatchLogID = -1` to start a file log; otherwise the call finishes the identified log. `BatchID` and `BatchLogID` are returned both through output parameters and result columns. Supply the owner/version and, for product scripts, the hash and sanitized source. Test batches must not have hashes.

A completed log with no error marks the content successful. Supplying an error marks the batch as having an error. Owner, batch and hash relationships are checked; a new hash requires filename/content. These metadata changes are transactional.

### z.usp_AcquireDeploymentLock

Reserves this database for one cooperating installer connection at a time. A second installer fails promptly rather than waiting for the first one.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_AcquireDeploymentLock
```

There are no arguments or returned rows. The lock belongs to the connection and uses resource `z.Deploy`; acquisition failure raises error 51000. Release it on that connection with `z.usp_ReleaseDeploymentLock` or close the connection.

### z.usp_ReleaseDeploymentLock

Ends the current connection's installer reservation so another installation can proceed.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_ReleaseDeploymentLock
```

There are no arguments or returned rows. The procedure tries to remove the connection's `z.Deploy` lock and suppresses caught cleanup exceptions. A native release failure can end cleanup before the lock is gone; disconnection also releases a session-owned lock.

### z.usp_GetDeploymentSystems

Lists installed subsystem versions, or looks up the owner for one deployment path. The installer uses this to choose eligible baselines and migrations.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_GetDeploymentSystems
(
	@CodeBase nvarchar(4000) = null
)
```

Omit `@CodeBase` to return all owners, or supply the deployment path to look up one. Results contain `SystemID`, `CodeBase` and `Version`. Empty or overlong inputs and identity collisions raise an error. The procedure changes no data.

### z.usp_BeginDeployment

Opens a deployment batch for a subsystem and target version. It records that an update is starting; it does not yet advance the installed version.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_BeginDeployment
(
	@CodeBase nvarchar(4000),
	@Version varchar(100)
)
```

Supply `@CodeBase` as the subsystem path and `@Version` as the intended version. A new owner starts at `0.0.0`. The call returns `BatchID` and `SystemID` for subsequent logging and completion. Owner creation and batch creation are transactional; identity collisions raise an error.

### z.usp_GetDeploymentHashes

Returns the current file hashes known for a subsystem so the installer can skip unchanged successful content.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_GetDeploymentHashes
(
	@SystemID uniqueidentifier
)
```

Pass a registered `@SystemID`. Each row contains `FileHash` and `HasSucceeded`; an unknown owner raises an error. The call is read-only.

### z.usp_RemoveDeploymentHash

Retires an obsolete file hash from current skip decisions while keeping its history.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_RemoveDeploymentHash
(
	@SystemID uniqueidentifier,
	@FileHash varbinary(32)
)
```

Supply the owner and 32-byte hash. Eligible stale content becomes inactive, but successful baseline/version hashes remain current; failed hashes can be retired. Invalid inputs raise an error. No history is deleted and no result set is returned.

### z.usp_CompleteDeployment

Records successful completion of a subsystem update and advances its installed version. A Test batch closes without changing the installed version or date.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_CompleteDeployment
(
	@SystemID uniqueidentifier,
	@Version varchar(100),
	@BatchID bigint
)
```

Pass the owner, version and open batch ID from the update. They must match a batch that has not failed or already completed. Completion and the version/date update are transactional. Invalid state raises an error; there is no result set.

### z.usp_FailDeployment

Marks a batch as failed and records its end time. It describes the update's outcome; it does not undo SQL already applied by product scripts.

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_FailDeployment
(
	@BatchID bigint
)
```

Pass `@BatchID` to set `HasError` and the UTC end time. A missing batch raises an error. Earlier script changes and completed subsystem versions remain in place. The metadata update is transactional and returns no rows.
