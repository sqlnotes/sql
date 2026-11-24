/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_DataInitializationMaster.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_datainitializationmaster

Executes matching data-initialization procedures in name order for a selected schema or all
schemas.
*/
create or alter procedure z.usp_DataInitializationMaster
(
	@SchemaName nvarchar(128) = 'z'
)
as
begin
	set nocount, xact_abort on;
	if charindex(N',', @SchemaName collate Latin1_General_100_BIN2) > 0
		throw 50000, 'A schema name supplied to z.usp_DataInitializationMaster cannot contain a comma.', 1;
	declare @SchemaPattern nvarchar(384);
	select	@SchemaPattern = replace(replace(replace(replace(replace(@SchemaName collate Latin1_General_100_BIN2,
				N'!', N'!!'), N'[', N'!['), N'%', N'!%'), N'_', N'!_'), N' ', N'[ ]');
	exec z.usp_ExecuteProcedures @SchemaNames = @SchemaPattern, @ProcedureNames = N'usp!_DataInitialization%',
		@ExcludedProcedureNames = N'usp!_DataInitializationHelper,usp!_DataInitializationMaster';
end;
