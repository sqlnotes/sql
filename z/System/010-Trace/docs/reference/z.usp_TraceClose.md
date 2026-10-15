# z.usp_TraceClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceClose.sql)

## Purpose and behavior

Select z.v_Trace by optional Name/ID and, by default, CreatorSessionID=@@spid. Stop running traces, close available traces and delete unavailable metadata rows (cascading callbacks). Null name and ID select all traces within session scope. CurrentSessionOnly=0 widens selection across creators. No explicit transaction or catch.

## Parameters and defaults

```text
@TraceName varchar(128) = null,@TraceID int = null,@CurrentSessionOnly bit = 1
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE and applicable metadata access. Native trace changes are server-level resources; do not confuse this selector with database isolation.

## Dependencies

Direct SQL object dependencies: `z.v_Trace`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
