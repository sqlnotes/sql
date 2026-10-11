# System architecture

[Guide](readme.md) · [Reference](reference/readme.md)

## Schema and deployment boundaries

All children create SQL objects in `z`. Partition functions/schemes are database-level; SQL Agent jobs live in `msdb`. Folder ownership controls independent installer histories, not separate SQL schemas. [Installer metadata](../../docs/reference.md) is bootstrapped separately.

System baseline creates `z.SeqGeneralID` and `z.DatabaseSchemas`. Shared modules deploy before children. Partition depends on shared date/ID functions, catalog views and schema-copy helpers. Monitoring and Trace depend on Partition. Root [post](../post) executes after all children.

## Initialization and orchestration

`z.usp_DataInitializationMaster` discovers initialization procedures by name, sorted alphabetically in the chosen schema (default `z`; null includes all schemas). It supplies no encompassing transaction.

`z.usp_DataInitialization_DatabaseSchemas` inserts `z` if absent. This table selects schemas for untargeted naming enforcement.

`z.usp_DataInitialization_PartitionedTableDataRetention` inserts/updates the generic policy: monthly, interval 1, three forward periods, six periods kept, default filegroup, archive disabled. Root post runs again during repeats and can overwrite edits to this policy.

`z.usp_CollectInfo` calls Monitoring health and session collectors. `z.usp_GeneralDailyMaintenance` calls Partition retention then enables out-of-row large values across eligible tables in the current database. `z.usp_CreateAllServiceJobs` calls Jobs to create hourly maintenance and remove orphaned schedules; defining it alone does not create jobs.

## Transactions and concurrency

Functions/views do not start transactions or change persisted rows. Procedures vary: schema-copy starts a transaction with `xact_abort on`; semaphores use caller-selected application-lock ownership; orchestration does not wrap all calls.

Several catch blocks roll back any open transaction, including the caller's work. Installer serialization protects metadata, not concurrent application DDL or administrative calls. Consult each reference before nesting procedures.

## Post objects and version marker

[GeneralPostScript.sql](../post/GeneralPostScript.sql) executes initialization and naming enforcement on each eligible repeat, then drops legacy `z.usp_DatabaseBackup` if present. [Remove-blocker post module](../post/1010%20Procedures/z.usp_RemoveBlocker.sql) defines a cross-feature helper after Jobs exists. Its [reference](reference/remove-blocker.md) describes generated temporary procedures/jobs and session termination.

The [0.0.1 marker](../versions/0.0.1/dummy.sql) contains no database-object definition; it establishes System's initial version through installer completion.