/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/post/1010%20Procedures/z.usp_CreateAllServiceJobs.sql
*/
create or alter procedure z.usp_CreateAllServiceJobs
as
begin
	set nocount on
	exec z.usp_CreateServiceJob @Name = 'General DailyMaintenance', @Command = 'exec z.usp_GeneralDailyMaintenance', @IntradayFrequency ='hour', @IntradayInterval = 1
	exec z.usp_RemoveOrphanedSchedule
end
