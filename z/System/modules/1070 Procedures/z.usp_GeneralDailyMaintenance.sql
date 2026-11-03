/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_GeneralDailyMaintenance.sql
*/
create or alter procedure z.usp_GeneralDailyMaintenance
as
begin
	set nocount on
	exec z.usp_ForcePartitionRetentionPolicy
	exec z.usp_SetLargeValueOutOfRow
end
GO

