# z.fn_ParseScheduleName

[Jobs](../readme.md) | [Source](../../modules/1020%20Functions/z.fn_ParseScheduleName.sql)

## Purpose and behavior

ScheduleName varchar(128) -> normalized schedule columns. Require Schema z: prefix and ten hyphen-separated integer fields; parse through System z.fn_SplitString and z.fn_FromSQLAgentSchedule. Malformed names can return no rows; invalid dates can throw.

## Parameters and defaults

```text
@ScheduleName varchar(128)
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

No writes or explicit transaction. Requires function access; schedule conversion does not validate a deployed Agent schedule. See subsystem troubleshooting for known conversion defects.

## Dependencies

Direct SQL object dependencies: `z.fn_FromSQLAgentSchedule`, `z.fn_SplitString`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
