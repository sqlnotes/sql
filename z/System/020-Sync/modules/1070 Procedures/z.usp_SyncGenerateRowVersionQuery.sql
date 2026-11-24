create or alter procedure z.usp_SyncGenerateRowVersionQuery
(
	@InitializationQuery nvarchar(max) output,
	@FilteredQuery nvarchar(max) output,
	@ColumnList nvarchar(max) output,
	@CodeForInterface nvarchar(max) = null output,
	@OrderBy nvarchar(max) = null
)
as
begin
	set nocount on
	declare @DefinitionA table (IsHidden bit,ColumnID int,ColumnName nvarchar(128),IsNullable bit,SystemTypeID int,SystemTypeName nvarchar(256),MaxLength smallint,Precision tinyint,Scale tinyint,CollationName nvarchar(128),UserTypeID int,UserTypeDatabase nvarchar(128),UserTypeSchema nvarchar(128),UserTypeName nvarchar(128),AssemblyQualifiedTypeName nvarchar(4000),XmlCollectionID int,XmlCollectionDatabase nvarchar(128),XmlCollectionSchema nvarchar(128),XmlCollectionName nvarchar(128),IsXmlDocument bit,IsCaseSensitive bit,IsFixedLengthClrType bit,SourceServer nvarchar(128),SourceDatabase nvarchar(128),SourceSchema nvarchar(128),SourceTable nvarchar(128),SourceColumn nvarchar(128),IsIdentityColumn bit,IsPartOfUniqueKey bit,IsUpdateable bit,IsComputedColumn bit,IsSparseColumnSet bit,OrdinalInOrderByList smallint,OrderByListLength smallint,OrderByIsDescending smallint,TdsTypeID int,TdsLength int,TdsCollationID int,TdsCollationSortID tinyint)
	declare @DefinitionB table (IsHidden bit,ColumnID int,ColumnName nvarchar(128),IsNullable bit,SystemTypeID int,SystemTypeName nvarchar(256),MaxLength smallint,Precision tinyint,Scale tinyint,CollationName nvarchar(128),UserTypeID int,UserTypeDatabase nvarchar(128),UserTypeSchema nvarchar(128),UserTypeName nvarchar(128),AssemblyQualifiedTypeName nvarchar(4000),XmlCollectionID int,XmlCollectionDatabase nvarchar(128),XmlCollectionSchema nvarchar(128),XmlCollectionName nvarchar(128),IsXmlDocument bit,IsCaseSensitive bit,IsFixedLengthClrType bit,SourceServer nvarchar(128),SourceDatabase nvarchar(128),SourceSchema nvarchar(128),SourceTable nvarchar(128),SourceColumn nvarchar(128),IsIdentityColumn bit,IsPartOfUniqueKey bit,IsUpdateable bit,IsComputedColumn bit,IsSparseColumnSet bit,OrdinalInOrderByList smallint,OrderByListLength smallint,OrderByIsDescending smallint,TdsTypeID int,TdsLength int,TdsCollationID int,TdsCollationSortID tinyint)

	insert into @DefinitionA(IsHidden, ColumnID, ColumnName, IsNullable, SystemTypeID, SystemTypeName, MaxLength, Precision, Scale, CollationName, UserTypeID, UserTypeDatabase, UserTypeSchema, UserTypeName, AssemblyQualifiedTypeName, XmlCollectionID, XmlCollectionDatabase, XmlCollectionSchema, XmlCollectionName, IsXmlDocument, IsCaseSensitive, IsFixedLengthClrType, SourceServer, SourceDatabase, SourceSchema, SourceTable, SourceColumn, IsIdentityColumn, IsPartOfUniqueKey, IsUpdateable, IsComputedColumn, IsSparseColumnSet, OrdinalInOrderByList, OrderByListLength, OrderByIsDescending, TdsTypeID, TdsLength, TdsCollationID, TdsCollationSortID)
		exec sp_describe_first_result_set @InitializationQuery

	insert into @DefinitionB(IsHidden, ColumnID, ColumnName, IsNullable, SystemTypeID, SystemTypeName, MaxLength, Precision, Scale, CollationName, UserTypeID, UserTypeDatabase, UserTypeSchema, UserTypeName, AssemblyQualifiedTypeName, XmlCollectionID, XmlCollectionDatabase, XmlCollectionSchema, XmlCollectionName, IsXmlDocument, IsCaseSensitive, IsFixedLengthClrType, SourceServer, SourceDatabase, SourceSchema, SourceTable, SourceColumn, IsIdentityColumn, IsPartOfUniqueKey, IsUpdateable, IsComputedColumn, IsSparseColumnSet, OrdinalInOrderByList, OrderByListLength, OrderByIsDescending, TdsTypeID, TdsLength, TdsCollationID, TdsCollationSortID)
		exec sp_describe_first_result_set @FilteredQuery, N'@From binary(8), @To binary(8)'
	if exists(
				select *
				from @DefinitionA a
					full outer join @DefinitionB b on a.ColumnID = b.ColumnID and a.ColumnName = b.ColumnName
				where a.ColumnID is null or b.ColumnID is null
			)
	begin
		raiserror('Initialization query''s column count and order does not match', 16, 1)
		return
	end
	select @ColumnList = stuff((select ','+quotename(ColumnName) from @DefinitionA order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, '')
	select @InitializationQuery = cast('select ' as nvarchar(max)) + a.SelectList + '
from (' + @InitializationQuery + '
) a',
			@FilteredQuery = cast('declare @From binary(8) = cast(@FromValue as binary(8)), @To binary(8) = cast(@ToValue as binary(8));
select ' as nvarchar(max)) + a.SelectList + '
from (' + @FilteredQuery + '
) a
' + isnull('order by ' + @OrderBy, '')
	from (
			select stuff(
							(
								select
										','+case when (SystemTypeName like 'datetime%' or SystemTypeName like 'time%') then
											'convert(varchar(100), ' + quotename(ColumnName) + ', 121) as '+quotename(ColumnName)
										else
											'' + quotename(ColumnName)
										end

								from @DefinitionA
								order by ColumnID
								for xml path(''), type
								).value('.', 'nvarchar(max)')
							, 1, 1, '')as SelectList
		) a
	delete @DefinitionA
	insert into @DefinitionA(IsHidden, ColumnID, ColumnName, IsNullable, SystemTypeID, SystemTypeName, MaxLength, Precision, Scale, CollationName, UserTypeID, UserTypeDatabase, UserTypeSchema, UserTypeName, AssemblyQualifiedTypeName, XmlCollectionID, XmlCollectionDatabase, XmlCollectionSchema, XmlCollectionName, IsXmlDocument, IsCaseSensitive, IsFixedLengthClrType, SourceServer, SourceDatabase, SourceSchema, SourceTable, SourceColumn, IsIdentityColumn, IsPartOfUniqueKey, IsUpdateable, IsComputedColumn, IsSparseColumnSet, OrdinalInOrderByList, OrderByListLength, OrderByIsDescending, TdsTypeID, TdsLength, TdsCollationID, TdsCollationSortID)
		exec sp_describe_first_result_set @InitializationQuery
	select @CodeForInterface = cast('select ' as nvarchar(max))
		+ stuff(
				(
					select ',cast(null as ' + SystemTypeName + ') as ' + quotename(ColumnName)
					from @DefinitionA a for xml path(''), type
				).value('.', 'nvarchar(max)')
				, 1, 1, ''),
			@ColumnList = stuff((select ','+quotename(ColumnName) from @DefinitionA order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)'), 1, 1, '')
end


go
