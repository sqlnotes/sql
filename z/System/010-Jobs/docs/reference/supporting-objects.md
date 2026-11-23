# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

These helpers identify database-owned jobs, interpret Agent session information, and list jobs for inspection. They support the creation and lifecycle procedures; most applications need only the job IDs and status checks below.

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.fn_GetJobIDFromJobName

[Source](../../modules/1010%20Functions/z.fn_GetJobIDFromJobName.sql)

Extracts a job ID from the application name of a SQL Agent T-SQL step session. Despite the parameter name, `@JobName` is that session's `program_name` text, not a friendly job name. The result is a `uniqueidentifier`; unrecognized or malformed text can return NULL.

### Parameters and defaults

```text
@JobName nvarchar(128)
```

## z.fn_GetServiceJobID

[Source](../../modules/1010%20Functions/z.fn_GetServiceJobID.sql)

Finds the Agent job ID for a service name in the current database. Pass `@Name` without the database prefix. It returns the visible job's `uniqueidentifier`, or NULL if no matching job is found.

### Parameters and defaults

```text
@Name nvarchar(255)
```

## z.fn_GetServiceJobName

[Source](../../modules/1010%20Functions/z.fn_GetServiceJobName.sql)

Builds the complete Agent job name for a service name: `z_(DatabaseName)_Name`. Pass the unprefixed service name in `@Name`; the result is `nvarchar(128)`. The complete name is truncated at that limit, so inputs differing only beyond it refer to the same job.

### Parameters and defaults

```text
@Name nvarchar(255)
```

## z.fn_IsSQLAgentRunning

[Source](../../modules/1010%20Functions/z.fn_IsSQLAgentRunning.sql)

Checks whether any visible session appears to belong to SQL Server Agent. There are no parameters. It returns integer 1 when such a session is found and 0 otherwise. This is a session-based indication, not a service-control or job-history check.

### Parameters and defaults

None.

## z.fn_ResourceSQLScheduleOperation

[Source](../../modules/1010%20Functions/z.fn_ResourceSQLScheduleOperation.sql)

Returns the shared coordination name used to serialize this database's job and schedule changes. There are no parameters; the `nvarchar(100)` value is `z.fn_ResourceSQLScheduleOperation`. It identifies the lock resource without acquiring a lock.

### Parameters and defaults

None.

## z.fn_SQLAgentScheduleTimeToTime

[Source](../../modules/1010%20Functions/z.fn_SQLAgentScheduleTimeToTime.sql)

Converts an Agent schedule's integer time to `time(0)`. For example, pass `93000` to obtain `09:30:00`. Invalid times can raise conversion errors.

### Parameters and defaults

```text
@Time as int
```

## z.fn_IsSQLJobRunning

[Source](../../modules/1010%20Functions/z.fn_IsSQLJobRunning.sql)

Checks whether a particular Agent job currently has a visible local T-SQL step session. Use it in a query when you need a bit-valued running check rather than a job-summary result set.

```sql
@JobID uniqueidentifier
```

Returns `bit`: 1 when a visible local session has a program_name matching
`SQLAgent - TSQL JobStep (Job 0x<32 hexadecimal digits> : Step ...)` for this
job ID; otherwise 0. NULL also returns 0. The ID is converted through binary(16)
to match Agent's native GUID byte order, rather than the printable GUID text.
Any matching step session counts, including a waiting, blocked or sleeping one.

This is a local T-SQL step-session observation. A 0 means no matching visible
session. Job metadata is not consulted. It does not report previous outcome,
non-T-SQL steps, remote execution, or periods when the job has no T-SQL step
session, such as a gap between steps. Application names are client-supplied;
this is not an execution-ownership or security check.

No permission elevation is performed. Seeing other sessions requires
`VIEW SERVER STATE` on SQL Server 2019 or `VIEW SERVER PERFORMANCE STATE` on
SQL Server 2022 and later. See Microsoft's
[sys.dm_exec_sessions reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql).

Use it directly in T-SQL without capturing a stored-procedure result set:

```sql
select z.fn_IsSQLJobRunning(@JobID) IsRunning;

select j.job_id JobID, j.name JobName, z.fn_IsSQLJobRunning(j.job_id) IsRunning
from msdb.dbo.sysjobs j;
```

## z.v_ServiceJobs

[Source](../../modules/1020%20Views/z.v_ServiceJobs.sql)

Lists visible SQL Agent jobs with their identity, description, enabled state and detected execution state. `IszServiceJob` identifies jobs using the current database's prefix; filter on it when you want only this database's service jobs. `ServiceName` is the name without that prefix. `IsExecuting` uses the same session-based detection limits described above.

Returned columns are `JobID`, `JobName`, `Description`, `IsActive`, `IsExecuting`, `IszServiceJob` and `ServiceName`.
