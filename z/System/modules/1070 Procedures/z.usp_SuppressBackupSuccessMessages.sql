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
