# z.usp_CheckSystemHealthTrace

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CheckSystemHealthTrace.sql)

## Purpose and behavior

Read z.fn_ExtractSystemHealthEvent, exclude five noisy event names, construct a local-time-based CollectSystemTime and MD5 EventHash, and insert keys absent from z.SystemHealthEvent. It has no explicit transaction or catch.

## Parameters and defaults

None.

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Existing stored rows are retained; ring-buffer data only is collected.

## Dependencies

Direct SQL object dependencies: `z.SystemHealthEvent`, `z.fn_ExtractSystemHealthEvent`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
