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
