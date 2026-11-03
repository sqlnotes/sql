/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1070%20Procedures/z.usp_DisableServiceJob.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/z.usp_DisableServiceJob.md

Disables the named database-prefixed SQL Agent job when it exists.
*/
create or alter procedure z.usp_DisableServiceJob
(
	@Name nvarchar(255)
)
as
begin
	set nocount on
	declare @JobID uniqueidentifier 
	select @JobID = z.fn_GetServiceJobID(@Name)
	if @JobID is not null
		exec msdb..sp_update_job @job_id = @JobID, @enabled = 0;
end