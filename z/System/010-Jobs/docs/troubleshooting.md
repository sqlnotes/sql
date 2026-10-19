# Jobs troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

Creation procedures reject an invalid schedule with error 51000 before changing jobs, categories or schedule attachments. A partially invalid list is rejected as a whole. Use z.fn_ValidateScheduleParameter to obtain the validation message; z.fn_ToSQLAgentSchedule returns no rows for invalid input. An empty conversion result is an error, not a request to remove all schedules. Agent Start is supported.

A valid input can still produce no rows if the complete database-prefixed schedule name exceeds 128 UTF-16 code units. The creation error includes this name-length limit. Names are not hashed or truncated. Error 51001 means the database-local job/schedule lock could not be acquired within the allowed wait or acquisition otherwise failed; inspect competing transactions before retrying.

Orphan cleanup excludes legacy global schedules and names belonging to other databases. AllOrphanedSchedules=1 is rejected. Reapplying a job attaches its new owned schedules before detaching old names; installation alone does not migrate existing Agent metadata. Preserved legacy orphans require separately scoped administrative cleanup.

Start/stop detection relies on program_name patterns and is not an authoritative job-history report. The shared job-name helper returns nvarchar(128), intentionally truncating the complete database-prefixed name. Creation and lifecycle lookup use that same identity; original names with the same truncated result identify the same job.

## Permission and partial-operation failures

System supplies z.fn_SplitString. SQL Server Agent, msdb job/schedule procedures and sys.sp_getapplock are required. The helpers do not start the Agent service.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.
