# z.fn_BuildQueryCreateTrace

[Trace](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCreateTrace.sql)

Produces a script to recreate the configuration of a registered trace. Use it to save or transfer the chosen events, columns, filters and callbacks. It does not copy captured event data or change the source trace.

```sql
select Ordinal, Script
from z.fn_BuildQueryCreateTrace(@TraceID)
order by Ordinal;
```

Pass the source trace ID in `@TraceID`. The result contains `Ordinal` and `Script`; read or execute the statements in `Ordinal` order. An unknown ID returns no rows, and configuration/catalog visibility controls what can be scripted.

The generated script recreates the trace on the connection that runs it and starts it if the source was running. Its new trace ID may differ. Callback procedures must already exist in the destination database. The script does not start collection; run the collector separately when you are ready.
