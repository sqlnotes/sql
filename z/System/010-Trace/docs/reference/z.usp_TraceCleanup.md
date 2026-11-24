# z.usp_TraceCleanup

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCleanup.sql)

Removes abandoned framework traces after their owner connection has disconnected. It stops and closes those traces and removes their configuration, while retaining collected data. There are no parameters. A connection that is still open keeps its traces, even while idle.

Only framework registrations are eligible; unrelated SQL Server traces are outside its scope. Ownership uses both session ID and login time, so a new connection reusing an old ID does not keep abandoned traces alive. TraceCreate and Monitoring startup run cleanup automatically; operators can also call it after a disconnected owner leaves traces behind.

Use the framework lifecycle procedures rather than directly closing server traces. Direct closure followed by reuse of the native trace ID cannot be distinguished from the stored ID alone.

Requires full server session visibility (VIEW SERVER STATE on SQL Server 2019; VIEW SERVER PERFORMANCE STATE on SQL Server 2022+) and trace/configuration privileges. Rejects ambient transactions. No native trace or table changes occur merely by installing this procedure.
