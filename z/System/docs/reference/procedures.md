# System procedures reference

[Object index](readme.md)

Use these procedures for shared scripting, maintenance and coordination tasks. Each entry starts with its purpose, followed by the call signature and the behavior a caller needs to know. Declarations show exact defaults and output parameters. Unless an entry describes a result set or special return value, use normal SQL error handling to determine whether the call succeeded. Callers need permission for the operations performed by the selected procedure.

## z.usp_AcquireSemaphore

Reserves permission to do a piece of shared work. Use the same semaphore name in cooperating sessions to limit how many can perform that work at once.

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

Set `@TotalCount` to the allowed number of holders. `@LockOwner` chooses whether a transaction or the connection holds the permission. `@LockTimeout` is the wait in milliseconds: 0 tries once and -1 waits indefinitely.

Capture the procedure return value and do the protected work only when it is positive. It identifies the acquired slot. `-1` means timeout; `-2` means the same session holds the semaphore under the other owner; other negative values report native acquisition failures. Reacquiring under the same owner returns the existing slot, so the outer operation remains responsible for release. The procedure does not open a transaction or return rows. [Ownership and examples](coordination.md#semaphores)

## z.usp_CopyTableSchema

Creates an empty table from an existing table's definition, including the selected indexes and defaults. Use `@ShowPlan = 1` to inspect the proposed SQL before applying it.

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

In preview mode, returns ordered `Ordinal`, `PartName` and `Definition` rows. In execution mode, creates the table without copying data and protects an existing target unless replacement is explicitly requested. Source partition 1 is used by default; NULL storage and compression options inherit the selected source settings. See [parameter usage, transactions and copy limits](schema-copy.md).

## z.usp_CreateAllServiceJobs

Sets up Schema Z's recurring general-maintenance job and removes unused managed schedules. Installation calls it on each deployment, including updates.

[Source](../../890-SystemBeforePost/1010%20Procedures/z.usp_CreateAllServiceJobs.sql)

```sql
create or alter procedure z.usp_CreateAllServiceJobs
```

Creates or reconciles the hourly `General DailyMaintenance` job through the Jobs module. New jobs are enabled; an existing job keeps its enabled state. The caller needs Agent/msdb job and schedule permissions, including the default change of job owner to `sa`. Setup is not wrapped in a single transaction. The procedure is installed after Jobs, in `890-SystemBeforePost`.

## z.usp_DataInitialization_PartitionedTableDataRetention

Supplies default retention policies for the shared bigint and datetime partition schemes. Existing custom policies are preserved when initialization runs again.

[Source](../../890-SystemBeforePost/1010%20Procedures/z.usp_DataInitialization_PartitionedTableDataRetention.sql)

```sql
create or alter procedure z.usp_DataInitialization_PartitionedTableDataRetention
```

Missing policies use monthly boundaries, three future periods, filegroup `Default`, six retained intervals and no archive step. The caller needs write access to the Partition policy table. The procedure has no parameters or result set and opens no explicit transaction.

## z.usp_DataInitializationHelper

Prints a reusable initialization script from a table's current rows. Use it to prepare reference data for deployment, then review and save the printed SQL.

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

Pass the table in `@FullObjectName`. The flags control whether the generated merge supplies identity values and updates matched rows; `@PrimaryKeys` and `@ExcludedColumns` override key selection and omitted columns. Computed and rowversion columns are excluded. The helper prints the script without executing it, so the output can contain the source data. A missing object returns without output; a missing merge key raises an error. Source SELECT and metadata access are required.

## z.usp_DataInitializationMaster

Runs the database's data-initialization procedures sequentially through the shared executor. Use it to populate or reconcile reference data during setup.

[Source](../../modules/1070%20Procedures/z.usp_DataInitializationMaster.sql)

```sql
create or alter procedure z.usp_DataInitializationMaster
(
	@SchemaName nvarchar(128) = 'z'
)
```

Runs procedures whose names start with `usp_DataInitialization` through [z.usp_ExecuteProcedures](#zusp_executeprocedures), one at a time, in schema and name order. It excludes `usp_DataInitializationHelper` and `usp_DataInitializationMaster`. The default schema is `z`; pass `@SchemaName = null` to include all schemas.

Each initialization procedure manages its own transactions. If one fails, the executor rolls back any open transaction, continues with the rest, and reports the errors at the end. Run a single initializer when each procedure must execute once per call. Concurrent calls can run an initialization procedure more than once, as explained below.

## z.usp_DropAllLocalTempTables

Removes local temporary tables visible to the call in the current session. Use it when deliberately cleaning up a session's temporary work tables.

[Source](../../modules/1070%20Procedures/z.usp_DropAllLocalTempTables.sql)

```sql
create or alter procedure z.usp_DropAllLocalTempTables
```

Global temporary tables (`##...`) are excluded. Selection depends on tempdb metadata visibility and which names resolve in the execution context, so review that scope before using it in a shared workflow. The procedure returns no rows, opens no transaction and needs permission to drop the selected tables.

## z.usp_DropObject

Drops a supported database object by name. Use it in cleanup scripts that need one entry point for different kinds of objects.

[Source](../../modules/1070%20Procedures/z.usp_DropObject.sql)

```sql
create or alter procedure z.usp_DropObject
(
    @ObjectName nvarchar(512) = null
)
```

Supply an object in the current database through `@ObjectName`. NULL or an unresolved name produces no command. Dependencies are not removed automatically; the caller needs the relevant DDL permissions. There is no returned result set or explicit transaction.

## z.usp_ExecuteProcedures

Runs procedures selected by schema and name pattern, one at a time. Use it for groups of maintenance or initialization procedures that can be called without arguments.

[Source](../../modules/1070%20Procedures/z.usp_ExecuteProcedures.sql)

```sql
create or alter procedure z.usp_ExecuteProcedures
(
	@SchemaName nvarchar(128),
	@NamePattern nvarchar(1024),
	@ExcludedProcedureNames nvarchar(max) = null
)
```

Runs all procedures matching the specified schema and name pattern, one at a time, in schema and alphabetical name order. With a single executor, each matching procedure is called once.

With multiple executors, a procedure that is already running is skipped without waiting. **This prevents simultaneous execution of the same procedure, but does not guarantee that each procedure executes only once across the executors.** Each executor has its own list and does not remember what the others have finished.

For example, thread 1 starts procedure 1. Thread 2 skips procedure 1, finishes procedure 2, and moves to procedure 3. When thread 1 finishes procedure 1, it reaches procedure 2 and runs it again because procedure 2 is no longer running. Procedure 2 has now executed twice.

Use a single executor when each matching procedure should run once per call. Multiple executors are suitable only when repeated execution is acceptable. They can also run later procedures before earlier ones have finished in another thread.

For example, this runs procedures in `dbo` whose names start with `usp_Refresh_`:

```sql
exec z.usp_ExecuteProcedures @SchemaName = N'dbo', @NamePattern = N'usp!_Refresh!_%';
```

`@SchemaName` selects a schema in the current database; `null` includes all schemas. `@NamePattern` uses SQL `like` patterns: `%` matches any text, and `!` escapes a special character. In the example, `!_` matches a literal underscore.

Use `@ExcludedProcedureNames` to leave specific procedure names out of the list. Separate the names with commas, for example `N'usp_DataInitializationHelper,usp_DataInitializationMaster'`. Spaces around each name are ignored. These exclusions apply to the exact names in every selected schema. Omit the parameter to exclude nothing beyond the executor itself.

Each call goes through the matching procedures once, with no retries. It calls them without parameters, so any parameters must have defaults. If nothing matches, it finishes successfully without doing any work. It excludes `z.usp_ExecuteProcedures` itself.

If a procedure raises an error, the executor rolls back any open transaction, tries to release its lock, and continues with the remaining procedures. After finishing the list, it reports the collected errors together in a message of up to 2,048 characters. A procedure's return code alone is not treated as an error.

Run this from a job connection without an enclosing transaction; each called procedure manages its own transactions. The caller needs permission to see and execute the matching procedures and use the shared semaphore helpers. To prevent simultaneous execution across jobs, all participating jobs must call through `z.usp_ExecuteProcedures`.

## z.usp_ForceNamingConvention

Renames indexes and constraints to follow Schema Z's naming conventions. Preview the proposed names with `@ShowPlan = 1`, then apply them after review. Table and schema names stay the same.

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

Select objects with the legacy `@TableName`, a JSON array of schema names in `@SchemaNames`, or a JSON array of table names in `@TableNames`. Multiple selectors are combined and duplicates are processed once. Table-list entries must be two-part names in the current database. Indexed views can contribute index candidates; ordinary views usually contribute none.

Preview returns `ObjectName`, `NewName` and `ObjectType` without renaming anything. Execution renames indexes, primary/unique keys, defaults and foreign keys. At least one selector is required. Malformed arrays, non-string or empty entries and unknown names fail validation before changes; an existing empty schema is valid. Legacy positional calls remain supported.

`@IgnoreError = 0` stops at the first failed rename; 1 prints that error and continues. Validation errors always stop the call. Renames are not wrapped in a transaction, so earlier changes can remain after a later failure. The procedure uses `xact_abort off` and does not roll back caller work. Metadata visibility and ALTER permissions determine what it can process. See [usage and migration examples](../usage.md#preview-and-enforce-naming-conventions).

## z.usp_GeneralDailyMaintenance

Runs routine partition retention and enables out-of-row storage for large-value columns. The general-maintenance Agent job calls this procedure.

[Source](../../modules/1070%20Procedures/z.usp_GeneralDailyMaintenance.sql)

```sql
create or alter procedure z.usp_GeneralDailyMaintenance
```

Retention follows the configured Partition policies and can remove data. The table-option update applies to eligible tables throughout the current database. These operations are not wrapped in one transaction and return no result set.

## z.usp_GetQueryResultToSQL

Turns a query result into SQL that recreates those rows as a `select` from a values list. Use it when preparing sample data or a script that needs a fixed result set.

[Source](../../modules/1070%20Procedures/z.usp_GetQueryResultToSQL.sql)

```sql
create or alter procedure z.usp_GetQueryResultToSQL
(
	@Query nvarchar(max),
	@SQL nvarchar(max) output
)
```

Pass trusted SQL through `@Query` and capture the generated statement with `@SQL output`. The query is executed, so its normal permissions and side effects apply. There is no internal transaction. Date/time values in the generated text use second precision; fractional seconds are truncated.

## z.usp_PrintString

Prints a long Unicode string without cutting it off at SQL Server's normal per-message limit. It keeps line breaks and empty lines so generated scripts remain readable.

[Source](../../modules/1070%20Procedures/z.usp_PrintString.sql)

```sql
create or alter procedure z.usp_PrintString
(
	@Str nvarchar(max)
)
```

Pass the text as `@Str`. Long lines are printed in chunks of at most 4,000 characters. Output goes to messages rather than a result set; no stored data changes.

## z.usp_RefeshAllSQLModules

Refreshes SQL Server's stored metadata for visible SQL modules in the current database. Use it after changes to objects that those modules reference.

[Source](../../modules/1070%20Procedures/z.usp_RefeshAllSQLModules.sql)

```sql
create or alter procedure z.usp_RefeshAllSQLModules @RefreshTimes int = 1
```

The public name is spelled `Refesh`. `@RefreshTimes` controls how many passes to make, defaulting to one. The first error stops processing with error 50000/state 12. ALTER permissions are required, and refreshing a module can remove its signature. No explicit transaction or result set is provided.

## z.usp_ReleaseSemaphore

Releases the permission previously reserved by `z.usp_AcquireSemaphore`, allowing another cooperating session to use that slot. Call it from the connection that acquired the semaphore.

[Source](../../modules/1070%20Procedures/z.usp_ReleaseSemaphore.sql)

```sql
create or alter procedure z.usp_ReleaseSemaphore
(
	@SemaphoreName nvarchar(200),
	@SuppressException bit = 0
)
```

Releases the slot for the recorded owner in the current database and session and clears its context entry on successful cleanup. NULL, blank, missing and already-released names return `0`. A native negative release status is returned to the caller. Caught exceptions are rethrown by default. With `@SuppressException = 1`, the procedure prints the exception and returns `-999`. The procedure preserves the caller's transaction and returns no result set. [Ownership and cleanup](coordination.md#semaphores)

## z.usp_RemoveSchemaZ

Removes Schema Z objects from the current database. This is the uninstall operation; review external dependencies and the removal limits before confirming it.

[Source](../../modules/1070%20Procedures/z.usp_RemoveSchemaZ.sql)

```sql
create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
```

Set `@Confirm = 1` to proceed. Removal covers `z` plan guides and schema objects, user-defined types, XML schema collections, shared AsyncChannel Broker definitions, the generic partition schemes/functions and schema `z` itself. It retries dependencies across passes but can leave objects blocked by external references. SQL Agent jobs and other external objects are not automatically removed. Broad DDL permissions are required. See [removal limits](../troubleshooting.md#removal).

## z.usp_SetLargeValueOutOfRow

Enables SQL Server's out-of-row storage option for eligible large-value columns throughout the current database. It is used by general maintenance.

[Source](../../modules/1070%20Procedures/z.usp_SetLargeValueOutOfRow.sql)

```sql
create or alter procedure z.usp_SetLargeValueOutOfRow
```

Processes tables with max-length columns where the option is currently off, including tables outside schema `z`. ALTER permission is required. The procedure returns no result set and opens no transaction.

## z.usp_SkipTrigger

Asks cooperating triggers to skip their work for the current connection. Use it around operations that deliberately manage the affected data themselves, then clear the flag afterward.

[Source](../../modules/1070%20Procedures/z.usp_SkipTrigger.sql)

```sql
create or alter procedure z.usp_SkipTrigger
(
	@ParentObjectNames nvarchar(max) = null,
	@TriggerNames nvarchar(max) = null
)
```

Choose triggers by comma-separated parent object names or trigger names, or use `all`. Calling without arguments clears the request. This does not disable SQL Server triggers: only triggers written to consult `z.fn_ShouldSkipTrigger` honor it. There is no returned result set or explicit transaction. See [trigger flags](coordination.md#trigger-flags).

## z.usp_SuppressBackupSuccessMessages

Reduces routine backup noise in the SQL Server error log and system event log for the whole instance. Failed backups remain logged, and client command output is unchanged.

[Source](../../modules/1070%20Procedures/z.usp_SuppressBackupSuccessMessages.sql)

```sql
create or alter procedure z.usp_SuppressBackupSuccessMessages
```

Enables global trace flag 3226, or returns successfully when it is already
enabled. The procedure has no parameters or result set. Enabling the flag
requires the sysadmin server role; permission and DBCC errors reach the caller.

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

Creates or updates a named text setting in the current database. See [settings](settings.md#zusp_setsetting) for examples, parameter meanings and transaction behavior.
