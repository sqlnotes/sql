# Jobs

[System documentation](../../docs/readme.md)

Create SQL Server Agent jobs for a database using schedules such as "every 15 minutes between 08:00 and 17:00." Jobs can run up to ten T-SQL commands in order, and the helpers can start, stop, enable, disable or remove them.

Jobs uses SQL Server Agent to do the actual scheduling and execution. Run the helpers from the database that owns the work; they give its jobs and schedules database-specific names in `msdb`.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Schedules reside in msdb and are logically database-scoped by name. Jobs in the same database can reuse a schedule; different databases receive separate names. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

## Prerequisites

System supplies z.fn_SplitString. SQL Server Agent, msdb job/schedule procedures and z.usp_AcquireSemaphore are required. The helpers do not start the Agent service.
