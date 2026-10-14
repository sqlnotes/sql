# Trace

[System documentation](../../docs/readme.md)

Configure SQL Trace, collect its rowset stream into partitioned tables, and capture related active-request snapshots.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

The implementation uses SQL Trace, including sp_trace_getdata, rather than Extended Events. Collection is synchronous and bound to the session that created the trace. Configure, start, and collect on that same connection. The default preset collector can run indefinitely in operational terms; use the [bounded custom example](usage.md#bounded-custom-trace) during development.

## Prerequisites

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. Monitoring supplies z.v_ActiveSessions. SQL Trace system catalogs and sp_trace_* procedures are required.

## Platform direction

Microsoft documents SQL Trace as deprecated and recommends Extended Events for new development. This subsystem currently implements SQL Trace; no Extended Events replacement is provided here. See [Microsoft SQL Trace documentation](https://learn.microsoft.com/en-us/sql/relational-databases/sql-trace/sql-trace?view=sql-server-ver17).
