# Trace troubleshooting

[Subsystem](readme.md) | [Architecture](architecture.md) | [Object index](reference/readme.md)

Inspect z.v_Trace and z.v_TraceOwned for registered trace IDs, owner session/login and Running/Stopped/Not Available status. TraceID is the native ID. Configure and start on the creator connection; configure events/columns/filters before the first Start attempt. Once native event bindings exist, Close/Create is required to change them; Stop/Start resumes the same trace. Callbacks and destination metadata can be changed while stopped.

External Stop/Close is normal and ends polling for that trace. Actual read, decode, insert or callback failures print trace/operation context and rethrow the original SQL error. Current-batch changes roll back, earlier commits remain. Cleanup failures are reported separately and do not replace the collection error.

Run z.usp_TraceCleanup after an abandoned owner's connection has ended. Idle connected sessions retain ownership. Cleanup requires VIEW SERVER STATE on SQL Server 2019, or VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later, and native trace/registry permissions. It never closes unrelated traces solely because they have no framework registration. Use framework Stop/Close APIs to keep registrations synchronized with server traces. Direct external trace closure and ID reuse cannot be distinguished from the stored TraceID alone.

A schema-transition error requires stopping old collectors and clearing their old registered configuration safely before eligible baseline replay. Keep receiving tables/data. Existing installations skipping the baseline need a separately planned transition; rerunning modules alone does not reconcile tables.

Missing events are possible with bounded sp_trace_getdata reads even when native dropped-event counters are zero. More frequent polling is not proof of complete delivery. A missing row does not prove a query never executed. No callback-latency guarantee is made; native calls and callbacks can exceed the optional collection duration.
