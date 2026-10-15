# z.usp_CreateServiceJob

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CreateServiceJob.sql)

## Purpose and behavior

Create/reconcile a database-prefixed SQL Agent job with two TSQL steps: database availability guard in master, then Command in the current database. Create desired schedules; detach old names and attach new ones. Existing steps 1/2 are updated only when commands differ; missing steps are not repaired, and description/category/delete level are not fully reconciled. Category creation failure is swallowed and category set null. A sysadmin can set the owner to principal SID 0x01. Transaction commits metadata changes; errors rollback any open transaction and rethrow.

## Parameters and defaults

```text
@Name nvarchar(255), @Command nvarchar(max), @Description nvarchar(max) = null, @Frequency varchar(20) = 'Daily', @Interval int = 1, @ByDay varchar(8000) = null,@IntradayFrequency varchar(20) = 'Second', @IntradayInterval int = 10,@ByTime varchar(8000) = '00:00',@StartDate date = null,@EndDate date = null,@DeleteAfterExecution bit = 0, @CategoryName nvarchar(50) = 'Schema z Jobs',@SetJobOwnerToSA bit = 1
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires relevant msdb Agent authority; job runs with configured owner context. DeleteAfterExecution=1 sets Agent delete_level=3. Database guard failure uses on_fail_action=1 (quit reporting success), which can obscure unavailable-database runs.

## Dependencies

Direct SQL object dependencies: `z.fn_GetServiceJobName`, `z.usp_CreateSchedule`.

Native dependencies: `msdb.dbo.sp_add_category`, `msdb.dbo.sp_add_job`, `msdb.dbo.sp_add_jobserver`, `msdb.dbo.sp_add_jobstep`, `msdb.dbo.sp_attach_schedule`, `msdb.dbo.sp_detach_schedule`, `msdb.dbo.sp_update_job`, `msdb.dbo.sp_update_jobstep`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobs`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
