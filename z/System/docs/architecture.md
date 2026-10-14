# System architecture

[Guide](readme.md) · [Reference](reference/readme.md)

## Schema and deployment boundaries

All children create SQL objects in `z`. Partition functions/schemes are database-level; SQL Agent jobs live in `msdb`. Folder ownership controls independent installer histories, not separate SQL schemas. [Installer metadata](../../docs/reference.md) is bootstrapped separately.

System baseline creates `z.SeqGeneralID` and the shared bigint/datetime partition functions and schemes in [SchemaZPartitionGeneric.sql](../baseline/2010%20Partitions/SchemaZPartitionGeneric.sql). Shared modules deploy before children. Partition depends on shared date/ID functions, catalog views and schema-copy helpers. Monitoring and Trace use System's shared bigint partition scheme; Partition provides boundary and retention maintenance. Root [post](../post) executes after all children.

## Initialization and orchestration

`z.usp_DataInitializationMaster` discovers initialization procedures by name, sorted alphabetically in the chosen schema (default `z`; null includes all schemas). It supplies no encompassing transaction.

Naming enforcement uses explicit schema/table selectors in `z.usp_ForceNamingConvention`. Root post passes `@SchemaNames = N'["z"]'`; no schema registry is maintained.

`z.usp_DataInitialization_PartitionedTableDataRetention` inserts/updates the generic policy: monthly, interval 1, three forward periods, six periods kept, default filegroup, archive disabled. Root post runs again during repeats and can overwrite edits to this policy.

`z.usp_GeneralDailyMaintenance` calls Partition retention then enables out-of-row large values across eligible tables in the current database. [z.usp_CreateAllServiceJobs](../post/1010%20Procedures/z.usp_CreateAllServiceJobs.sql) is defined in root post after Jobs, and calls that subsystem to create hourly maintenance and remove orphaned schedules; defining it alone does not create jobs.

## Transactions and concurrency

Functions/views do not start transactions or change persisted rows. Procedures vary: schema-copy execution uses its own transaction or a caller savepoint with `xact_abort on`, while `@ShowPlan = 1` returns scripts without transaction or generated-DDL execution; semaphores use caller-selected application-lock ownership; orchestration does not wrap all calls.

Several catch blocks roll back any open transaction, including the caller's work. Installer serialization protects metadata, not concurrent application DDL or administrative calls. Consult each reference before nesting procedures.

## Post objects and version marker

[DeprecatedObject.sql](../post/DeprecatedObject.sql) removes retired objects on each eligible repeat, grouped by object type. Schema objects are removed through `z.usp_DropObject`; unsupported partition objects use guarded statements. [GeneralPostScript.sql](../post/GeneralPostScript.sql) executes initialization and naming enforcement. [Remove-blocker post module](../post/1010%20Procedures/z.usp_RemoveBlocker.sql) defines a cross-feature helper after Jobs exists. Its [reference](reference/remove-blocker.md) describes generated temporary procedures/jobs and session termination.

Retired names and their current replacements:

| Retired object | Current object |
| --- | --- |
| `z.DatabaseSchemas` | Explicit `@SchemaNames`/`@TableNames` arguments to `z.usp_ForceNamingConvention` |
| `z.usp_DataInitialization_DatabaseSchemas` | No initialization needed; callers select naming scope explicitly |
| `z.usp_CollectInfo` | Call `z.usp_CheckSystemHealthTrace` and `z.usp_TakeSnapshotActiveSessions` directly as needed |
| `z.usp_DatabaseBackup` | `z.usp_BackupDatabase` |
| `z.usp_RemoveZSchema` | `z.usp_RemoveSchemaZ` |
| `z.v_ObjectSpaceUsage` | `z.v_IndexSpaceUsage` |
| `z._fn_SecondToTimeString` | `z.fn_FormatDurationSeconds` |
| `z.fn_ConvertToSQLAgentSchedule` | `z.fn_ToSQLAgentSchedule`, `z.fn_FromSQLAgentSchedule` |
| `z.fn_CopyTableSchema` | `z.usp_CopyTableSchema` |
| `z.fn_BuildQueryCopyTableSchema` | `z.usp_CopyTableSchema` with `@ShowPlan = 1` for script preview |
| `z.fn_GetZSequenceID` | `z.fn_GenerateZSequenceID(null, @SeqGeneralID)` |
| `z.fn_LettersOnly` | `z.fn_AsciiLettersOnly` |
| `z.fn_NumbersOnly` | `z.fn_DigitsOnly` |
| `z.fn_PreviousCommittedRowVersion` | `z.fn_GetLastCommittedRowVersion` |
| `z.fn_ReadLinesFromString` | `z.fn_SplitLines` |
| `z.fn_SecondsToTimeString` | `z.fn_FormatDurationSeconds` |
| `z.fn_StandardizeSchedule` | `z.fn_CleanseScheduleParameter` |
| `PS_zPartitionGeneric` | `PS_SchemaZPartitionGeneric` |
| `PF_zPartitionGeneric` | `PF_SchemaZPartitionGeneric` |

Update external callers before deploying; schema-bound dependencies can prevent removal. Old partition storage is retained with a message while indexes or partition schemes still reference it. Cleanup does not move table data or rewrite retention-policy rows. Add future retired names to the matching type section using an existence guard, and review dependencies before removal.

The [0.0.1 marker](../versions/0.0.1/dummy.sql) contains no database-object definition; it establishes System's initial version through installer completion.
