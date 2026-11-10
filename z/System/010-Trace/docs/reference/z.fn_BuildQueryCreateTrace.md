# z.fn_BuildQueryCreateTrace

[Trace](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql)

Return ordered setup scripts for one registered native TraceID. Read configuration without allocating or modifying a trace.

```sql
select Ordinal, Script
from z.fn_BuildQueryCreateTrace(@TraceID)
order by Ordinal;
```

Scripts create a native trace by name in the executing session, add configured events/columns and typed native filters, register callbacks, and start it if the source trace is running. The newly allocated native ID can differ from the source ID. Callbacks must exist in the destination database. Scripts do not start collection or export event data. Requires configuration/catalog visibility; an unknown ID returns no rows.
