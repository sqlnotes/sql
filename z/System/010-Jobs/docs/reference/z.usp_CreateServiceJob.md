# z.usp_CreateServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateServiceJob.sql)

## Purpose and behavior

Create/reconcile a database-prefixed SQL Agent job with two TSQL steps: database availability guard in master, then Command in the current database. Create database-prefixed schedules; attach new names before detaching old ones, preserving unused schedules. Reapplying updates non-NULL description/category, deletion mode and start step 1, preserving existing enabled and notification settings. The two managed steps have their names, TSQL subsystem, execution databases, routing, retries, flags and success code restored. Existing commands retain the current collation-based comparison rule. If either step is missing, both are rebuilt in order; jobs with steps outside 1/2 are rejected rather than deleting custom work. Category creation failure is swallowed and category set null. A sysadmin can set the owner to principal SID 0x01. Transaction commits metadata changes; errors rollback any open transaction and rethrow.

The complete relevant schedule input is validated before category, job or schedule writes. Invalid input or an empty conversion result raises error 51000; existing job metadata and schedule attachments are preserved. A partially invalid list is rejected as a whole. An invalid definition cannot request an unscheduled job.

The job transaction acquires the same current-database exclusive application lock as creation, removal and cleanup, before schedule creation and job lookup. A 15-second acquisition failure raises error 51001. Nested schedule creation retains the lock through all attachment changes until the actual outer transaction ends. Category creation remains outside this transaction. Reapplying an existing job definition transitions its legacy schedules without deleting schedules still used elsewhere. Installation alone does not modify Agent metadata.

The database guard preserves Unicode database names and requires known values: not in standby, ONLINE, MULTI_USER and READ_WRITE. An unknown property or any other value stops before the command step. The existing guard error and Agent routing still quit reporting success when the guard rejects execution.

## Parameters and defaults

```text
@Name nvarchar(255), @Command nvarchar(max), @Description nvarchar(max) = null, @Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null,@DeleteAfterExecution int = 0, @CategoryName nvarchar(50) = 'Schema z Jobs',@SetJobOwnerToSA bit = 1
```

These are the source-declared types and defaults. On update, NULL description/category retains the existing value; use an empty description to clear it. Other execution-context overrides, proxy/output settings and existing server assignments are not reconciled. Rebuilding missing steps recreates their original defaults.

## Results, permissions, and limits

No defined result set. Requires relevant msdb Agent authority; job runs with configured owner context. DeleteAfterExecution uses native Agent delete levels: 0 = never, 1 = on success, 2 = on failure, 3 = on completion. NULL and values outside 0–3 raise error 51000 before metadata writes. Previously 1 meant completion; callers wanting that behavior must now pass 3. A rejected database guard quits reporting success, so deletion modes 1 and 3 can delete a guarded/skipped job. Database guard failure uses on_fail_action=1 (quit reporting success), which can obscure unavailable-database runs.

## Dependencies

Direct SQL object dependencies: `z.fn_ValidateScheduleParameter`, `z.fn_ToSQLAgentSchedule`, `z.fn_GetServiceJobName`, `z.fn_ResourceSQLScheduleOperation`, `z.usp_CreateSchedule`.

Native dependencies: `msdb.dbo.sp_add_category`, `msdb.dbo.sp_add_job`, `msdb.dbo.sp_add_jobserver`, `msdb.dbo.sp_add_jobstep`, `msdb.dbo.sp_attach_schedule`, `msdb.dbo.sp_detach_schedule`, `msdb.dbo.sp_delete_jobstep`, `msdb.dbo.sp_update_job`, `msdb.dbo.sp_update_jobstep`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobs`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
