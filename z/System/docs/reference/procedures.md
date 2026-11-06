# System procedures reference

[Object index](readme.md)

Declarations show required parameters, defaults and output parameters. Unless specified, there is no declared result set or return contract beyond normal SQL procedure status. Permissions depend on underlying statements/callees; dynamic SQL is not a privilege-elevation contract.

## z.usp_AcquireSemaphore

[Source](../../modules/1070%20Procedures/z.usp_AcquireSemaphore.sql)

```sql
create or alter procedure z.usp_AcquireSemaphore
(
	@SemaphoreName nvarchar(200),
	@TotalCount int = 1,
	@LockOwner varchar(32) = 'Transaction',
	@LockTimeout int = -1
)
```

Acquires a capacity slot through native locks; returns a positive slot or negative failure. If the same database, session and owner already hold it, returns the existing slot without another native acquisition or reference-count increment. Validates inputs and bounds waits with @LockTimeout. The outer acquisition owns release. No internal transaction/result set. See coordination.

## z.usp_CopyTableSchema

[Source](../../modules/1070%20Procedures/z.usp_CopyTableSchema.sql)

```sql
create or alter procedure z.usp_CopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128) = null, -- NULL: 'Use Source Object File Group', 'Use default Database File Group', 'Use Source Object Partition Scheme', FileGroupName or PartitionSchemeName(FieldName)
	@DropTargetTableIfExists bit = 0,
	@CopyIdentity bit = 1,
	@CopyTableSchema bit = 1,
	@CopyIndexes bit = 1,
	@CopyXMLIndexes bit = 1,
	@CopyDefault bit = 1,
	@ScriptAfterTableCreation nvarchar(max) = null,
	@DataCompression varchar(20) = null,
	@PrintCode bit = 0,
	@PartitionNumber int = 1,
	@ShowPlan bit = 0
)
```

Generates schema-copy DDL and executes it without copying rows, or returns ordered Ordinal/PartName/Definition rows with `@ShowPlan = 1` without executing generated SQL. Existing target replacement is explicit. Default partition is 1; NULL storage/compression inherit each selected heap/index partition's settings. Uses its own transaction or a caller-transaction savepoint. Needs source metadata and target DDL permissions. See [schema-copy behavior and limits](schema-copy.md).

## z.usp_CreateAllServiceJobs

[Source](../../890-SystemBeforePost/1010%20Procedures/z.usp_CreateAllServiceJobs.sql)

```sql
create or alter procedure z.usp_CreateAllServiceJobs
```

Defined in 890-SystemBeforePost after the Jobs subsystem is installed. System root post invokes it on every deployment to create or reconcile General DailyMaintenance hourly/interval 1 via z.usp_CreateServiceJob, then remove orphaned schedules. New jobs are enabled; existing job enabled state is preserved. Installation therefore requires Agent/msdb job and schedule permissions, including the default job-owner change to sa. No encompassing transaction.

## z.usp_DataInitialization_PartitionedTableDataRetention

[Source](../../890-SystemBeforePost/1010%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql)

```sql
create or alter procedure z.usp_DataInitialization_PartitionedTableDataRetention
```

Inserts missing generic bigint/datetime policies: Monthly/1, forward 3, Default, keep 6, archive 0. Repeats preserve existing custom values. Needs Partition table writes; no explicit transaction/result set.

## z.usp_DataInitializationHelper

[Source](../../modules/1070%20Procedures/z.usp_DataInitializationHelper.sql)

```sql
create or alter procedure z.usp_DataInitializationHelper
(
	@FullObjectName sysname,
	@ForceIdentityColumnInsert bit = 1,
	@ForceMatchedDataUpdate bit = 1,
	@PrimaryKeys varchar(max) = null,
	@ExcludedColumns varchar(max) = null
)
```

Reads current rows and prints merge initialization SQL without executing it. Excludes computed/rowversion columns; allows key/exclusion/identity options. Missing object silently returns; missing key errors. Needs source SELECT/metadata; printed data may be sensitive. No explicit transaction.

