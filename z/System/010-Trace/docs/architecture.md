# Trace architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

System supplies z.SeqGeneralID, ID/date helpers, z.usp_ForceNamingConvention, and PS_SchemaZPartitionGeneric. Monitoring supplies z.v_ActiveSessions. SQL Trace system catalogs and sp_trace_* procedures are required.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.usp_TraceCreate` associates a native trace with `z.Trace`. Event/column/filter procedures configure its stopped state; start/stop/close procedures manage native state. `z.usp_TraceCollectAndClose` builds a receiving-table decoder and persists the rowset stream in short transactions. `z.TraceTrigger` rows dispatch procedural callbacks after each insert; the blocking and growth callbacks read Monitoring's current requests into correlated snapshot tables. `z.usp_CollectTrace` assembles four presets and enters that collector. The Trace post stage refreshes generated metadata views; installation itself does not enter collection.

The implementation uses SQL Trace, including sp_trace_getdata, rather than Extended Events. Collection is synchronous and bound to the session that created the trace. Configure, start, and collect on that same connection. The default preset collector can run indefinitely in operational terms; use the bounded custom example below during development.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

No active trace found means no selected Running trace is owned by the current SPID. A collector failure rolls back its current transaction and rethrows, but does not close all traces in a finally block; inspect z.v_Trace and explicitly close survivors. Configure only stopped traces. Preset long-running events contain the token SP:CompletedSP:StmtCompleted; substring lookup does not match the intended separate events. z.usp_TraceRemoveColumns does not implement all as all columns: use a query selecting ColumnID. Updating ReceivingTable on an existing stopped trace requires a non-null Description in z.usp_TraceCreate.
