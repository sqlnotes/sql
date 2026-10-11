# Partition troubleshooting

[Guide](readme.md) · [Reference and source](reference/readme.md)

## Weekly

Weekly is accepted by checks, but boundary end-date/loop increments and retention cutoff omit it. Do not rely on Weekly maintenance.

## Invalid interval

The boundary guard tests `isnull(@PartitionRangeTypeInterval, 0) is null`, which never rejects invalid input. Zero can divide by zero; null can produce empty/incomplete output, and abs(INT_MIN) overflows. Supply positive intervals and a bounded span.

## Shared-function ordering

The builder assigns the merge to rn=1 under descending unquoted schema.object ordering, then emits rows by ascending quoted SourceObject. For ordinary identifiers this intends the merge to follow all switches; unusual identifiers can change that relative ordering. Review emitted order and every table sharing the function.

## Switch failures and unsupported topology

Targets must satisfy SQL Server index/constraint/storage switch requirements. Schema-copy does not clone checks or foreign keys. Existing nonempty archive targets raise an error; empty targets are recreated.

Retention excludes heaps and does not branch on range direction. Its preceding-partition mapping should not be assumed correct for range-right functions; the shipped function is range left.

## Policy changes and blocking

System initialization restores shipped generic policy values on deployment repeats. Maintenance has no independent lock and may hold one transaction across every policy. Splits/switches/merges can block concurrent workloads and move populated data.
