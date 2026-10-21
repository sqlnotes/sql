# Monitoring usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select SessionID, BlockingSessionID, DurationInSecond, DatabaseName, SQLText
from z.v_ActiveSessions;

select SchemaName, TableName, ReservedKB, DataKB
from z.v_ObjectSpaceUsed;

exec z.usp_TakeSnapshotActiveSessions;
exec z.usp_CheckSystemHealthTrace;
```

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

## SQL Trace diagnostics

Read [the preset collector reference](reference/z.usp_CollectTrace.md) before running it: it builds/enables four logical definitions, merges them into one physical trace for the collector session, and enters synchronous collection with a long default duration. Configure and collect on the same connection. For a bounded custom trace, see [Trace usage](../../010-Trace/docs/usage.md#bounded-custom-trace).

Read retained daily summaries without starting collection:

```sql
select * from z.fn_TraceLongRunningQueryByDay(7);
```

Collector failures may leave owned native resources open; inspect `z.v_Trace` using NativeTraceID and run generation-safe framework cleanup from a separate privileged connection when eligible. Idle Building configuration is preserved; abandoned Collecting configuration is eligible when its owner has no active request. Native zero-drop counters do not establish complete reception.