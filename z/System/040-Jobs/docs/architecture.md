# Jobs architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

System supplies z.fn_SplitString and semaphore acquire/release procedures. SQL Server Agent and msdb job/schedule procedures are required. The helpers do not start the Agent service.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.fn_CleanseScheduleParameter` normalizes readable inputs; `z.fn_ToSQLAgentSchedule` expands them into native integer fields and deterministic schedule names. `z.usp_CreateSchedule` reuses/creates those schedules under a System semaphore. `z.usp_CreateServiceJob` binds them to an msdb job named for the current database and reconciles two command steps. Lifecycle helpers operate on that prefixed job; orphan cleanup operates on unattached schedules. Reverse conversion and name parsing support inspection, with known conversion limits listed below.

Schedules are shared server objects. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

Inspect the rows from z.fn_ToSQLAgentSchedule before creating a job. The Agent-start spelling normalizes to Agent Starts but the description branch tests Agent Start; the normalizer therefore returns no row for that mode. The reverse converter maps weekly bit 64 to Sunday instead of Saturday. Unsupported or incomplete input can produce no schedule rows without throwing. Start/stop detection relies on program_name patterns and is not an authoritative job-history report. Job names ultimately pass through nvarchar(128) variables even though @Name accepts 255 characters.
