# z.usp_GetJobStatus

[Jobs](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_GetJobStatus.sql)

## Purpose and parameters

Shows whether SQL Server Agent jobs are enabled, what they are currently doing, and the outcome of their last run. Use it for one job or all jobs visible to the caller; it does not change them.

```sql
@JobID uniqueidentifier = null,
@JobName sysname = null
```

Pass either a job ID or the complete SQL Agent job name. The name is passed
unchanged; the procedure does not add the service-job database prefix. If both
parameters are NULL, return all jobs visible to the caller, including jobs
outside the current database's service-job prefix. A blank name is treated as
absent by the native procedure. Supplying both an ID and a nonblank name is a
native error, even when they identify the same job. Unknown jobs and permission errors also
follow native behavior.

## Results

Return the native job-summary result set unchanged. Relevant columns include:

| Column | Meaning |
| --- | --- |
| `job_id`, `name` | Native job identity |
| `enabled` | Whether the job is enabled |
| `current_execution_status` | Current execution state code |
| `current_execution_step` | Current step |
| `current_retry_attempt` | Current retry count |
| `last_run_outcome` | Previous run's outcome, separate from current state |

The procedure returns job summaries only, without separate step, schedule or target result sets. Columns and status codes are the native Agent values. Native return codes and errors propagate, and the procedure does not grant additional permissions.
See [Microsoft's sp_help_job reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-help-job-transact-sql)
for the full schema, status codes and required msdb roles.

## Examples

```sql
-- All visible jobs.
exec z.usp_GetJobStatus;

-- An exact full SQL Agent job name.
exec z.usp_GetJobStatus @JobName = N'z_(sql)_Example';

-- A job ID returned by usp_CreateServiceJob.
declare @JobID uniqueidentifier = '11111111-1111-1111-1111-111111111111';
exec z.usp_GetJobStatus @JobID = @JobID;
```
