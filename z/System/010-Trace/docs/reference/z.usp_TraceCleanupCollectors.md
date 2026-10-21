# z.usp_TraceCleanupCollectors

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCleanupCollectors.sql)

## Purpose and behavior

Preserve a Building run while its matching owner session/login exists, including idle gaps. Preserve a Collecting run while the owner has any sys.dm_exec_requests row, including unrelated or waiting work. Otherwise stop/close only its exactly registered native generation and delete its logical configuration, mapping and registry. Recheck owner activity before native actions. A reused native ID with mismatched expiry/start-time tags is preserved for manual review and does not prevent independent owners from registering.

No trace is adopted by name or numeric ID alone. Unregistered native resources and deliberately orphaned metadata require manual review. Native operations cannot be rolled back if later metadata work fails. Cleanup of a connected idle Collecting owner should run from a separate connection; an owner calling cleanup has an active request itself.

## Parameters and defaults

None.

## Results, permissions and limits

No parameters or defined result set. Reject ambient transactions. Requires full server request/session visibility: VIEW SERVER STATE on SQL Server 2019, VIEW SERVER PERFORMANCE STATE on SQL Server 2022+. Native cleanup also requires trace privileges.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for run ownership, schema compatibility and known transport limits.
