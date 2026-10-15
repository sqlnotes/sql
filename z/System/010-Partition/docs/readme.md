# Partition

[System guide](../../docs/readme.md)

Partition creates missing date boundaries and applies sliding retention to configured partition functions. Shared System schemes support datetime and datetime-encoded bigint storage.

- [Usage and previews](usage.md)
- [Architecture and dependencies](architecture.md)
- [Troubleshooting](troubleshooting.md)
- [Objects and exact interfaces](reference/readme.md)

Retention permanently removes rows when archive is disabled. A function may be shared across many tables/indexes. Compression is preserved separately for each aligned index and source partition; no compression rebuild policy or archive transport is performed. Review the reference before execution.
