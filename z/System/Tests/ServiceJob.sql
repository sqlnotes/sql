if z.fn_IsSQLAgentRunning() = 0 -- agent is not running
	return
declare @ServiceName nvarchar(100) , @JobName nvarchar(100), @JobID uniqueidentifier
select @ServiceName = '848806C5-6676-497E-B4F5-8F3B1CDE6774'
--select @JobName = 
