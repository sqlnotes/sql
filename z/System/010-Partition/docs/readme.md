# Partition

[System guide](../../docs/readme.md)

Keeps date-partitioned tables ready for new data and removes or retains expired partitions according to a policy. Configure a policy for a partition function, preview the work, then run it manually or through the general-maintenance Agent job.

The same partition function can serve several tables and indexes, so a policy applies to all of them together. The shared System schemes support datetime keys and datetime-encoded bigint IDs.

- [Usage and previews](usage.md)
- [Architecture and dependencies](architecture.md)
- [Troubleshooting](troubleshooting.md)
- [Objects and exact interfaces](reference/readme.md)

Retention permanently removes rows when archive is disabled. A function may be shared across many tables/indexes. Compression is preserved separately for each aligned index and source partition; no compression rebuild policy or archive transport is performed. Review the reference before execution.
