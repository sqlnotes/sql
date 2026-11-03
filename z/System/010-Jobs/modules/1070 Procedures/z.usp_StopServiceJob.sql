/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1070%20Procedures/z.usp_StopServiceJob.sql
*/
create or alter procedure z.usp_StopServiceJob
(
	@Name nvarchar(255)
)
as
begin
	set nocount on
	declare  @JobID uniqueidentifier 
	select @JobID = JobID
	from z.v_ServiceJobs
	where JobID = z.fn_GetServiceJobID(@Name)
		and IsExecuting = 1
	if @@rowcount > 0
	begin
		exec msdb..sp_stop_job @job_id = @JobID;
	end
end
