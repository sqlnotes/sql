create or alter procedure z.usp_ForceNamingConvention
(
	@TableName nvarchar(256) = null, 
	@IgnoreError bit = 0
)
as
begin
	set nocount on 
	set xact_abort off
	declare @ObjectName nvarchar(1200), @NewName nvarchar(128), @ObjectType varchar(13), @ObjectID int
	if @TableName is not null 
	begin
		select @ObjectID = object_id(@TableName)
		if @ObjectID is null
		raiserror('Could not find object %s.', 16, 1, @TableName)
		return
	end
	
	select 'exec sp_rename ' + quotename(quotename(SchemaName) + '.' + quotename(ObjectName) + '.' + quotename(IndexName), '''')+','+quotename(ExpectedIndexName, '''') + ',' + quotename('Index', '''') +';'
			--, *
	from maint.fn_GetIndexStructure(@TableName)
		where SchemaName in (select SchemaName from maint.DatabaseSchemas)
			and ExpectedIndexName <> IndexName
			and IsPrimaryKey = 0
			and IsUniqueConstraint = 0



	declare @SQL nvarchar(max)
	create table #Query(ID int identity(1,1), SQL nvarchar(max))
	--Indexes
	insert into #Query(SQL)
		
	-- PK and UQ
	insert into #Query(SQL)
		select 'exec sp_rename ' + quotename(quotename(SchemaName) + '.' + quotename(IndexName), '''')+','+quotename(ExpectedIndexName, '''') + ',' + quotename('Object', '''') +';'
			--, *
		from maint.fn_GetIndexStructure(@TableName)
		where SchemaName in (select SchemaName from maint.DatabaseSchemas)
			and ExpectedIndexName <> IndexName
			and (IsPrimaryKey = 1 or  IsUniqueConstraint = 1)
	--Default
	insert into #Query(SQL)
		select 'exec sp_rename ' + quotename(quotename(SchemaName) + '.' + quotename(DefaultObjectName), '''')+','+quotename(ExpectedDefaultObjectName, '''') + ',' + quotename('Object', '''') +';'
		from maint.fn_GetDefaultStructure(@TableName)
		where SchemaName in (select SchemaName from maint.DatabaseSchemas)
			and ExpectedDefaultObjectName <> DefaultObjectName
	--FK
	insert into #Query(SQL)
		select 'exec sp_rename ' + quotename(quotename(SchemaName) + '.' + quotename(ObjectName), '''')+','+quotename(ExpectedObjectName, '''') + ',' + quotename('Object', '''') +';'
		from maint.fn_GetForeignKeyStructure(@TableName, null)
		where SchemaName in (select SchemaName from maint.DatabaseSchemas)
			and ExpectedObjectName <> ObjectName
	
	exec maint.usp_RunOrShowQuery @RunQuery = @ExecuteDirectly,  @TempTable = '#Query', @IngoreError = @IgnoreError
end


select * from z.v_Indexes