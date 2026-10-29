# Trace

[System documentation](../../docs/readme.md)

Build logical SQL Trace definitions through framework procedures. Each collector session merges its enabled definitions into one physical SQL Trace and routes matching events to their destination tables and callbacks.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Configure and collect on one dedicated connection and database. Different sessions have independent runs and may use identical logical names. Creation and logical Start allocate no native trace; Collect allocates one for the run. Collection is synchronous and creates a fresh static API cursor for each bounded one-frame sp_trace_getdata read. This backend can lose events even with zero native drops; merging does not establish complete reception or a callback latency guarantee. Raw saving and parsing remain combined. Use the [bounded custom example](usage.md#bounded-custom-trace).

This initial schema redesign changes table shapes and logical ID semantics. Baseline guards do not migrate existing tables: use a fresh installation or explicitly recreate the development schema. No version increment or migration is supplied.

## Prerequisites

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. SQL Trace system catalogs and sp_trace_* procedures are required.

## Platform direction

Microsoft documents SQL Trace as deprecated and recommends Extended Events for new development. This subsystem currently implements SQL Trace; no Extended Events replacement is provided here. See [Microsoft SQL Trace documentation](https://learn.microsoft.com/en-us/sql/relational-databases/sql-trace/sql-trace?view=sql-server-ver17).
