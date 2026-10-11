# Deployment metadata reference

[Installer guide](readme.md) · [Source](../Deploy.sql)

## Tables

Bootstrap creates missing current-schema tables inside a transaction; it does not migrate old schemas. All dates are UTC datetime values. Foreign keys retain owner/batch/hash relationships. Installer login needs schema/DDL and metadata access; there are no automatically granted application roles.

| Object | Columns and relationships |
| --- | --- |
| z.Systems | SystemID uniqueidentifier PK; CodeBase nvarchar(4000) not null; Version varchar(100) not null; Date datetime not null. Check requires GUID from MD5(trim(lower(CodeBase))). |
| z.SystemUpdateBatch | BatchID bigint identity PK; SystemID FK; SystemVersion varchar(100); HasError bit default 0; StartDate datetime default UTC; nullable EndDate. Owner/version distinguish deployment and Test batches. |
| z.SystemScriptHash | ScriptHashID bigint identity PK; SystemID FK; FileHash varbinary(32) not null with length check; FileName/FileContent nvarchar(max) not null; CreationDate UTC; IsCurrent default 1; HasSucceeded default 0. Unique owner/hash index. |
| z.SystemUpdateBatchLog | Composite PK BatchID/BatchLogID (bigint identity log ID); owner FK; nullable FileHash (32-byte check and composite owner/hash FK); nullable ErrorMessage nvarchar(max); StartDate UTC; nullable EndDate; batch FK. Tests are unhashed. |

Nonnullable columns are required except where defaults or identities are shown. Hash/log large-value storage is set out of row. History is not automatically time-expired; pruning deactivates hashes rather than deleting old records. Filename/content live in hash rows, not repeated in each log.

## Procedure contracts

Metadata procedures are intended for the installer. Calling them individually does not acquire the deployment lock automatically. Write procedures use nocount/xact_abort and local transactions where shown in source; rollback can affect a caller transaction. Access is not a general user-facing administrative API.

### z.usp_CreateDatabaseUpdateLog

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

Creates a batch when BatchID=-1, creates file log when BatchLogID=-1, otherwise finishes that log. Returns BatchID and BatchLogID both as output parameters and result columns. Validates owner/batch/hash, forbids Test hashes, registers/reactivates hash before execution, marks success on completed log with no error, latches batch HasError. New hash requires sanitized filename/content. Atomic local transaction with updlock/holdlock.

### z.usp_AcquireDeploymentLock

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_AcquireDeploymentLock
```

No arguments/result set. Session-owned exclusive z.Deploy application lock, timeout 0. Negative/null result throws 51000.

### z.usp_ReleaseDeploymentLock

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_ReleaseDeploymentLock
```

No arguments/result set. Releases session z.Deploy lock; failure throws 51001.

### z.usp_GetDeploymentSystems

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_GetDeploymentSystems
(
	@CodeBase nvarchar(4000) = null
)
```

Returns SystemID, CodeBase, Version for all rows or normalized CodeBase lookup. Rejects empty/overlong input and identity collision. Read-only, no explicit transaction.

### z.usp_BeginDeployment

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_BeginDeployment
(
	@CodeBase nvarchar(4000),
	@Version varchar(100)
)
```

Normalizes CodeBase, checks collision, inserts missing system at 0.0.0, creates batch for requested version. Returns BatchID/SystemID. Atomic with updlock/holdlock; does not itself update installed version.

### z.usp_GetDeploymentHashes

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_GetDeploymentHashes
(
	@SystemID uniqueidentifier
)
```

Returns FileHash, HasSucceeded for current hashes belonging to registered SystemID. Unregistered owner throws. Read-only.

### z.usp_RemoveDeploymentHash

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_RemoveDeploymentHash
(
	@SystemID uniqueidentifier,
	@FileHash varbinary(32)
)
```

Validates owner/32-byte hash, marks stale record IsCurrent=0. Successful baseline/version hashes remain current; failed hashes can retire. Does not delete histories or return a result set.

### z.usp_CompleteDeployment

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_CompleteDeployment
(
	@SystemID uniqueidentifier,
	@Version varchar(100),
	@BatchID bigint
)
```

Atomically closes a matching, nonfailed, open owner/version batch, then updates system version/date except Test. Failed/mismatched/completed batches throw. No result set.

### z.usp_FailDeployment

[Source](../Deploy.sql)

```sql
create or alter procedure z.usp_FailDeployment
(
	@BatchID bigint
)
```

Marks batch HasError=1 and EndDate UTC in a transaction; missing batch throws. Does not roll back product scripts or rewind completed subsystem versions. No result set.
