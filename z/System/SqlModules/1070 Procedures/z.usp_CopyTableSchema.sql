create or alter procedure z.usp_CopyTableSchema
(
	@FullSourceTableName nvarchar(256),
	@FullTargetTableName nvarchar(256),
	@FileGroupOrPartitionScheme nvarchar(128) = null, -- NULL: 'Use Source Object File Group', 'Use default Database File Group', 'Use Source Object Partition Scheme', FileGroupName or PartitionSchemeName(FieldName)
	@DropTargetTableIfExists bit = 1,
	@CopyIdentity bit = 0,
	@CopyTableSchema bit = 1,
	@CopyIndexes bit = 1,
	@CopyXMLIndexes bit = 0,
	@CopyDefault bit = 1,
	@ScriptAfterTableCreation nvarchar(max) = null,
	@DataCompression varchar(20) = null,
	@PrintCode bit = 0
)
as
begin
	set nocount, xact_abort on
	declare @Ordinal int, @PartName varchar(30), @SQL nvarchar(max)

	select Ordinal, PartName, Definition into #1
	from z.fn_BuildQueryCopyTableSchema(@FullSourceTableName, @FullTargetTableName, @FileGroupOrPartitionScheme, @CopyIdentity, @DataCompression)
	if @@rowcount = 0
	begin
		raiserror('Could not retrieve script.', 16, 1)
		return
	end
	begin try
	begin tran
	if @DropTargetTableIfExists = 1
	begin
		if object_id(@FullTargetTableName) is not null
		begin
			select @SQL = 'drop table ' + @FullTargetTableName
			if @PrintCode = 1
				exec z.usp_PrintString @SQL;
			exec(@SQL)
		end
	end
	declare c cursor local for
		select Ordinal, PartName, Definition
		from (
				select Ordinal, PartName, Definition 
				from #1
				union all
				select 10000, 'Table 1', @ScriptAfterTableCreation
			) s
		where Definition is not null
			and (
						@CopyTableSchema = 1 and s.PartName in('Table')
					or @CopyIndexes = 1 and s.PartName not in ('Default') and s.PartName not like '%XML%'
					or @CopyXMLIndexes = 1 and s.PartName not in ('Default') and s.PartName like '%XML%'
					or @CopyDefault = 1 and s.PartName in ('Default')
					or @ScriptAfterTableCreation is not null and s.PartName in('Table 1')
				)

		order by Ordinal
		
	open c
	fetch next from c into @Ordinal, @PartName, @SQL
	while @@fetch_status = 0
	begin
		if @PrintCode = 1
			exec z.usp_PrintString @SQL
		exec(@SQL)

		fetch next from c into @Ordinal, @PartName, @SQL
	end
	close c
	deallocate c

	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end