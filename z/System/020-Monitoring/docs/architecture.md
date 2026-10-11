# Monitoring architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

System supplies z.SeqGeneralID; Partition supplies PS_SchemaZPartitionGeneric. Server DMVs, Extended Events, and msdb Database Mail supply external data. System orchestration can schedule collection through Jobs.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.v_ActiveSessions` reads live requests; `z.usp_TakeSnapshotActiveSessions` appends them to `z.ActiveSessions`. `z.fn_ExtractSystemHealthEvent` reads the Extended Events ring buffer; `z.usp_CheckSystemHealthTrace` filters events and persists their XML in `z.SystemHealthEvent`. Resource/space views read native catalogs directly. `z.usp_CheckDatabaseMail` configures server and msdb mail infrastructure separately from those collectors.

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

Empty request snapshots can be normal: the collector excludes its own session. Check DMV visibility before assuming there are no other requests. Missing ring-buffer events can mean system_health is absent, has no ring-buffer target, or has already overwritten events. Persisted duplicate keys can occur under concurrent collectors; the System Health insert uses a not-exists predicate without serialization. z.v_IndexSpaceUsage uses 8.192 / 1024 per page for columns labelled MB, rather than the usual 8 / 1024; use raw page counts when exact units matter.
