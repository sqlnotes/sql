-- Stop with the old APIs still installed if previous collector resources remain.
if object_id(N'z.TraceCollectorTrace', N'U') is not null
	exec sys.sp_executesql N'if exists(select 1 from z.TraceCollectorTrace) throw 50000, N''Close all native generations with the previous installation before deploying the physical trace model.'', 1;';
if object_id(N'z.TraceCollector', N'U') is not null
	exec sys.sp_executesql N'if exists(select 1 from z.TraceCollector) throw 50000, N''Release all collector sessions with the previous installation before deploying the physical trace model.'', 1;';
if col_length(N'z.Trace', N'CollectorUUID') is not null or columnproperty(object_id(N'z.Trace'), N'TraceID', 'IsIdentity') = 1
begin
	if exists(select 1 from z.Trace)
		throw 50000, N'Close all existing traces with the previous installation before deploying the physical trace model.', 1;
end;
go
