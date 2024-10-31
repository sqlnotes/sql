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
		if not exists(select * from sys.tables where object_id = @ObjectID)
			and not exists(select * from sys.views where object_id = @ObjectID)
		begin
			raiserror('Could not find object %s.', 16, 1, @TableName)
			return
		end
	end
	declare c cursor local static for
		select	case when IsPrimaryKey = 1 or IsUniqueConstraint = 1 then 
						quotename(SchemaName) + '.' + quotename(IndexName) -- constraint
					else
						quotename(SchemaName) + '.' + quotename(ObjectName) + '.' + quotename(IndexName)-- indexes
				end,
				ExpectedIndexName, 
				case when IsPrimaryKey = 1 or IsUniqueConstraint = 1 then 'Object' else 'Index'end 
		from z.v_Indexes
		where (@ObjectID is null or ObjectID = @ObjectID)
			and ExpectedIndexName <> IndexName
		union all
		select	quotename(SchemaName) + '.' + quotename(DefaultName),
				ExpectedDefaultName,
				'Object'
		from z.v_DefaultConstraints
		where (@ObjectID is null or ParentObjectID = @ObjectID)
			and ExpectedDefaultName <> DefaultName
		union all
		select quotename(SchemaName) + '.' + quotename(ForeignKeyName),
				ExpectedForeignKeyName,
				'Object' 
		from z.v_ForeignKeys
		where (@ObjectID is null or ParentObjectID = @ObjectID)
			and ExpectedForeignKeyName <> ForeignKeyName
	open c
	fetch next from c into @ObjectName, @NewName, @ObjectType
	while @@fetch_status = 0
	begin
		begin try
			print 'Renaming ' + @ObjectName + ' --> ' + @NewName
			exec sp_rename @objname = @ObjectName, @newname = @NewName, @objtype = @ObjectType
		end try
		begin catch
			if @@trancount > 0
				rollback;
			if @IgnoreError = 1
				print z.fn_GetFullErrorMessage();
			throw;
		end catch
		fetch next from c into @ObjectName, @NewName, @ObjectType
	end
	close c
	deallocate c
end
