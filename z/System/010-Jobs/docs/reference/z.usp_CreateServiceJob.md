# z.usp_CreateServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateServiceJob.sql)

## Purpose and behavior

Creates a SQL Server Agent job for the current database, or updates the existing job with the same name. Supply up to ten T-SQL commands; Agent runs them in order after checking that the database is available.

`@Name` is the service name, without the database prefix. `@Command` through `@Command10` contain the work to run. The schedule parameters describe when Agent should run it; see [schedule vocabulary](../usage.md#schedule-vocabulary). Use `@CreateSchedule = 0` for a job you will start manually, and the optional `@JobName` and `@JobID` outputs to identify the resulting Agent job.

The database check requires ONLINE, MULTI_USER, READ_WRITE status outside standby. A rejected check ends the job reporting success without running user commands. A failed user command ends the job reporting failure.

The complete schedule is validated before job or schedule changes. `@CreateSchedule = 0` ignores schedule inputs and removes the job's schedule attachments while retaining the schedules themselves; NULL is invalid. See [schedule matching, dates and validation](z.usp_CreateSchedule.md).

Definition changes wait up to 15 seconds for another change in the same database. Lock acquisition failure raises 51001. A transactional failure rolls back the active transaction, including a caller's transaction; category creation can remain applied. Setting `@SetJobOwnerToSA = 1` lets a sysadmin assign ownership to the built-in administrator login.

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
@Command10 nvarchar(max) = null,
@CreateSchedule bit = 1,
@JobName nvarchar(128) = null output,
@JobID uniqueidentifier = null output
```

Reapplying preserves enabled and notification settings, server assignments, and any description/category passed as NULL. An empty description clears it. A changed command count or missing step rebuilds all managed steps with default execution context, proxy and output settings. Intact steps retain those overrides.

## Step names and reconciliation

The guard is step 1, named `Check Database Status`. When supplied, Command uses the job name as its step name for compatibility. Optional commands use `Command 2` through `Command 10`, preserving their parameter numbers even when intervening NULL commands are omitted. Agent step IDs remain consecutive: Command followed by Command4 produces IDs 2 and 3. Supplying only Command2 creates one user step at ID 2, named Command 2, after the guard. NULL, empty and ASCII-whitespace-only commands add no steps. Remaining commands retain their original text and order. NULL Name raises error 50000 before category, job or schedule writes; an empty command list is valid and creates a guard-only job.

Reapplying a definition repairs the managed steps and removes commands omitted from the new definition. Custom extra steps are rejected with error 51000 rather than silently overwritten: steps outside IDs 1 through 11, and unrecognized names at IDs 3 through 11, are not accepted. The first two step positions retain the existing repair policy. Do not use the generated names for custom steps. An error rolls back a managed-step rebuild.

## Results, permissions, and limits

No defined result set. Optional `@JobName` and `@JobID` output parameters return
the actual database-prefixed job name and its `msdb.dbo.sysjobs.job_id` after
successful creation or reconciliation. Both default to NULL. The full name uses
the existing 128-character naming limit and accepted truncation behavior.
Outputs are cleared on entry and populated together only after the procedure's
COMMIT succeeds. When called inside a transaction, the caller still owns the
outer commit; a later caller rollback can undo the job changes.

Errors continue to propagate through THROW. SQL Server can skip copying output
parameters back when an exception propagates, so initialize T-SQL receiving variables
to NULL before each call, and clear them in the caller's CATCH if they are reused.
The procedure cannot clear a caller's pre-existing values when copy-out is skipped.

```sql
declare @JobName nvarchar(128), @JobID uniqueidentifier;
exec z.usp_CreateServiceJob @Name = N'Example', @Command = N'select 1;',
	@CreateSchedule = 0, @SetJobOwnerToSA = 0,
	@JobName = @JobName output, @JobID = @JobID output;
select @JobName JobName, @JobID JobID;
```

Requires relevant msdb Agent authority; job runs with configured owner context. DeleteAfterExecution uses native Agent delete levels: 0 = never, 1 = on success, 2 = on failure, 3 = on completion. NULL and values outside 0–3 raise error 51000 before metadata writes. Previously 1 meant completion; callers wanting that behavior must now pass 3. A rejected database guard quits reporting success, so deletion modes 1 and 3 can delete a guarded/skipped job.

## Dependencies

Direct SQL object dependencies: `z.fn_ValidateScheduleParameter`, `z.fn_ToSQLAgentSchedule`, `z.fn_GetServiceJobName`, `z.fn_ResourceSQLScheduleOperation`, `z.usp_CreateSchedule`.

Native dependencies: `msdb.dbo.sp_add_category`, `msdb.dbo.sp_add_job`, `msdb.dbo.sp_add_jobserver`, `msdb.dbo.sp_add_jobstep`, `msdb.dbo.sp_attach_schedule`, `msdb.dbo.sp_detach_schedule`, `msdb.dbo.sp_delete_jobstep`, `msdb.dbo.sp_update_job`, `msdb.dbo.sp_update_jobstep`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobs`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
