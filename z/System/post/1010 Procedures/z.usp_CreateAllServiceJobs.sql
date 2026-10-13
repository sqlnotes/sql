create or alter procedure z.usp_CreateAllServiceJobs
as
begin
	set nocount on
	exec z.usp_CreateServiceJob @Name = 'General DailyMaintenance', @Command = 'exec z.usp_GeneralDailyMaintenance', @IntradayFrequency ='hour', @IntradayInterval = 1
	exec z.usp_RemoveOrphanedSchedule
end
