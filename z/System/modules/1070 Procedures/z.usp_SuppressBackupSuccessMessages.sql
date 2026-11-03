/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_SuppressBackupSuccessMessages.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_suppressbackupsuccessmessages

Enables global trace flag 3226 to suppress successful backup and restore log entries only when
it is not already enabled.
*/
create or alter procedure z.usp_SuppressBackupSuccessMessages
as
begin
	set nocount, xact_abort on;

	declare @TraceStatus table (TraceFlag int, Status int, [Global] int, [Session] int);

	insert into @TraceStatus (TraceFlag, Status, [Global], [Session])
		exec (N'dbcc tracestatus (3226, -1) with no_infomsgs;');

	if not exists (select 1 from @TraceStatus where TraceFlag = 3226 and Status = 1 and [Global] = 1)
	begin
		dbcc traceon (3226, -1) with no_infomsgs;
	end
end
