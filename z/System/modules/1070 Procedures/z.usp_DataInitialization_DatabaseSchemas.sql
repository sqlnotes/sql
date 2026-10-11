create or alter procedure z.usp_DataInitialization_DatabaseSchemas
as
begin
	set nocount on
	-- Initialize [z].[DatabaseSchemas]
	-- exec z.usp_DataInitializationHelper @FullObjectName = '[z].[DatabaseSchemas]' , @ForceIdentityColumnInsert = 1, @ForceMatchedDataUpdate = 0, @PrimaryKeys = null, @ExcludedColumns = null
	;with s as 
	(
		select cast([SchemaName] as nvarchar(128)) as [SchemaName]
			from (
					values('z')--,
						--('dbo')
				) v([SchemaName])
	)
	merge [z].[DatabaseSchemas] t
	using s on s.[SchemaName]= t.[SchemaName]
	when not matched then
		insert ([SchemaName])
		values(s.[SchemaName])
	;
end
