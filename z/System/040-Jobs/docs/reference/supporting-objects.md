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

Name nvarchar(255) -> nvarchar(255): z_ + parenthesized current database + _ + Name; read-only.

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

No inputs -> nvarchar(100): constant z.fn_ResourceSQLScheduleOperation used as shared semaphore resource.

### Parameters and defaults

None.

## z.fn_SQLAgentScheduleTimeToTime

[Source](../../modules/1010%20Functions/z.fn_SQLAgentScheduleTimeToTime.sql)

Time int -> time(0): zero-pad to six digits then interpret HHMMSS; invalid values can raise conversion errors.

### Parameters and defaults

```text
@Time as int
```

## z.v_ServiceJobs

[Source](../../modules/1020%20Views/z.v_ServiceJobs.sql)

All visible msdb jobs, with JobID, JobName, Description, IsActive, IsExecuting, IszServiceJob, ServiceName. IszServiceJob flags this database prefix; filter explicitly. IsExecuting relies on SQLAgent program_name containing binary job ID.