## z.usp_DataInitializationMaster

[Source](../../modules/1070%20Procedures/z.usp_DataInitializationMaster.sql)

```sql
create or alter procedure z.usp_DataInitializationMaster
(
	@SchemaName nvarchar(128) = 'z'
)
```

Executes usp_DataInitialization* except Helper/Master, sorted by quoted name. Default z; null includes all schemas. Prints progress, inherits callee effects/errors; no encompassing transaction.

## z.usp_DropAllLocalTempTables

[Source](../../modules/1070%20Procedures/z.usp_DropAllLocalTempTables.sql)

```sql
create or alter procedure z.usp_DropAllLocalTempTables
```

Executes catalog-selected local-temp-table DROP statements in tempdb, excluding ## and candidates that do not resolve through object_id in that execution context. Selection depends on metadata visibility and name resolution; do not assume a carefully scoped cleanup contract. Needs rights on selected objects; no transaction/result set.

## z.usp_DropObject

[Source](../../modules/1070%20Procedures/z.usp_DropObject.sql)

```sql
create or alter procedure z.usp_DropObject
(
    @ObjectName nvarchar(512) = null
)
```

Resolves current-database object ID and drops supported kind with dynamic SQL. Null/unresolved produces no generated command. Does not remove dependents; needs DDL rights. No transaction/result set.

## z.usp_ForceNamingConvention

[Source](../../modules/1070%20Procedures/z.usp_ForceNamingConvention.sql)

```sql
create or alter procedure z.usp_ForceNamingConvention
(
	@TableName nvarchar(256) = null,
	@IgnoreError bit = 0,
	@SchemaNames nvarchar(max) = null,
	@TableNames nvarchar(max) = null,
	@ShowPlan bit = 0
)
```

