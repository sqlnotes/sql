/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceStart.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceStart.md

Enables selected logical trace definitions in the current building collector run.
*/
create or alter procedure z.usp_TraceStart
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null
)
as
begin
	set nocount, xact_abort on;
	exec z.usp_TraceAssertOwner @TraceName, @TraceID;
	declare @CollectorUUID uniqueidentifier = try_convert(uniqueidentifier, session_context(N'Schema z.TraceCollector.UUID'));
	if exists(select 1 from z.TraceCollector where CollectorUUID = @CollectorUUID and State <> 'Building')
		throw 50000, N'Logical trace configuration is frozen during collection.', 1;
	update z.Trace set IsEnabled = 1, ModificationDate = getdate()
	where CollectorUUID = @CollectorUUID and (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID);
end;
go
