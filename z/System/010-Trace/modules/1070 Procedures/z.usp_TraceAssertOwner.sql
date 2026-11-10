/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/modules/1070%20Procedures/z.usp_TraceAssertOwner.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Trace/docs/reference/z.usp_TraceAssertOwner.md

Validates that the selected native traces were created by the current session.
*/
create or alter procedure z.usp_TraceAssertOwner
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null
)
as
begin
	set nocount on;
	if not exists(select 1 from z.v_TraceOwned where (@TraceName is null or Name = @TraceName) and (@TraceID is null or TraceID = @TraceID))
		throw 50000, N'No matching trace was created by the current session.', 1;
end;
go
