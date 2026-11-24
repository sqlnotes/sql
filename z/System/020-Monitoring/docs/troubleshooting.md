# Monitoring troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

The active-request collector excludes its own session. An empty snapshot can mean there were no other visible requests. Check DMV permissions before interpreting the result.

System Health needs a running session with a ring-buffer target. It deduplicates events in one snapshot. Two concurrent collectors can both select the same missing key. The primary key prevents duplicate storage, so one insert may fail. Coordinate calls when they can overlap.

For index space, use the page counts or KB columns for exact calculations. The compatibility columns labeled MB keep the original conversion. [Space columns](reference/supporting-objects.md#zv_indexspaceused)

## Extended Events

For the Error/Long Running Query XE collectors, an empty poll can mean the session
has no dispatched events or has no ring_buffer target. The collectors call their
matching creator first, creating absent sessions and starting stopped ones. Existing definitions are
not repaired by create-if-absent calls. Inspect target XML truncated/dropped
attributes and polling frequency when events are missing; a 4096-KB ring buffer
can still exceed the 4-MB XML conversion ceiling. See the
[Extended Events reference](reference/extended-events.md).
