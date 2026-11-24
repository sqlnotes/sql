# z.fn_ParseScheduleName

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_ParseScheduleName.sql)

## Purpose and behavior

Reads the timing information encoded in a Schema Z schedule name and returns readable schedule settings. Use it to inspect a name without looking up or changing the schedule in `msdb`.

`@ScheduleName` can use the current format, `Schema z: [DatabaseName]: <native fields>`, or the legacy format without a database prefix. Names belonging to another database can also be inspected. The result uses the normalized schedule columns returned by [z.fn_FromSQLAgentSchedule](z.fn_FromSQLAgentSchedule.md). Malformed names can return no rows; invalid dates can raise an error.

## Parameters and defaults

```text
@ScheduleName nvarchar(128)
```

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

Direct SQL object dependencies: `z.fn_FromSQLAgentSchedule`, `z.fn_SplitString`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
