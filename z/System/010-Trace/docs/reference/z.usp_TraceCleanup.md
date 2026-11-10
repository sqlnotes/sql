# z.usp_TraceCleanup

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCleanup.sql)

No parameters. Stop and close registered native traces whose creator session ID/login time no longer exists, then remove their configuration. Idle connected owners are preserved. A reused session ID with a different login time does not preserve abandoned traces.

Actions require the locked registration and a rowset trace without a scheduled stop. There is no second trace ID or start-time tag. Direct external closure followed by ID reuse cannot be distinguished from that ID alone; use framework lifecycle APIs. It only handles framework registrations, not arbitrary server traces. TraceCreate and Monitoring startup invoke it; an operator can invoke it after owner disconnection.

Requires full server session visibility (VIEW SERVER STATE on SQL Server 2019; VIEW SERVER PERFORMANCE STATE on SQL Server 2022+) and trace/configuration privileges. Rejects ambient transactions. No native trace or table changes occur merely by installing this procedure.
