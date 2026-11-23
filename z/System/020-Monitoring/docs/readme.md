# Monitoring

[System documentation](../../docs/readme.md)

Use Monitoring to answer what is running now, what caused a recent problem, and how resource or storage use changes over time. Live views show current requests and space use. Collectors save request snapshots, performance readings and selected diagnostic events for later investigation.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Error and long-running query Extended Events](reference/extended-events.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Start with [live views](usage.md#examples) for an immediate check. Use [CPU/memory](reference/z.usp_CollectCPUMemoryStats.md) or [performance-counter history](reference/z.usp_CollectPerformanceCounters.md) for trends, [Extended Events](reference/extended-events.md) for errors and slow queries, or the [SQL Trace presets](reference/z.usp_CollectTrace.md) for blocking and file-growth diagnostics as well. Collection must be called or scheduled explicitly.

Snapshots capture requests at collection time, not a full session history. Query text, plans, login names, and client details can be sensitive. Database Mail configuration is an administrative operation that changes server settings and msdb; it is not a health-only check.

## Prerequisites

System supplies z.SeqGeneralID, PS_SchemaZPartitionGeneric and PS_SchemaZPartitionGenericDateTime. Server DMVs, Extended Events, and msdb Database Mail supply external data. System orchestration can schedule collection through Jobs. [Trace](../../010-Trace/docs/readme.md) supplies the SQL Trace framework for monitoring presets and installs before Monitoring.
