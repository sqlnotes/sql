create or alter function z.fn_SyncCDCGetInstantName
(
	@CaptureInstancePrefix nvarchar(256) = 'SchemaZSync',
	@TableName nvarchar(256)
)
returns nvarchar(256)
as
begin
	return @CaptureInstancePrefix+ '_' + object_schema_name(object_id(@TableName)) + '_' + object_name(object_id(@TableName))
end

go
