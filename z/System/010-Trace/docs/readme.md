# Trace

[System documentation](../../docs/readme.md)

Build logical SQL Trace definitions through framework procedures. Each collector session shares their event-column union across overlapping physical rowset generations and routes matching events to destination tables and callbacks using one receiving connection.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Configure and collect on one dedicated connection and database. Sessions have independent runs and may use identical logical names. Create/Start allocate no native trace. Collect keeps overlapping generations capturing while it receives each uninterrupted rowset directly into a temp table and processes that buffer in order. EventSequence deduplicates overlap; output masking is preserved. Native expiry and processing timing are soft, and complete reception is not guaranteed under every load. No API cursor or additional receiving worker is used. See the [bounded custom example](usage.md#bounded-custom-trace).

Logical IDs remain distinct from native generation IDs. The eligible physical-mapping baseline upgrades its original single-generation primary key. Other existing table shapes are not reconciled. No version increment or new migration is supplied.

## Prerequisites

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. SQL Trace system catalogs and sp_trace_* procedures are required.

## Platform direction

Microsoft documents SQL Trace as deprecated and recommends Extended Events for new development. This subsystem currently implements SQL Trace; no Extended Events replacement is provided here. See [Microsoft SQL Trace documentation](https://learn.microsoft.com/en-us/sql/relational-databases/sql-trace/sql-trace?view=sql-server-ver17).
