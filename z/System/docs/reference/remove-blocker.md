# z.usp_RemoveBlocker

[Object index](readme.md) · [Source](../../post/1010%20Procedures/z.usp_RemoveBlocker.sql)

## Interface

```sql
create or alter procedure z.usp_RemoveBlocker
```

No parameters or explicit result set. Requires no open transaction and running SQL Agent; otherwise raises an error and returns.

## Behavior and generated objects

Builds global temporary procedure `##usp_RemoveBlocker_<CallerSPID>`, then creates/starts a service job using that name when no matching job exists. The temporary procedure repeatedly inspects requests blocking the caller and issues `kill <BlockingSessionID>` for user sessions. It waits until the caller has no active request for approximately two seconds, then drops itself. The created job requests automatic deletion after execution (SQL Agent delete_level=3).

The helper does not wait for the job to finish, offer a dry run or limit killing to a configured database. It targets a blocker of the invoking session. Exceptions from KILL inside the generated worker are swallowed.

## Dependencies, permissions and transactions

Depends on Jobs `z.fn_IsSQLAgentRunning`, `z.fn_GetServiceJobID`, `z.usp_CreateServiceJob` and `z.usp_StartServiceJob`, plus server DMVs. Caller/job context need appropriate temp-procedure DDL, SQL Agent/job rights, DMV visibility and permission to terminate sessions. Defining the procedure does not grant those rights.

No transaction is started. Session termination can roll back the victim's work and affect unrelated application activity. Session IDs can be reused; the worker tracks a numeric ID, not an immutable connection identity. This helper is an intrusive administrator tool and requires careful operational control.

## Failure and cleanup

Temporary procedure/job creation and starting are separate operations. A failure can leave partial artifacts. Job deletion policy does not guarantee the generated procedure is removed when the worker fails or never starts. No cancellation/timeout interface is provided.
