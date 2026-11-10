-- Retire objects from the previous shared-collector design only after its registries are empty.
if object_id(N'z.TraceCollectorTrace', N'U') is not null
	exec sys.sp_executesql N'if exists(select 1 from z.TraceCollectorTrace) throw 50000, N''Existing native trace generations must be closed before retiring their registry.'', 1;';
if object_id(N'z.TraceCollector', N'U') is not null
	exec sys.sp_executesql N'if exists(select 1 from z.TraceCollector) throw 50000, N''Existing collector sessions must be released before retiring their registry.'', 1;';
exec z.usp_DropObject @ObjectName = N'z.usp_TraceOpenPhysical';
exec z.usp_DropObject @ObjectName = N'z.usp_TraceRegisterCollector';
exec z.usp_DropObject @ObjectName = N'z.usp_TraceReleaseCollector';
exec z.usp_DropObject @ObjectName = N'z.usp_TraceCleanupCollectors';
if object_id(N'z.TraceCollectorTrace', N'U') is not null drop table z.TraceCollectorTrace;
if object_id(N'z.TraceCollector', N'U') is not null drop table z.TraceCollector;
go
