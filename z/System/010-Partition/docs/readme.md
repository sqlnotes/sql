# Partition

[System guide](../../docs/readme.md)

Partition creates missing date boundaries and applies sliding retention to configured partition functions. Its generic bigint scheme supports System identifier-based storage.

- [Usage and previews](usage.md)
- [Architecture and dependencies](architecture.md)
- [Troubleshooting](troubleshooting.md)
- [Objects and exact interfaces](reference/readme.md)

Retention permanently removes rows when archive is disabled. A function may be shared across many tables/indexes. Weekly intervals, heaps, range-right and shared-function maintenance have implementation limitations; review the reference before execution.
