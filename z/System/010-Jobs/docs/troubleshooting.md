# Jobs troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

Inspect the rows from z.fn_ToSQLAgentSchedule before creating a job. The Agent-start spelling normalizes to Agent Starts but the description branch tests Agent Start; the normalizer therefore returns no row for that mode. The reverse converter maps weekly bit 64 to Sunday instead of Saturday. Unsupported or incomplete input can produce no schedule rows without throwing. Start/stop detection relies on program_name patterns and is not an authoritative job-history report. Job names ultimately pass through nvarchar(128) variables even though @Name accepts 255 characters.

## Permission and partial-operation failures

System supplies z.fn_SplitString and semaphore acquire/release procedures. SQL Server Agent and msdb job/schedule procedures are required. The helpers do not start the Agent service.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
