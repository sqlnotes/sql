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
				when @Type in ('NONCLUSTERED COLUMNSTORE') then 'IX_NCI_' + @ParentSchemaName + '_' + @ParentObjectName 
				when @Type in ('CLUSTERED COLUMNSTORE') then 'IX_CCI_' + @ParentSchemaName + '_' + @ParentObjectName 
				when @Type in ('ForeignKey') then 'FK_' + @ParentSchemaName + '_' + @ParentObjectName
													+ case when @ParentSchemaName = @ReferencedSchemaName then '' else '_' + @ReferencedSchemaName end
													+ '_' + @ReferencedObjectName  
													+ '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('Default') then 'DF_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('PRIMARY_XML') then 'IX_XML_PR_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '')
				when @Type in ('SECONDARY_XML_PATH') then 'IX_XML_P_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '') + '_PATH'
				when @Type in ('SECONDARY_XML_VALUE') then 'IX_XML_V_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '') + '_VALUE'
				when @Type in ('SECONDARY_XML_PROPERTY') then 'IX_XML_R_' + @ParentSchemaName + '_' + @ParentObjectName + '_' + replace(translate(@ParentColumns, ', ]', '__['), '[', '') + '_PROPERTY'
			end
			
end

