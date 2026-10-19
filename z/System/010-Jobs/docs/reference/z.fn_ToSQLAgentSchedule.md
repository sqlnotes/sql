# z.fn_ToSQLAgentSchedule

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_ToSQLAgentSchedule.sql)

## Purpose and behavior

Eight shared schedule inputs -> Name nvarchar(128) and ten native integer schedule fields. Split requested days/times into combinations, consolidate weekly bitmasks, and derive deterministic `Schema z: [DatabaseName]: <native fields>` names through z.fn_GetScheduleNamePrefix. Read-only; inspect returned fields before use.

Invalid input returns no rows; no valid subset is emitted from a partially invalid list. Call z.fn_ValidateScheduleParameter with the same arguments for the diagnostic. The creation procedures raise that diagnostic as an error before modifying Agent metadata.

The database prefix is Unicode and quoted. If any complete name exceeds 128 UTF-16 code units, the entire conversion returns no rows; names are never truncated. Input validation can succeed while the combined name is too long. Shorten the database name or use a shorter definition; job creation reports the name-length limit. Names are database-specific, while schedules can be reused by jobs in the same database.

Day vocabulary uses the same explicit case-insensitive, accent-sensitive comparison as validation and normalization. Weekly masks and relative monthly fields therefore retain the complete requested meaning in case-sensitive databases. This comparison applies to schedule words, not the database prefix or native name identity.

An omitted StartDate uses the SQL Server local date; EndDate remains unlimited. Specific retains its explicit execution dates from ByDay. Returned Name rows describe the requested definition. CreateSchedule can resolve a historical every-day schedule with a different start date/name and returns its actual identity through ScheduleIDs.

## Parameters and defaults

```text
@Frequency varchar(20) = 'Daily',
@Interval int = 1,
@ByDay varchar(8000) = null,
@IntradayFrequency varchar(20) = 'Second',
@IntradayInterval int = 10,
@ByTime varchar(8000) = '00:00',
@StartDate date = null,
@EndDate date = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

Direct SQL object dependencies: `z.fn_GetScheduleNamePrefix`, `z.fn_ValidateScheduleParameter`, `z.fn_CleanseScheduleParameter`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
