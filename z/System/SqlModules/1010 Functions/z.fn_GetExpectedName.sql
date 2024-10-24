create or alter function z.fn_GetExpectedName
(
	@Type varchar(50), -- Index, UniqueKey, PrimaryKey, ColumnStore, ForeignKey, Default
	@ParentSchemaName sysname, 
	@ParentObjectName sysname, 
	@ParentColumns nvarchar(max), --col1,col2...no space
	@ReferencedSchemaName sysname,
	@ReferencedObjectName sysname
)
returns nvarchar(128)
as
begin
	return	case 
				when @Type in ('Index') then 'IX_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('UniqueKey') then 'UQ_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('PrimaryKey') then 'PK_' + @ParentSchemaName + '_' + @ParentObjectName 
				when @Type in ('ColumnStore') then 'IX_CS_' + @ParentSchemaName + '_' + @ParentObjectName 
				when @Type in ('ForeignKey') then 'FK_' + @ParentSchemaName + '_' + @ParentObjectName
													+ case when @ParentSchemaName = @ReferencedSchemaName then '' else '_' + @ReferencedSchemaName end
													+ '_' + @ReferencedObjectName  
													+ '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('Default') then 'DF_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
			end
			
end

