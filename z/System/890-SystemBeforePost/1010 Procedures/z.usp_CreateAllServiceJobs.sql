/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/890-SystemBeforePost/1010%20Procedures/z.usp_CreateAllServiceJobs.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_createallservicejobs

Creates the hourly general-maintenance service job and removes orphaned schedules.
*/
create or alter procedure z.usp_CreateAllServiceJobs
as
begin
	set nocount on
	exec z.usp_CreateServiceJob @Name = 'General DailyMaintenance', @Command = 'exec z.usp_GeneralDailyMaintenance', @IntradayFrequency ='hour', @IntradayInterval = 1
	exec z.usp_RemoveOrphanedSchedule
end
