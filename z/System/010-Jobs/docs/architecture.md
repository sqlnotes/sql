# Jobs architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

System supplies z.fn_SplitString. SQL Server Agent, msdb job/schedule procedures and sys.sp_getapplock are required. The helpers do not start the Agent service.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

`z.fn_CleanseScheduleParameter` normalizes readable inputs. `z.fn_ValidateScheduleParameter` validates the complete relevant input and returns an error message or NULL. `z.fn_ToSQLAgentSchedule` expands valid input into native integer fields and deterministic schedule names; invalid input returns no rows. Both creation procedures throw on invalid input before changing schedules, jobs or categories. An empty conversion result cannot remove a job's existing schedules.

These three functions share explicit Latin1_General_100_CI_AS comparisons for schedule vocabulary, independent of the database's own collation. Case folding occurs under the same semantics before validation. Case-sensitive and Turkish database defaults cannot cause accepted weekday tokens or relative monthly fields to be dropped. Database identities, command text and date/time payloads are not normalized by these vocabulary comparisons.

`z.usp_CreateSchedule` reuses/creates schedules named `Schema z: [DatabaseName]: <native fields>`. Names preserve Unicode and escape closing brackets. A complete name exceeding SQL Agent's 128 UTF-16-unit limit rejects the whole definition; names are never truncated. `z.usp_CreateServiceJob` binds them to a job named for the current database and reconciles two command steps: a database guard and one user command. Desired schedule names are read as rows, without splitting a comma-separated string.

Schedule creation, job reconciliation, job removal and orphan cleanup acquire the same exclusive, transaction-owned application lock in the current database. Acquisition waits at most 15 seconds and fails with error 51001 on failure. Nested creation retains protection until the actual outer transaction commits or rolls back; helpers do not explicitly release it. Different databases have independent names and locks. Category creation remains outside the job transaction. Direct native/administrative operations and Agent automatic deletion do not participate in this cooperative lock.

Reconciliation attaches replacement schedules before detaching old names. Detachment and job removal preserve unused schedules. Orphan cleanup removes only unattached schedules matching the current database's literal prefix; legacy global names and other databases' schedules remain. Global cleanup via AllOrphanedSchedules=1 is rejected. Reverse conversion and name parsing support both legacy and new names, with known conversion limits listed below.

Schedules reside in msdb but are logically owned by the database named in their prefix; jobs in the same database can reuse them. Creating/removing jobs and schedules changes msdb. Returned normalization rows describe the translation, not proof that SQL Agent accepted or executed it.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

Inspect the rows from z.fn_ToSQLAgentSchedule before creating a job; use z.fn_ValidateScheduleParameter for input diagnostics and check the combined schedule-name length when no rows are returned. Agent Start and Idle are supported. Start/stop detection relies on program_name patterns and is not an authoritative job-history report. The shared job-name helper returns nvarchar(128), intentionally truncating the complete database-prefixed name. Creation and lifecycle lookup use that same identity; original names with the same truncated result identify the same job. Reapplying reconciles description/category when non-NULL, native deletion mode and the two managed steps/start step, preserving manual job disabling and notifications. Missing managed steps are rebuilt; additional custom steps cause rejection. Schedule timing drift is rejected before schedule creation; a matching disabled schedule stays disabled. Other execution-context overrides and existing server assignments are not reconciled.

Existing jobs move to database-prefixed schedules when their definitions are reapplied; installation alone does not migrate Agent metadata. Legacy schedules still used by other jobs are preserved, and legacy orphans require separately scoped administrative cleanup. A database rename creates a new schedule namespace; old names are retained until explicitly reconciled or cleaned up.
