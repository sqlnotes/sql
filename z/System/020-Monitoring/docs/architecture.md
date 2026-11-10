# Monitoring architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

System supplies z.SeqGeneralID, PS_SchemaZPartitionGeneric and PS_SchemaZPartitionGenericDateTime. Server DMVs, Extended Events, and msdb Database Mail supply external data. System orchestration can schedule collection through Jobs. [Trace](../../010-Trace/docs/readme.md) supplies the SQL Trace framework for monitoring presets and installs before Monitoring.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.v_ActiveSessions` reads live requests; `z.usp_TakeSnapshotActiveSessions` appends them to `z.ActiveSessions`. `z.usp_CollectSystemHealthEvents` reads the system_health ring buffer, passes its XML to the pure decoder `z.fn_ExtractSystemHealthEvent`, filters events and persists their XML in `z.SystemHealthEvent`. Resource/space views read native catalogs directly. `z.usp_CheckDatabaseMail` configures server and msdb mail infrastructure separately from those collectors.

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

Empty request snapshots can be normal: the collector excludes its own session. Check DMV visibility before assuming there are no other requests. Missing ring-buffer events can mean system_health is absent, has no ring-buffer target, or has already overwritten events. Persisted duplicate keys can occur under concurrent collectors; the System Health insert uses a not-exists predicate without serialization. z.v_IndexSpaceUsed uses 8.192 / 1024 per page for columns labelled MB, rather than the usual 8 / 1024; use raw page counts when exact units matter.

## SQL Trace monitoring

`z.usp_CollectTrace` creates/configures four independent native rowset traces for blocking, long-running queries, errors and file growth. Each has native filters, its own destination and callbacks, and no scheduled stop time. One connection polls and processes their buffers. Monitoring owns diagnostic tables, snapshot callbacks and daily/hourly summaries. Installation does not start capture.

TraceCreate allocates stopped native traces; Start applies configuration and starts each one. Collection closes its selected traces/configuration on completion and retains diagnostic data. Cleanup reaps only framework registrations whose creator session/login is absent, preserving idle connected owners. Bounded reads have known reception loss. Snapshot callbacks inspect state when processing runs. See [Trace architecture](../../010-Trace/docs/architecture.md).

## Server Extended Events collectors

[Error and long-running query sessions](reference/extended-events.md) are defined
through idempotent creation procedures, independently of the SQL Trace framework.
The two collectors call their matching creator before reading the buffer, so
collection can create a missing server session or start a stopped session.
They capture all databases into 4096-KB ring buffers. Separate collectors persist
typed rows and original XML to z.ErrorEvent and z.LongRunningQueryEvent; installation
does not create sessions, start collection or schedule jobs. All three XE receiving
tables (including z.SystemHealthEvent) use EventDateUTC datetime as their UTC
partition key on PS_SchemaZPartitionGenericDateTime. The System Health collector
reads the native buffer before calling its XML-input inline extractor, which
returns EventDateUTC directly. All three extractors are pure XML decoders; the
original event XML retains the full timestamp precision.

## Performance counter history

`z.usp_CollectPerformanceCounters` samples `z.v_PerformanceCountersDefault` and
persists latest gauges and calculated interval values to `z.PerformanceCounters`.
UTC Date partitions share `PS_SchemaZPartitionGenericDateTime` and its existing
maintenance policy. Short per-sample transactions commit before waits; no job or
collection starts during installation. The [reference](reference/z.usp_CollectPerformanceCounters.md)
describes timing, matching bases, missing values and transaction behavior.
