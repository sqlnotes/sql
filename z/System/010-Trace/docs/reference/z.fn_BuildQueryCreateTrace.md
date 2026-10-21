# z.fn_BuildQueryCreateTrace

[Trace](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql)

Return ordered setup scripts for a logical definition. The TraceID argument is a logical z.Trace identity, not sys.traces.id. Read logical configuration tables without modifying state or allocating a native trace.

```sql
select Ordinal, Script
from z.fn_BuildQueryCreateTrace(@TraceID)
order by Ordinal;
```

Scripts create the definition, add each event's selected columns, reproduce typed filters in FilterOrdinal order, register callbacks and enable the definition when currently enabled. Callbacks must exist in the target database before replay. Scripts use the logical name, so replay builds configuration in the executing session's run. They do not start collection or export persisted event data.

Requires configuration/catalog visibility. No matching logical definition returns no rows. Use the generated native definition view for native trace inspection. A native trace can no longer be exported through this function merely by passing its native numeric ID.
