create or alter procedure z.usp_SyncCreatePublisherTable
(
	@PublisherID int,
	@TableName nvarchar(128),
	@SyncMethod varchar(100) = 'RowVersion',
	@AlternatePrimaryKey varchar(3000) = null
)
as
begin
	set nocount, xact_abort on
	declare @ConfigID int, @DropTable nvarchar(max),	@CreateSchema nvarchar(max), @CreateTable nvarchar(max), @CreateInterface nvarchar(max), @CreateTrigger nvarchar(max)
	select @TableName = quotename(object_schema_name(object_id(@TableName))) + '.' + quotename(object_name(object_id(@TableName)))
	if @TableName is null
	begin
		raiserror('Could not find table %s', 16, 1, @TableName)
		return
	end
	exec z.usp_SyncGenerateConfig @PublisherID = @PublisherID, @FullTableName = @TableName, @ConfigID = @ConfigID output, @SyncMethod = @SyncMethod
	exec z.usp_SyncGenerateInitializationScript @FullTableName = @TableName, @DropTable = @DropTable output, @CreateSchema = @CreateSchema output, @CreateTable = @CreateTable output, @CreateInterface = @CreateInterface output, @CreateTrigger = @CreateTrigger output, @SyncMethod = @SyncMethod, @AlternatePrimaryKey = @AlternatePrimaryKey
	begin transaction
	merge z.SyncPublisherTable t
	using(select @PublisherID as PublisherID) s on t.PublisherID = s.PublisherID and t.TableName = @TableName
	when not matched then
		insert(PublisherID, TableName, ConfigID)
			values(@PublisherID, @TableName, @ConfigID)
	when matched and t.ConfigID <> @ConfigID then
		update set ConfigID = @ConfigID
	;

	;with s as
	(
		select ScriptOrder, Script
		from (values(1, @DropTable),
					(2, @CreateSchema),
					(3, @CreateTable),
					(4, @CreateInterface),
					(5, @CreateTrigger)
			) s(ScriptOrder, Script)
	),
	t as
	(
		select *
		from z.SyncPublisherInitializationScript t
		where t.PublisherID = @PublisherID and t.ConfigID = @ConfigID
	)
	merge t
	using s on t.ScriptOrder = s.ScriptOrder
	when not matched then
		insert (PublisherID, ConfigID, ScriptOrder, Script)
			values(@PublisherID, @ConfigID, s.ScriptOrder, s.Script)
	when matched and  t.Script <> s.Script then
		update set t.Script = s.Script
	when not matched by source then
		delete
	;

	commit
end


go
