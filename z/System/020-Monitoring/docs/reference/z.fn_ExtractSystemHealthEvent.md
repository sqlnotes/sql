# z.fn_ExtractSystemHealthEvent

[Monitoring](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_ExtractSystemHealthEvent.sql)

## Purpose and behavior

Read the system_health ring_buffer target and shred each event XML. Date converts timestamps using the current server UTC offset; DateUTC preserves the parsed UTC value. The computed row_number is not filtered, so this function does not deduplicate events.

## Parameters and defaults

None.

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Date datetime, EventName varchar(128), EventBody xml, DateUTC datetime. No write side effects; no inputs.

## Dependencies

Native dependencies: `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
