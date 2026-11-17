# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.fn_GetJobIDFromJobName

[Source](../../modules/1010%20Functions/z.fn_GetJobIDFromJobName.sql)

JobName nvarchar(128) -> uniqueidentifier: parse the fixed SQLAgent TSQL JobStep program_name binary-ID position using try_convert; malformed text can return null.

### Parameters and defaults

```text
@JobName nvarchar(128)
```

## z.fn_GetServiceJobID

[Source](../../modules/1010%20Functions/z.fn_GetServiceJobID.sql)

Name nvarchar(255) -> uniqueidentifier: visible msdb job with z.fn_GetServiceJobName; null if absent.

### Parameters and defaults

```text
@Name nvarchar(255)
```

## z.fn_GetServiceJobName

[Source](../../modules/1010%20Functions/z.fn_GetServiceJobName.sql)

Name nvarchar(255) -> nvarchar(128): z_ + parenthesized current database + _ + Name; read-only. The complete name intentionally uses native nvarchar(128) truncation. Names differing only beyond that limit identify the same job; no collision check or hash is added.

### Parameters and defaults

```text
@Name nvarchar(255)
```

## z.fn_IsSQLAgentRunning

[Source](../../modules/1010%20Functions/z.fn_IsSQLAgentRunning.sql)

No inputs -> int: 1 if any visible session program_name matches %SQLAgent%, otherwise 0; this is a session heuristic.

### Parameters and defaults

None.

## z.fn_ResourceSQLScheduleOperation

[Source](../../modules/1010%20Functions/z.fn_ResourceSQLScheduleOperation.sql)

No inputs -> nvarchar(100): constant z.fn_ResourceSQLScheduleOperation used by the database-local exclusive transaction-owned job/schedule application lock.

### Parameters and defaults

None.

## z.fn_SQLAgentScheduleTimeToTime

[Source](../../modules/1010%20Functions/z.fn_SQLAgentScheduleTimeToTime.sql)

Time int -> time(0): zero-pad to six digits then interpret HHMMSS; invalid values can raise conversion errors.

### Parameters and defaults

```text
@Time as int
```

## z.fn_IsSQLJobRunning

[Source](../../modules/1010%20Functions/z.fn_IsSQLJobRunning.sql)

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

All visible msdb jobs, with JobID, JobName, Description, IsActive, IsExecuting, IszServiceJob, ServiceName. IszServiceJob flags this database prefix; filter explicitly. IsExecuting relies on SQLAgent program_name containing binary job ID.
