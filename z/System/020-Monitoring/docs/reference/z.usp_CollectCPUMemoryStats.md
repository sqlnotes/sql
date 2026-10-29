# z.usp_CollectCPUMemoryStats

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CollectCPUMemoryStats.sql)

## Purpose and behavior

Collect z.v_CPUMemoryStats into z.CPUMemoryStats with at most one row per second.
Date is truncated to the beginning of its second, retaining local server time.
Within each second in the current source read, the row with the latest original
Date supplies the CPU/memory measurements. Equally latest timestamps can supply
either row. A matching stored second is refreshed with that reading; an unseen
second is inserted. RecordID and SQLServerStartTime are not stored or used.

No parameters or result set. An empty source changes no rows. Collection does
not synthesize observations for missing seconds or change the ring buffer's
native sampling interval. It installs no polling job or automatic retention.

The collector uses READ COMMITTED and serializes its writes using an exclusive
transaction-owned application lock with a 10-second timeout. The MERGE matches
only Date and uses HOLDLOCK. The collector's rounding and the Date primary key
produce one stored row per collected second. The table does not validate whole
seconds on direct writes. The collector opens/commits a transaction and rethrows
failures after rollback. Caller transactions are allowed; a successful nested
call leaves the caller transaction open and holds its locks until that outer
transaction ends. The catch can roll back the entire caller transaction on failure.

## Data and time conventions

Date retains the view's reconstructed local server time at second precision;
it is not UTC. Small changes in the reconstructed Date are accepted under this
second-bucket policy. If a reconstruction crosses a second boundary, it belongs
to that newly calculated second. The table stores the latest collected reading
for each second, rather than preserving ring-buffer record identity across reads.
UserModeTime and KernelModeTime retain 100-nanosecond units. Percentages and
other measurements are copied without averaging or conversion.
WorkingSetDelta is decoded and stored as bigint so native values above the int
range are preserved.

The ring buffer is finite; collection cannot recover overwritten observations.
History is for the current source server, not a multi-server repository.

## Dependencies and permissions

Requires z.CPUMemoryStats, z.v_CPUMemoryStats and native DMV visibility.
SQL Server 2019 requires VIEW SERVER STATE; SQL Server 2022 and later requires
VIEW SERVER PERFORMANCE STATE for these diagnostic DMVs. Destination
insert/update/select access is required; the procedure grants no privileges.

The guarded baseline creates a missing table and widens an existing int
WorkingSetDelta column to nullable bigint without replacing rows. The installer
runs this baseline while Monitoring is at version 0.0.0; installed versions above
0.0.0 skip baselines and require a separate upgrade path. No version increase is
supplied.
