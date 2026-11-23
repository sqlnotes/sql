# Jobs architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

Jobs connects readable schedule definitions to SQL Server Agent. The conversion functions let you preview a schedule; the creation procedures apply it to `msdb`; the lifecycle helpers operate on the resulting database-owned jobs.

## Dependencies and installation

System supplies z.fn_SplitString. SQL Server Agent, msdb job/schedule procedures and z.usp_AcquireSemaphore are required. The helpers do not start the Agent service.

See [System documentation](../../docs/readme.md) for deployment order.

## Data and control flow

Start with `z.fn_ValidateScheduleParameter` when you need to check a definition, or `z.fn_ToSQLAgentSchedule` when you want to preview the SQL Agent fields. Validation returns NULL on success or a readable error message. Conversion returns rows for valid input and no rows for invalid input. `z.fn_CleanseScheduleParameter` supplies the common normalized representation. Both creation procedures reject invalid input before changing schedules, jobs or categories; an empty conversion never means "remove the existing schedules."

Schedule words are case-insensitive and accent-sensitive, even when the database uses a case-sensitive or Turkish collation. This applies to words such as weekdays and monthly recurrence names; database identities and command text retain their original meaning.

`z.usp_CreateSchedule` creates or reuses schedules named `Schema z: [DatabaseName]: <native fields>`. Names preserve Unicode and punctuation. An overlength schedule name rejects the whole definition rather than being truncated. The returned schedule IDs identify the actual assignments, including reused schedules.

`z.usp_CreateServiceJob` creates a database availability check followed by up to ten user commands. Agent runs the retained commands in parameter order; NULL, empty and ASCII-whitespace-only commands add no step. A failed user command ends the job with failure. An unavailable database ends the job reporting success without running user commands. An empty command list is valid and creates only the database check.

Job and schedule definition changes are serialized within their owning database. A competing change waits up to 15 seconds; acquisition failure raises error 51001. Protection lasts until the outer transaction commits or rolls back. Different databases operate independently. Manual changes through native Agent tools and Agent's automatic job deletion do not participate in this coordination. Category creation can remain applied even when a later job change fails.

Updating or removing a job retains unused schedule definitions. Orphan cleanup removes only this database's unattached schedules; other databases' schedules and legacy global schedules remain. `AllOrphanedSchedules = 1` is rejected. Reverse conversion and name parsing can inspect both legacy and current schedule names.

[Schedule resolution](reference/z.usp_CreateSchedule.md) describes start-date defaults, reuse and timing drift.

## Integration constraints

Preview schedules before creating a job. No conversion rows can mean invalid input or an overlength name; the validator supplies input diagnostics. Agent Start and Idle schedules are supported. Running checks observe visible Agent sessions and do not replace a job-history report.

Complete job names are limited to `nvarchar(128)` and are truncated consistently by creation and lifecycle lookup. Two service names with the same truncated result identify the same job. Schedule names instead fail when overlength.

Reapplying a definition preserves manual disabling, notifications, server assignments and NULL description/category inputs. A changed command count or missing managed step rebuilds the managed steps and resets step-specific execution-context, proxy and output overrides; intact steps retain them. Unknown custom extra steps are rejected. Generated step names are reserved for the library. See the [creation reference](reference/z.usp_CreateServiceJob.md) before customizing a managed job.

A reused schedule must still match the timing encoded in its name. Timing drift is rejected before creating requested schedules, and a matching disabled schedule stays disabled.

Existing jobs move to database-prefixed schedules when their definitions are reapplied; installation alone does not migrate Agent metadata. Legacy schedules still used by other jobs are preserved, and legacy orphans require separately scoped administrative cleanup. A database rename creates a new schedule namespace; old names are retained until explicitly reconciled or cleaned up.
