# z.fn_ExtractSystemHealthEvent

[Monitoring](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_ExtractSystemHealthEvent.sql)

## Purpose and behavior

Turns a `system_health` ring-buffer XML snapshot into one queryable row per event, including UTC time, name and original XML. Use it when you already have the target XML and want to inspect or filter it yourself. To read the live server buffer and save selected events, use `z.usp_CollectSystemHealthEvents` instead.

Like the Error and Long Running Query extractors, this function only decodes the XML supplied by its caller. It does not access the server, change time zones, filter event names or remove repeated events.

## Parameters and defaults

```text
@TargetData xml
```

No default. Callers supply the target XML explicitly; null or empty XML returns
no events.

## Results, permissions, and limits

Returns EventDateUTC datetime, EventName nvarchar(128), EventHash uniqueidentifier,
and EventBody xml in that order. UTC timestamps use the same offset normalization
as the other event extractors. EventHash is the MD5 of the original event XML
converted to varbinary(max). EventBody retains the full original timestamp;
EventDateUTC has SQL datetime precision. No write side effects or server access.

The former no-argument function and Date/DateUTC outputs are replaced by this
XML-input interface. Update external callers together with the collector.

## Dependencies and deployment

No native DMV dependencies. XML methods and built-in time/hash functions are used.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md)
for subsystem-wide constraints.