Renames indexes, PK/UQ constraints, defaults and foreign keys through expected-name views and `sp_rename`; it does not rename tables or schemas. Supply at least one selector: legacy `@TableName`, JSON string array `@SchemaNames`, or JSON string array `@TableNames`. Selection is their union, with duplicates removed. New table-list entries must be exactly two-part, schema-qualified current-database tables or views. Indexed views can contribute index candidates; ordinary views usually contribute none. All selectors are validated before renaming; malformed JSON, non-string/empty entries and unknown names are rejected. Empty arrays alone are insufficient, while an existing empty schema is valid. Legacy table-name resolution and the first two positional arguments remain compatible. `@ShowPlan = 1` returns `ObjectName`, `NewName` and `ObjectType` rows without renaming. Normal execution is non-atomic, with `xact_abort off` and no internal transaction or caller rollback. `@IgnoreError = 0` throws on the first failed rename; `1` prints that error and continues. Completed renames can persist after later failures. Metadata visibility and ALTER permissions control available objects and execution. See [selection and migration examples](../usage.md#preview-and-enforce-naming-conventions).

## z.usp_GeneralDailyMaintenance

[Source](../../modules/1070%20Procedures/z.usp_GeneralDailyMaintenance.sql)

```sql
create or alter procedure z.usp_GeneralDailyMaintenance
```

Calls Partition retention then database-wide large-value table-option update. Can delete retained rows; no encompassing transaction/result set.

## z.usp_GetQueryResultToSQL

[Source](../../modules/1070%20Procedures/z.usp_GetQueryResultToSQL.sql)

```sql
create or alter procedure z.usp_GetQueryResultToSQL
(
	@Query nvarchar(max),
	@SQL nvarchar(max) output
)
```

Executes trusted @Query and returns select-from-values SQL in @SQL output using first-result metadata/temp tables. Query can have effects; needs its permissions. No internal transaction. Temporal precision/nchar limitations in troubleshooting.

## z.usp_PrintString

[Source](../../modules/1070%20Procedures/z.usp_PrintString.sql)

```sql
create or alter procedure z.usp_PrintString (@str nvarchar(max))
```

Uses z.fn_SplitLines to print nvarchar input by lines, then chunks up to 4000 characters with unlimited recursion. No persisted writes/result set; long lines become multiple messages.

## z.usp_RefeshAllSQLModules

[Source](../../modules/1070%20Procedures/z.usp_RefeshAllSQLModules.sql)

```sql
create or alter procedure z.usp_RefeshAllSQLModules @RefreshTimes int = 1
```

Name is spelled Refesh. Refreshes all visible current-database modules with definitions via sp_refreshsqlmodule, repeated RefreshTimes default 1. First error stops with 50000/state 12. Needs ALTER; refresh can remove module signatures. No transaction/result set.

## z.usp_ReleaseSemaphore

[Source](../../modules/1070%20Procedures/z.usp_ReleaseSemaphore.sql)

```sql
create or alter procedure z.usp_ReleaseSemaphore
(
	@SemaphoreName nvarchar(200),
	@LockOwner varchar(32) = 'Transaction'
)
```

Retrieves the slot from session context and releases one acquisition reference. A missing or nonpositive stored slot raises error 50000; native failures return a negative status. Clears context after the final release. No internal transaction/result set.

## z.usp_RemoveSchemaZ

[Source](../../modules/1070%20Procedures/z.usp_RemoveSchemaZ.sql)

```sql
create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
```

Confirm=1 attempts destructive removal of z plan guides/objects, generic partitions, itself/schema. Completion is not reliable: a retained Async service can block its queue drop on older installations, dependency ordering is incomplete, and types/XML schema collections are omitted. No transaction or safe progress guarantee; errors print and retry, and it removes itself before the final schema drop. Agent/Broker artifacts are not comprehensively removed. Needs broad DDL. See [removal limitations](../troubleshooting.md#removal).

## z.usp_SetLargeValueOutOfRow

[Source](../../modules/1070%20Procedures/z.usp_SetLargeValueOutOfRow.sql)

```sql
create or alter procedure z.usp_SetLargeValueOutOfRow
```

Enables large value types out of row for every current-database table with max-length columns and option off. Not limited to schema z. Needs ALTER; no transaction/result set.

## z.usp_SkipTrigger

[Source](../../modules/1070%20Procedures/z.usp_SkipTrigger.sql)

```sql
create or alter procedure z.usp_SkipTrigger
(
	@ParentObjectNames nvarchar(max) = null,
	@TriggerNames nvarchar(max) = null
)
```

Stores session-context flag from comma-separated parent/trigger names or all. Null arguments clear it. No transaction/result set; only cooperating triggers consult it.

## z.usp_SuppressBackupSuccessMessages

[Source](../../modules/1070%20Procedures/z.usp_SuppressBackupSuccessMessages.sql)

```sql
create or alter procedure z.usp_SuppressBackupSuccessMessages
```

Checks global trace flag 3226 using `DBCC TRACESTATUS`. If already enabled globally,
returns without changing it; otherwise enables it with `DBCC TRACEON (3226, -1)`.
Suppresses successful backup/restore entries in the SQL Server error log and
system event log for the whole instance. Backup failures remain logged; backup
command progress/completion output to the client is unaffected. No parameters or
result set. Enabling the flag requires membership in the sysadmin server role;
permission and DBCC errors propagate to the caller.

```sql
exec z.usp_SuppressBackupSuccessMessages;
```

Installation defines this procedure without calling it. The runtime setting is
lost on SQL Server restart unless separately configured with startup option
`-T3226`; this procedure does not change startup configuration. Use when backup
monitoring does not depend on successful backup log entries. The internal
`INSERT ... EXEC` means it cannot run inside another `INSERT ... EXEC`.
See Microsoft's [trace flag documentation](https://learn.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-traceon-trace-flags-transact-sql).

## z.usp_SetSetting

Inserts or updates a database-local setting with a locked atomic upsert. See [settings](settings.md#zusp_setsetting) for the declaration, description-preservation rules and transaction behavior.
