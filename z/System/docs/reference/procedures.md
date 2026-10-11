# System procedures reference

[Object index](readme.md)

Declarations show required parameters, defaults and output parameters. Unless specified, there is no declared result set or return contract beyond normal SQL procedure status. Permissions depend on underlying statements/callees; dynamic SQL is not a privilege-elevation contract.

## z.usp_AcquireSemaphore

[Source](../../modules/1070%20Procedures/z.usp_AcquireSemaphore.sql)

```sql
create or alter procedure z.usp_AcquireSemaphore
(
	@Resource nvarchar(200), -- Name of the semaphore
	@TotalCount int = 1, -- Size of the semaphore, default it's binary semaphore
	@LockOwner varchar(32) = 'Transaction'
)
```

Acquires resource/slot application locks; returns positive slot number and stores session context. No internal transaction/result set. Transaction ownership needs caller transaction; no timeout/capacity validation. See coordination.

## z.usp_CollectInfo

[Source](../../modules/1070%20Procedures/z.usp_CollectInfo.sql)

```sql
create or alter procedure z.usp_CollectInfo
```

Calls Monitoring z.usp_CheckSystemHealthTrace then z.usp_TakeSnapshotActiveSessions. Writes collector data; needs collector permissions. No encompassing transaction; output follows callees.

## z.usp_CopyTableSchema

[Source](../../modules/1070%20Procedures/z.usp_CopyTableSchema.sql)

```sql
create or alter procedure z.usp_CopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128) = null, -- NULL: 'Use Source Object File Group', 'Use default Database File Group', 'Use Source Object Partition Scheme', FileGroupName or PartitionSchemeName(FieldName)
	@DropTargetTableIfExists bit = 1,
	@CopyIdentity bit = 1,
	@CopyTableSchema bit = 1,
	@CopyIndexes bit = 1,
	@CopyXMLIndexes bit = 1,
	@CopyDefault bit = 1,
	@ScriptAfterTableCreation nvarchar(max) = null,
	@DataCompression varchar(20) = null,
	@PrintCode bit = 0
)
```

Executes schema-copy DDL, dropping target by default, without copying rows. Starts transaction with xact_abort; catch can roll back caller work. Needs source metadata and target DDL permissions. See schema-copy.

## z.usp_CreateAllServiceJobs

[Source](../../modules/1070%20Procedures/z.usp_CreateAllServiceJobs.sql)

```sql
create or alter procedure z.usp_CreateAllServiceJobs
```

Creates General DailyMaintenance hourly/interval 1 via z.usp_CreateServiceJob, then removes orphaned schedules. Collector/trace job calls are commented out. Needs Agent/msdb rights; no encompassing transaction.

## z.usp_DataInitialization_DatabaseSchemas

[Source](../../modules/1070%20Procedures/z.usp_DataInitialization_DatabaseSchemas.sql)

```sql
create or alter procedure z.usp_DataInitialization_DatabaseSchemas
```

Merge-inserts z into z.DatabaseSchemas if missing. dbo example commented out. No deletion/update, explicit transaction or result set. Needs table writes.

## z.usp_DataInitialization_PartitionedTableDataRetention

[Source](../../modules/1070%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql)

```sql
create or alter procedure z.usp_DataInitialization_PartitionedTableDataRetention
```

Merge-inserts/updates generic policy: Monthly/1, forward 3, Default, keep 6, archive 0. Repeats can overwrite custom values. Needs Partition table writes; no explicit transaction/result set.

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

Dynamically drops catalog-selected local temp tables in tempdb, excluding ##. Broad catalog-based selection; do not assume a carefully scoped cleanup contract. Needs rights on selected objects; no transaction/result set.

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
	@IgnoreError bit = 0
)
```

Renames index/PK/UQ/default/FK using expected-name views and sp_rename. Null table limits to z.DatabaseSchemas; explicit table may target any schema. Sets xact_abort off, no internal transaction. Catch rolls back caller work and always throws even with IgnoreError=1. Needs metadata/ALTER.

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

Prints nvarchar input by lines and chunks up to 4000 characters with unlimited recursion. No persisted writes/result set; long lines become multiple messages.

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
	@Resource nvarchar(200), --name of the semaphore
	@LockOwner varchar(32) = 'Transaction'
)
```

Releases resource/slot locks from session context. No transaction/result set or return-code validation. Does not clear context.

## z.usp_RemoveSchemaZ

[Source](../../modules/1070%20Procedures/z.usp_RemoveSchemaZ.sql)

```sql
create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
```

Confirm=1 enables destructive removal of z plan guides/objects, generic partitions, itself/schema. No transaction or safe progress guarantee; errors print and retry. External dependencies may loop and partial removal may persist. Agent/Broker artifacts not comprehensively removed. Needs broad DDL.

## z.usp_SetLargeValueOutOfRow

[Source](../../modules/1070%20Procedures/z.usp_SetLargeValueOutOfRow.sql)

```sql
create or alter procedure z.usp_SetLargeValueOutOfRow
```

Enables large value types out of row for every current-database table with max-length columns and option off. Not limited to z/DatabaseSchemas. Needs ALTER; no transaction/result set.

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
