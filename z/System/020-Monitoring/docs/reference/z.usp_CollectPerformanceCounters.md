# z.usp_CollectPerformanceCounters

[Object index](readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectPerformanceCounters.sql) | [Table](../../baseline/2020%20Tables/z.PerformanceCounters.sql)

Collects `z.v_PerformanceCountersDefault` into `z.PerformanceCounters` until the
requested duration expires. Both parameters are positive integer seconds:
`@Interval = 1`, `@Duration = 2147483647`. NULL, zero and negative inputs use these defaults. Execution is synchronous; the default
duration is approximately 68 years. Installation does not start collection or
create a job.

```sql
exec z.usp_CollectPerformanceCounters @Interval = 1, @Duration = 60;
select Date, ObjectName, CounterName, InstanceName, CounterValue
from z.PerformanceCounters
order by Date desc, ObjectName, CounterName, InstanceName;
```

The first read establishes a baseline. Each subsequent read stores the latest
gauges and calculates interval measurements using actual elapsed time. A duration
shorter than the interval produces a final partial interval. Waits and query
execution are subject to SQL Server scheduling, so the interval and duration are
soft timing targets. Processing, lock waits and the final write can finish after
the requested duration.

| Counter type | Stored CounterValue |
| --- | --- |
| 65792, raw count | Latest raw value |
| 272696320 / 272696576, cumulative count | Change divided by actual elapsed seconds |
| 537003264, raw fraction | Latest numerator / matching latest base * 100 |
| 1073874176, average bulk | Numerator change / matching base change |
| 1073939712, base | Latest raw value |

Calculated values are nullable floats. Missing or ambiguous bases, unsupported
types, missing previous samples, counter decreases and zero denominators yield
NULL where calculation is unavailable. A reset followed by growth beyond the
previous reading between samples cannot be detected from two readings.
The raw source values remain available for inspection. Base matching uses the
same object and instance plus the expected counter name (the two selected ratio
names have explicit mappings; other candidates use CounterName plus ` Base`). It never selects an
arbitrary base from an object. Rates follow the native counter units; average
values are per operation, and raw fractions are percentages. See Microsoft's
[DMV counter semantics](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql).

The table stores UTC `Date datetime`, counter identity, `CounterType`, calculated
`CounterValue float`, `RawValue bigint`, nullable `BaseValue bigint` and actual
`ElapsedSeconds float`. Its page-compressed primary key is Date plus ObjectName,
CounterName and InstanceName on `PS_SchemaZPartitionGenericDateTime(Date)`.
Concurrent collectors can contribute different sample times; identical sample
keys refresh the existing row. Sampling does not perform partition maintenance
or change retention policies. Existing shared partition maintenance applies.

The procedure rejects caller transactions and implicit-transaction mode. Each sample writes in a short
transaction with a bounded transaction-owned application lock; no transaction is
held during the sampling wait. Completed samples remain committed after later
failure or cancellation. Catchable write errors roll back that sample and
propagate. Client cancellation follows normal SQL transaction rules: clients
should roll back any transaction left open before reusing the connection.

Requires destination write access and DMV access: VIEW SERVER STATE on SQL Server
2019, or VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later. The default
view's literal object-name and instance filters determine which counters exist
in each sample; it may return no rows on a server whose object names differ.
The guarded baseline creates a missing table on fresh installation. An existing
versioned installation that skips baselines requires separate execution of the
table definition before using the procedure.
