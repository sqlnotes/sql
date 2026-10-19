# Jobs

[System documentation](../../docs/readme.md)

Translate readable schedules into SQL Agent fields and manage database-prefixed service jobs in msdb.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Schedules reside in msdb and are logically database-scoped by name. Jobs in the same database can reuse a schedule; different databases receive separate names. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

## Prerequisites

System supplies z.fn_SplitString. SQL Server Agent, msdb job/schedule procedures and sys.sp_getapplock are required. The helpers do not start the Agent service.
