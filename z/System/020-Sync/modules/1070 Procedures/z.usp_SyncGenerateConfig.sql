create or alter procedure z.usp_SyncGenerateConfig
(
	@PublisherID int = null,
	@FullTableName nvarchar(128),
	@ConfigID int = null output,
	@NeedInitialize bit = 0 output,
	@UpdateAndInitializeWhenNeeded bit = 1,
	@Activate bit = 1,
	@SyncMethod varchar(100) = 'RowVersion'
)
as
begin
	set nocount on
	declare @TableName nvarchar(128) = object_name(object_id(@FullTableName)),
			@SchemaName nvarchar(128) = object_schema_name(object_id(@FullTableName)),
			@InterfaceName nvarchar(128) = quotename(object_schema_name(object_id(@FullTableName))) + '.' + quotename(object_name(object_id(@FullTableName)) + '_Interface'),
			@ConfigName varchar(128) = z.fn_SyncGetConfigName(@publisherID, @FullTableName),
			@ColumnList nvarchar(max), @ColumnListChangeTracking nvarchar(max), @FilterProcedure nvarchar(128) = 'z.usp_SyncFilterRowVersion', @FilterField nvarchar(128) = 'RowVersion',
			@InitialQuery nvarchar(max), @FilteredQuery nvarchar(max), @BatchSize int = 1500, @TargetObjectFieldList nvarchar(max),
			@ColumnListChangeDataCapture nvarchar(max)

	select @FullTableName = quotename(@SchemaName) + '.' + quotename(@TableName), @ConfigID = null
	if @SyncMethod = 'ChangeTracking'
	begin
		if @@trancount = 0
			exec z.usp_SyncEnableChangeTrackingOnDB
		exec z.usp_SyncEnableChangeTracking null, null, @FullTableName
		select @FilterProcedure = 'z.usp_SyncFilterChangeTracking'
	end
	else if @SyncMethod = 'ChangeDataCapture'
	begin
		exec z.usp_SyncEnableChangeDataCaptureOnDB
		exec z.usp_SyncEnableChangeDataCapture null, null, @FullTableName
		select @FilterProcedure = 'z.usp_SyncFilterChangeDataCapture'
	end
	else if @SyncMethod = 'RowVersion'
	begin
		select @FilterProcedure = 'z.usp_SyncFilterRowVersion'
	end
	else if @SyncMethod = 'Snapshot'
	begin
		select @FilterProcedure = 'z.usp_SyncFilterSnapshot'
	end
	else
	begin
		raiserror('Only SyncMethod ChangeDataCapture, ChangeTracking, RowVersion, and Snapshot are supported. %s is not supported.', 16, 1, @SyncMethod)
		return
	end

	create table #TargetDefinition(ObjectID int null,SchemaName nvarchar(128) null,ObjectName nvarchar(128) null,ColumnName nvarchar(128) null,ColumnID int null,PrimaryKeyOrder int null,DataLength smallint not null,DataType nvarchar(171) null,IsNullable bit null,ReadOnly bit null,CollationName sysname null,IsIdentity bit null,IsComputed bit null,ComputedColumnDefinition nvarchar(max) null,IsTimestamp bit null,SystemType nvarchar(128) null,UserType nvarchar(128) null,MaxLength smallint not null,DataTypeByUserType nvarchar(171) null)
	insert into #TargetDefinition
		exec z.usp_SyncGetTableSchema null, null, @FullTableName
	delete #TargetDefinition where IsComputed = 1 or IsTimestamp = 1

	select @ColumnList = (
							select
									case when (DataType like 'datetime%' or DataType like 'time%') then
										'convert(varchar(100), a0.' + quotename(ColumnName) + ', 121) as '+quotename(ColumnName)
									else
										quotename(ColumnName)
									end + ','

							from #TargetDefinition
							order by ColumnID
							for xml path(''), type
							).value('.', 'nvarchar(max)') + 'cast(0 as bit) ___IsDeleted___'

	select @ColumnListChangeTracking = (
							select
									case when (DataType like 'datetime%' or DataType like 'time%') then
										'convert(varchar(100), ' + iif(PrimaryKeyOrder > 0, 'isnull(a0.' + quotename(ColumnName) + ', ct.' + quotename(ColumnName) + ')', 'a0.' + quotename(ColumnName)) + ', 121) as '+quotename(ColumnName)
									else
										iif(PrimaryKeyOrder > 0, 'isnull(a0.' + quotename(ColumnName) + ', ct.' + quotename(ColumnName)+') as '+quotename(ColumnName) , 'a0.' + quotename(ColumnName))
									end + ','

							from #TargetDefinition
							order by ColumnID
							for xml path(''), type
							).value('.', 'nvarchar(max)') + 'cast(case when ct.sys_change_operation = ''D'' or a0.' + (select top 1 quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by ColumnID) + ' is null then 1 else 0 end as bit) ___IsDeleted___'

	select @ColumnListChangeDataCapture = (
							select
									case when (DataType like 'datetime%' or DataType like 'time%') then
										'convert(varchar(100), a0.' + quotename(ColumnName) + ', 121) as '+quotename(ColumnName)
									else
										'a0.' + quotename(ColumnName)
									end + ','

							from #TargetDefinition
							order by ColumnID
							for xml path(''), type
							).value('.', 'nvarchar(max)') + 'cast(case when a0.__$operation = 1 then 1 else 0 end as bit) ___IsDeleted___'

	select @TargetObjectFieldList = (
							select quotename(ColumnName) + ','
							from #TargetDefinition
							order by ColumnID
							for xml path(''), type
							).value('.', 'nvarchar(max)') + ' ___IsDeleted___'

		if @SyncMethod = 'RowVersion'
		begin
			select	@InitialQuery = cast('select ' as nvarchar(max)) + @ColumnList + ' from ' + @FullTableName + ' a0'
			select	@FilteredQuery = cast('select ' as nvarchar(max)) + @ColumnList + ' from ' + @FullTableName + ' a0 with(forceseek) where RowVersion > cast(@FromValue as binary(8))	and RowVersion <= cast(@ToValue as binary(8))'
		end
		else if @SyncMethod = 'ChangeTracking'
		begin
			select	@InitialQuery = cast('select ' as nvarchar(max)) + @ColumnList + ' from ' + @FullTableName + ' a0'
			select	@FilteredQuery = cast('declare @From bigint = cast(@FromValue as bigint);select ' as nvarchar(max)) + @ColumnListChangeTracking + '
