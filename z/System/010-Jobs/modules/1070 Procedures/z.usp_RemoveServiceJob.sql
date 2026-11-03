/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1070%20Procedures/z.usp_RemoveServiceJob.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/z.usp_RemoveServiceJob.md

Removes the named database-prefixed SQL Agent job when it exists.
*/
create or alter procedure z.usp_RemoveServiceJob
(
	@Name nvarchar(255)
)
as
begin
	set nocount, xact_abort on;
	declare @JobID uniqueidentifier, @Resource nvarchar(255) = z.fn_ResourceSQLScheduleOperation(), @LockResult int;
	begin try
		begin tran;
		exec @LockResult = sys.sp_getapplock @Resource = @Resource, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 15000;
		if @LockResult < 0 throw 51001, 'Could not acquire the database schedule operation lock.', 1;
		select @JobID = z.fn_GetServiceJobID(@Name);
		if @JobID is not null
			exec msdb.dbo.sp_delete_job @job_id = @JobID, @delete_unused_schedule = 0;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
