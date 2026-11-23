# System architecture

[Guide](readme.md) · [Reference](reference/readme.md)

System supplies the common utilities used by the feature modules. Use this page to understand how those modules fit together, what installation sets up, and which operations can affect a caller's transaction. For individual tasks and examples, start with [Using System](usage.md).

## Schema and deployment boundaries

All children create SQL objects in `z`. Partition functions/schemes are database-level; SQL Agent jobs live in `msdb`. Folder ownership controls independent installer histories, not separate SQL schemas. [Installer metadata](../../docs/reference.md) is bootstrapped separately.

System baseline creates `z.SeqGeneralID` and the shared bigint/datetime partition functions and schemes in [SchemaZPartitionGeneric.sql](../baseline/2010%20Partitions/SchemaZPartitionGeneric.sql). Shared modules deploy before children. Partition depends on shared date/ID functions, catalog views and schema-copy helpers. Monitoring and Trace use System's shared bigint partition scheme; Partition provides boundary and retention maintenance. Root [post](../post) executes after all children.

## Initialization and orchestration

`z.usp_DataInitializationMaster` uses `z.usp_ExecuteProcedures` to run procedures whose names start with `usp_DataInitialization`, excluding Helper and Master, one at a time in schema and name order (default schema `z`; null includes all schemas). Each initialization procedure manages its own transactions. Errors are collected while the remaining procedures run, then reported at the end. Use a single initializer when each procedure should run once; overlapping calls can repeat procedures that another call has already finished.

Naming enforcement uses explicit schema/table selectors in `z.usp_ForceNamingConvention`. Root post passes `@SchemaNames = N'["z"]'`; no schema registry is maintained.

`z.usp_DataInitialization_PartitionedTableDataRetention` inserts missing generic bigint/datetime policies: monthly, interval 1, three future boundaries, an expiration cutoff six intervals before the current period, default filegroup, archive disabled. Root post runs again during repeats and preserves existing policy values.

`z.usp_GeneralDailyMaintenance` calls Partition retention then enables out-of-row large values across eligible tables in the current database. [z.usp_CreateAllServiceJobs](../890-SystemBeforePost/1010%20Procedures/z.usp_CreateAllServiceJobs.sql) is defined in 890-SystemBeforePost after Jobs; root post calls it to create or reconcile hourly maintenance and remove orphaned schedules.

## Transactions and concurrency

Product errors use `throw`, including error scripts returned by partition builders. Explicit replacements retain error number 50000, severity 16 and their existing message text; parameterized messages are formatted before throwing. `throw` honors `xact_abort`, so validation failures can make an active caller transaction uncommittable. Partition entry guards deliberately use `xact_abort off` before rejecting a caller transaction, preserving that guard's existing transaction contract. Procedure session settings return to the caller's settings when the procedure exits.

Functions/views do not start transactions or change persisted rows. Procedures vary: schema-copy execution uses its own transaction or a caller savepoint with `xact_abort on`, while `@ShowPlan = 1` returns scripts without transaction or generated-DDL execution; semaphores use caller-selected application-lock ownership; orchestration does not wrap all calls.

Several catch blocks roll back any open transaction, including the caller's work. Installer serialization protects metadata, not concurrent application DDL or administrative calls. Consult each reference before nesting procedures.

## Post objects and version marker

[DeprecatedObject.sql](../post/DeprecatedObject.sql) removes System-owned retired objects on each eligible repeat, grouped by object type. Feature subsystems own their retired-object cleanup in their own `post` folders: [Jobs](../010-Jobs/post/DeprecatedObject.sql), [TaskQueue](../012-TaskQueue/post/DeprecatedObject.sql), [Backup](../020-Backup/post/DeprecatedObject.sql) and [Monitoring](../020-Monitoring/post/DeprecatedObject.sql). Each cleanup runs after its owning subsystem's replacement modules. Schema objects are removed through `z.usp_DropObject`; unsupported partition objects use guarded statements. [GeneralPostScript.sql](../post/GeneralPostScript.sql) executes initialization, naming enforcement and general-maintenance job setup. [Remove-blocker pre-post module](../890-SystemBeforePost/1010%20Procedures/z.usp_RemoveBlocker.sql) defines a cross-feature helper in 890-SystemBeforePost after Jobs exists. Its [reference](reference/remove-blocker.md) describes generated temporary procedures/jobs and session termination.

Retired names and their current replacements:

| Retired object | Current object |
| --- | --- |
| `z.DatabaseSchemas` | Explicit `@SchemaNames`/`@TableNames` arguments to `z.usp_ForceNamingConvention` |
| `z.usp_DataInitialization_DatabaseSchemas` | No initialization needed; callers select naming scope explicitly |
| `z.usp_CheckSystemHealthTrace` | `z.usp_CollectSystemHealthEvents` |
| `z.usp_CollectInfo` | Call `z.usp_CollectSystemHealthEvents` and `z.usp_TakeSnapshotActiveSessions` directly as needed |
| `z.usp_DatabaseBackup` | `z.usp_BackupDatabase` |
| `z.usp_RemoveZSchema` | `z.usp_RemoveSchemaZ` |
| `z.v_ObjectSpaceUsage` | `z.v_IndexSpaceUsed` |
| `z.v_IndexSpaceUsage` | `z.v_IndexSpaceUsed` |
| `z._fn_SecondToTimeString` | `z.fn_FormatDurationSeconds` |
| `z.fn_ConvertToSQLAgentSchedule` | `z.fn_ToSQLAgentSchedule`, `z.fn_FromSQLAgentSchedule` |
| `z.fn_CopyTableSchema` | `z.usp_CopyTableSchema` |
| `z.fn_BuildQueryCopyTableSchema` | `z.usp_CopyTableSchema` with `@ShowPlan = 1` for script preview |
| `z.fn_GetZSequenceID` | `z.fn_GenerateZSequenceID(null, @SeqGeneralID)` |
| `z.fn_LettersOnly` | `z.fn_ASCIILettersOnly` |
| `z.fn_NumbersOnly` | `z.fn_DigitsOnly` |
| `z.fn_PreviousCommittedRowVersion` | `z.fn_GetLastCommittedRowVersion` |
| `z.fn_ReadLinesFromString` | `z.fn_SplitLines` |
| `z.fn_SecondsToTimeString` | `z.fn_FormatDurationSeconds` |
| `z.fn_StandardizeSchedule` | `z.fn_CleanseScheduleParameter` |
| `PS_zPartitionGeneric` | `PS_SchemaZPartitionGeneric` |
| `PF_zPartitionGeneric` | `PF_SchemaZPartitionGeneric` |

Update external callers before deploying; schema-bound dependencies can prevent removal. Old partition storage is retained with a message while indexes or partition schemes still reference it. Cleanup does not move table data or rewrite retention-policy rows. Add future retired names to the owning subsystem's `post` cleanup, grouped by object type, and review dependencies before removal. Keep only System-owned retirement in System's post script.

The [0.0.1 marker](../versions/0.0.1/dummy.sql) contains no database-object definition; it establishes System's initial version through installer completion.

## Database settings

System owns [z.Settings and its helpers](reference/settings.md). The guarded table is in baseline, and the getter and setter are in modules. The installer includes baseline when a subsystem has no version folders or when its installed version is 0.0.0 or equals the first version in `versions/`, so System's baseline remains eligible on existing 0.0.1 installations and hash checking skips unchanged ordinary scripts. Installed versions above the first version folder skip baseline. No settings are seeded or consumed automatically.
