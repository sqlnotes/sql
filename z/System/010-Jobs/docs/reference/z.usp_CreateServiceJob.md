# z.usp_CreateServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateServiceJob.sql)

## Purpose and behavior

Create/reconcile a database-prefixed SQL Agent job with a database availability guard in master followed by zero to ten TSQL command steps in the current database. Command through Command10 each default to NULL. Materialize the commands once in parameter order, discarding NULL, empty and ASCII-whitespace-only entries (space and characters 9 through 13). Each remaining command becomes a consecutive step; its original SQL text is preserved. If none remain, the job contains only the database guard, with success action 1 (quit reporting success). Command itself may be NULL or omitted. Every user step continues to the next step on success; the last reports success. Any user-step failure quits reporting failure.

Create database-prefixed schedules; attach resolved schedule IDs before detaching old IDs, preserving unused schedules. Reapplying updates non-NULL description/category, deletion mode and start step 1, preserving existing enabled and notification settings. Managed step names, TSQL subsystem, execution databases, routing, retries, flags and success code are restored. Existing commands retain the current collation-based comparison rule. A changed command count or missing step rebuilds the managed steps in order. Unrecognized extra steps cause rejection rather than deleting custom work. Category creation failure is swallowed and category set null. A sysadmin can set the owner to principal SID 0x01. Transaction commits metadata changes; errors rollback any open transaction and rethrow.

The complete relevant schedule input is validated before category, job or schedule writes. Invalid input or an empty conversion result raises error 51000; existing job metadata and schedule attachments are preserved. A partially invalid list is rejected as a whole. An invalid definition cannot request an unscheduled job.

The job transaction acquires the same current-database exclusive application lock as creation, removal and cleanup, before schedule creation and job lookup. A 15-second acquisition failure raises error 51001. Nested schedule creation retains the lock through all attachment changes until the actual outer transaction ends. Category creation remains outside this transaction. Reapplying an existing job definition transitions its legacy schedules without deleting schedules still used elsewhere. Installation alone does not modify Agent metadata.

The database guard preserves Unicode database names and requires known values: not in standby, ONLINE, MULTI_USER and READ_WRITE. An unknown property or any other value stops before the command step. The existing guard error and Agent routing still quit reporting success when the guard rejects execution.

An omitted StartDate uses the SQL Server local date; EndDate remains unlimited (9999-12-31). Creation captures one operation date and passes it through validation, conversion and nested schedule creation. Explicit dates and recurring ByTime defaults are unchanged. Specific derives execution dates from ByDay, ignores StartDate/EndDate, and retains date-only values as midnight.

Reuse requires the current database's literal prefix and matching native timing fields/end date. For every-day schedules (daily interval one), different start dates can share a schedule when both are on or before the captured operation date. Future starts require the same start date. Multi-day, weekly, monthly and other frequencies retain exact start-date matching. Prefer an exact date match, then the lowest schedule ID among eligible historical starts. Disabled schedules stay disabled. No existing schedule is renamed or modified.

## Parameters and defaults

```text
@Name nvarchar(255),
@Command nvarchar(max) = null,
@Description nvarchar(max) = null,
@Frequency varchar(20) = 'Daily',
@Interval int = 1,
@ByDay varchar(8000) = null,
@IntradayFrequency varchar(20) = 'Second',
@IntradayInterval int = 10,
@ByTime varchar(8000) = '00:00',
@StartDate date = null,
@EndDate date = null,
@DeleteAfterExecution int = 0,
@CategoryName nvarchar(50) = 'Schema z Jobs',
@SetJobOwnerToSA bit = 1,
@Command2 nvarchar(max) = null,
@Command3 nvarchar(max) = null,
@Command4 nvarchar(max) = null,
@Command5 nvarchar(max) = null,
@Command6 nvarchar(max) = null,
@Command7 nvarchar(max) = null,
@Command8 nvarchar(max) = null,
@Command9 nvarchar(max) = null,
@Command10 nvarchar(max) = null
```

These are the source-declared types and defaults. On update, NULL description/category retains the existing value; use an empty description to clear it. Other execution-context overrides, proxy/output settings and existing server assignments are not reconciled. Rebuilding after a command-count change or missing step recreates all managed steps with creation defaults, including execution-context, proxy and output settings. Intact step structures retain those overrides even when commands change.

## Step names and reconciliation

The guard is step 1, named `Check Database Status`. When supplied, Command uses the job name as its step name for compatibility. Optional commands use `Command 2` through `Command 10`, preserving their parameter numbers even when intervening NULL commands are omitted. Agent step IDs remain consecutive: Command followed by Command4 produces IDs 2 and 3. Supplying only Command2 creates one user step at ID 2, named Command 2, after the guard. Empty and whitespace-only commands add no steps. NULL Name raises error 50000 before category, job or schedule writes; an empty command list is valid and creates a guard-only job.

Steps 1 and 2 retain the existing managed-repair policy. Additional steps at IDs 3 through 11 must have one of the generated managed names; otherwise error 51000 rejects the operation. Steps outside IDs 1 through 11 also reject it. Generated names identify library-managed steps, so custom steps must not use those names. Managed-name swaps/cycles are repaired through temporary names. Removing optional commands removes their obsolete managed steps transactionally; an error rolls back the rebuild.

The guard's existing failure routing is distinct from user-step failure routing: guard rejection quits reporting success; a user-step failure quits reporting failure.

## Results, permissions, and limits

No defined result set. Requires relevant msdb Agent authority; job runs with configured owner context. DeleteAfterExecution uses native Agent delete levels: 0 = never, 1 = on success, 2 = on failure, 3 = on completion. NULL and values outside 0–3 raise error 51000 before metadata writes. Previously 1 meant completion; callers wanting that behavior must now pass 3. A rejected database guard quits reporting success, so deletion modes 1 and 3 can delete a guarded/skipped job. Database guard failure uses on_fail_action=1 (quit reporting success), which can obscure unavailable-database runs.

## Dependencies

Direct SQL object dependencies: `z.fn_ValidateScheduleParameter`, `z.fn_ToSQLAgentSchedule`, `z.fn_GetServiceJobName`, `z.fn_ResourceSQLScheduleOperation`, `z.usp_CreateSchedule`.

Native dependencies: `msdb.dbo.sp_add_category`, `msdb.dbo.sp_add_job`, `msdb.dbo.sp_add_jobserver`, `msdb.dbo.sp_add_jobstep`, `msdb.dbo.sp_attach_schedule`, `msdb.dbo.sp_detach_schedule`, `msdb.dbo.sp_delete_jobstep`, `msdb.dbo.sp_update_job`, `msdb.dbo.sp_update_jobstep`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobs`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
