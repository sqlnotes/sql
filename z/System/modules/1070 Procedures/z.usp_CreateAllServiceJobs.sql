create or alter procedure z.usp_CreateAllServiceJobs
as
begin
	set nocount on
	--exec z.usp_CreateServiceJob @Name = 'Collect Active Sessions', @Command = 'exec z.usp_CollectInfo', @IntradayFrequency ='minute', @IntradayInterval = 5
	exec z.usp_CreateServiceJob @Name = 'General DailyMaintenance', @Command = 'exec z.usp_GeneralDailyMaintenance', @IntradayFrequency ='hour', @IntradayInterval = 1
	--exec z.usp_CreateServiceJob @Name = 'Trace System', @Command = 'exec z.usp_CollectTrace', @IntradayFrequency ='second', @IntradayInterval = 1
	exec z.usp_RemoveOrphanedSchedule
end


