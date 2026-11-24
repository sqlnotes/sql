create or alter function z.fn_SyncGetChangeDataCaptureInstanceName
(
	@TableName nvarchar(256)
)
returns nvarchar(256)
as
begin
	return 'SchemaZSync_' + object_schema_name(object_id(@TableName)) + '_' + object_name(object_id(@TableName))
end

go
