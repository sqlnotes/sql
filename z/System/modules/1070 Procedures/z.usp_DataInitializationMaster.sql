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
	exec z.usp_ExecuteProcedures @SchemaName = @SchemaName, @NamePattern = N'usp!_DataInitialization%',
		@ExcludedProcedureNames = N'usp_DataInitializationHelper,usp_DataInitializationMaster';
end;
