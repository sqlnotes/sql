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
