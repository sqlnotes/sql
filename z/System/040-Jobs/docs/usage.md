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

Schedules are shared server objects. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

## Schedule vocabulary

Use Daily, Weekly, Monthly, Specific or Idle. Agent-start conversion currently has a known defect. Interval is the day/week/month recurrence count. ByDay is comma-separated weekday names for Weekly, month numbers 1..31 or relative phrases such as First Monday for Monthly, and date-time values for Specific. IntradayFrequency is Hourly, Minute, Second or Specific. ByTime accepts comma-separated HH:mm[:ss] times or time ranges; repeating schedules use ranges, Specific intraday uses times. A lone repeating start time is expanded through one second before that time, potentially representing an overnight/full-day window; inspect native output rather than assuming cross-midnight support. SQL Agent remains the final validator.
