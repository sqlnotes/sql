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