/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_GeneralDailyMaintenance.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_generaldailymaintenance

Runs partition-retention enforcement followed by database-wide large-value storage-option
maintenance.
*/
create or alter procedure z.usp_GeneralDailyMaintenance
as
begin
	set nocount on
	exec z.usp_ForcePartitionRetentionPolicy
	exec z.usp_SetLargeValueOutOfRow
end
GO

