# Jobs usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select JobName, ServiceName, IsActive, IsExecuting
from z.v_ServiceJobs
where IszServiceJob = 1;

select *
from z.fn_ToSQLAgentSchedule('Daily', 1, null, 'Minute', 15, '08:00-17:00', default, default);
```

Schedules reside in msdb and are logically database-scoped by name. Jobs in the same database can reuse a schedule; different databases receive separate names. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

## Job names

The complete job name is `z_(DatabaseName)_Name`, returned as `nvarchar(128)`. Overlength names are silently truncated. Creation, lookup, start/stop, enable/disable and removal use the same truncated identity. Two input names with the same truncated result refer to the same job. The original input can contain up to 255 UTF-16 units; the database prefix consumes part of the stored name's 128-unit capacity.

## Job updates and automatic deletion

Reapplying a job definition updates its non-NULL description/category and deletion mode, restores managed steps and starts with the database guard. A manually disabled job remains disabled. Changing the command count or repairing missing steps rebuilds all managed steps, resetting step-specific overrides to creation defaults. Intact structures preserve execution-context, proxy and output overrides. Unknown custom extra steps cause an error and must be removed explicitly before reapplying; generated managed step names are reserved.

## Multiple commands

Supply one command per step with `@Command` through `@Command10`, each defaulting to NULL. Collect commands in parameter order and discard NULL, empty and ASCII-whitespace-only entries (space, tab, line feed, vertical tab, form feed and carriage return). Retained command text is unchanged. Supplying only `@Command2` is valid. If no commands remain, create only the database guard, which quits successfully when its check passes. Each successful user step proceeds to the next; the final one reports success. Any user-step failure stops the job with failure.

```sql
exec z.usp_CreateServiceJob
	@Name = N'Daily processing',
	@Command = N'exec dbo.usp_PrepareData;',
	@IntradayFrequency = 'Specific',
	@ByTime = '14:00',
	@Command2 = N'exec dbo.usp_ProcessData;',
	@Command3 = N'exec dbo.usp_FinishData;';
```

This creates the guard followed by three user steps. With only Command and Command4, the user steps are Agent IDs 2 and 3; the latter is named Command 4. Existing calls supplying only Command still have one user step. When supplied, Command retains the job name; Command2 through Command10 use names Command 2 through Command 10, independent of job-name length. Supplying only Command2 creates the guard and one user step, named Command 2.

`@DeleteAfterExecution` accepts the native SQL Agent values:

| Value | Delete the job |
| --- | --- |
| 0 | Never (default) |
| 1 | When it succeeds |
| 2 | When it fails |
| 3 | When it completes, regardless of outcome |

The former bit value 1 meant completion; use 3 to retain that behavior. Guard rejection currently ends the job reporting success, so modes 1 and 3 also apply to a guarded skip.

## Schedule vocabulary

Use Daily, Weekly, Monthly, Specific, Agent Start or Idle. Interval is the day/week/month recurrence count. ByDay is comma-separated weekday names for Weekly, month numbers 1..31 or relative phrases such as First Monday for Monthly, and date-time values for Specific. IntradayFrequency is Hourly, Minute, Second or Specific. ByTime accepts comma-separated HH:mm[:ss] times or time ranges; repeating schedules use ranges, Specific intraday uses times. A lone repeating start time is expanded through one second before that time, potentially representing an overnight/full-day window; inspect native output rather than assuming cross-midnight support. Explicit reversed ranges are rejected. SQL Agent remains the final validator.

Schedule keywords are case-insensitive and accent-sensitive regardless of database collation. For example, Weekly with Monday,tuesday retains both days, and monthly THIRD WEEKDAY has the same meaning as Third Weekday. Database names and the user command are preserved with their original text.

Invalid relevant inputs, including any invalid or empty list member, reject the complete definition. The creation procedures raise error 51000 before changing existing jobs or schedules. To inspect the diagnostic without making changes, call z.fn_ValidateScheduleParameter with the same eight schedule arguments; NULL means validation succeeded. Parameters unused by the selected frequency retain their existing ignored behavior; Specific derives its execution dates from ByDay and ignores supplied StartDate and EndDate. Manual-only job creation is not inferred from an empty or invalid schedule.

An omitted StartDate uses the SQL Server local date; EndDate remains unlimited (9999-12-31). Creation captures one operation date and passes it through validation, conversion and nested schedule creation. Explicit dates and recurring ByTime defaults are unchanged. Specific derives execution dates from ByDay, ignores StartDate/EndDate, and retains date-only values as midnight.

Reuse requires the current database's literal prefix and matching native timing fields/end date. For every-day schedules (daily interval one), different start dates can share a schedule when both are on or before the captured operation date. Future starts require the same start date. Multi-day, weekly, monthly and other frequencies retain exact start-date matching. Prefer an exact date match, then the lowest schedule ID among eligible historical starts. Disabled schedules stay disabled. No existing schedule is renamed or modified.

## Existing schedule changes

Schedule names encode all ten timing fields. Reuse candidates must match their own encoded timing; the historical-start exception applies only when comparing candidates with the requested definition. If a schedule was edited without being renamed, creation raises error 51000 identifying it before creating any requested schedules. Restore its timing settings or rename it before retrying; other jobs may share it. A matching schedule that was manually disabled remains disabled.

## Database ownership and transition

Schedule names include the quoted current database, for example `Schema z: [MyDatabase]: <native fields>`. The entire name must fit 128 UTF-16 code units. Overlength names reject the complete definition instead of truncating it. Unicode and commas in database names are preserved; use the JSON integer array returned through z.usp_CreateSchedule @ScheduleIDs to identify resolved schedules. Do not split the legacy comma-joined ScheduleNames display output. Converter Name rows describe the requested definition and can differ from a reused historical schedule name.

Reapply a job definition to move an existing job from shared legacy schedules to its database-owned schedules. New attachments are established before old ones are detached; unused legacy schedules are retained. Orphan cleanup removes only the current database's unattached prefixed schedules. AllOrphanedSchedules=1 now raises an error; global and legacy cleanup require separate administrative handling.

The four definition/removal/cleanup procedures share a database-local exclusive transaction lock. A competing call waits up to 15 seconds, then raises error 51001 if acquisition fails. The lock is held until the outer transaction ends. Renaming a database changes its schedule prefix and requires explicitly reapplying definitions; existing Agent metadata is not automatically renamed.
