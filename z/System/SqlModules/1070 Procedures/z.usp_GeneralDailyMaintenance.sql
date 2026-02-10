create or alter procedure z.usp_GeneralDailyMaintenance
as
begin
	set nocount on
	exec z.usp_ForcePartitionRetentionPolicy
	exec z.usp_SetLargeValueOutOfRow
end
GO

