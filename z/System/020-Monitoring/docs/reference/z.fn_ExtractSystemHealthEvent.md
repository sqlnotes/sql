# z.fn_ExtractSystemHealthEvent

[Monitoring](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_ExtractSystemHealthEvent.sql)

## Purpose and behavior

Inline table-valued XML decoder, following the same input/return structure as
z.fn_ExtractErrorEvent and z.fn_ExtractLongRunningQueryEvent. Shreds each event
under RingBufferTarget in the supplied XML. It does not read server DMVs, convert
to local time, filter event names or deduplicate rows. The collector owns server
access, event filtering and persistence.

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