from changetable(changes ' + @FullTableName + ', @From) ct
	left outer join ' + @FullTableName + ' a0 on ' + stuff((select ' and a0.' + quotename(ColumnName) + ' = ct.' + quotename(ColumnName) from #TargetDefinition where PrimaryKeyOrder > 0 order by ColumnID for xml path(''), type). value('.', 'nvarchar(max)'), 1, 5, '') + '
order by ___IsDeleted___ desc'
		end
		else if @SyncMethod = 'ChangeDataCapture'
		begin
			select	@InitialQuery = cast('select ' as nvarchar(max)) + @ColumnList + ' from ' + @FullTableName + ' a0'
			select	@FilteredQuery = cast('declare @From binary(10) = cast(@FromValue as binary(10)), @To binary(10) = cast(@ToValue as binary(10));select ' as nvarchar(max)) + @ColumnListChangeDataCapture + '
from cdc.' + quotename('fn_cdc_get_net_changes_' + z.fn_SyncGetChangeDataCaptureInstanceName(@FullTableName)) + '(@From, @To, ''all with merge'') a0
where a0.__$start_lsn > @From
order by ___IsDeleted___ desc'
		end
		if @SyncMethod = 'Snapshot'
		begin
			select	@InitialQuery = cast('select ' as nvarchar(max)) + @ColumnList + ' from ' + @FullTableName + ' a0'
			select	@FilteredQuery = @InitialQuery
		end
	select @ConfigID = ConfigID from z.SyncConfig where Name = @ConfigName
	if @@rowcount = 0
	begin
		insert into z.SyncConfig(Name, InitializationQuery, FilterProcedure, FilteredQuery, SourceTable, FilterField, TargetObject, TargetObjectFieldList, BatchSize, IsActive)
			values(@ConfigName, @InitialQuery, @FilterProcedure, @FilteredQuery, @FullTableName, @FilterField, @InterfaceName, @TargetObjectFieldList, @BatchSize, @Activate)
		select @ConfigID = scope_identity(), @NeedInitialize = 1
		return
	end
	update z.SyncConfig
		set IsActive = @Activate,
			InitializationQuery = @InitialQuery,
			FilterProcedure = @FilterProcedure,
			FilteredQuery = @FilteredQuery,
			SourceTable = @FullTableName,
			FilterField = @FilterField,
			TargetObject = @InterfaceName,
			TargetObjectFieldList = @TargetObjectFieldList,
			BatchSize = @BatchSize
	where ConfigID = @ConfigID

	if @NeedInitialize = 1
		delete z.SyncProgress where ConfigID = @ConfigID
	if @UpdateAndInitializeWhenNeeded = 1
	begin
		update c
			set Name = @ConfigName, InitializationQuery = @InitialQuery, FilterProcedure = @FilterProcedure, FilteredQuery = @FilteredQuery,  SourceTable = @FullTableName, FilterField = @FilterField, TargetObject = @InterfaceName, TargetObjectFieldList = @TargetObjectFieldList, BatchSize = @BatchSize, IsActive = @Activate
		from z.SyncConfig c
		where c.ConfigID =@ConfigID
			and (
					c.TargetObjectFieldList <> @TargetObjectFieldList
					or c.TargetObject <> @InterfaceName
					or c.SourceTable <> @FullTableName
					or c.FilterProcedure = @FilterProcedure
				)
		if @@rowcount >0
		begin
			delete z.SyncProgress where ConfigID = @ConfigID
			select @NeedInitialize = 1
		end
	end
end


go
