# Jobs

[System documentation](../../docs/readme.md)

Translate readable schedules into SQL Agent fields and manage database-prefixed service jobs in msdb.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Schedules are shared server objects. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

## Prerequisites

System supplies z.fn_SplitString and semaphore acquire/release procedures. SQL Server Agent and msdb job/schedule procedures are required. The helpers do not start the Agent service.
