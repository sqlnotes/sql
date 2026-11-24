create or alter function z.fn_SyncCDCGetFuncationName
(
	@CaptureInstancePrefix nvarchar(256) = 'SchemaZSync',
	@TableName nvarchar(256)
)
returns table
as
return
	(
			select Type, object_schema_name(o.ObjectID) + '.' + object_name(o.ObjectID) ObjectName
			from (
					select 'all' Type, object_id('cdc.fn_cdc_get_all_changes_'+@CaptureInstancePrefix + '_' + object_schema_name(object_id(@TableName)) + '_' + object_name(object_id(@TableName))) as ObjectID
					union all
					select 'net', object_id('cdc.fn_cdc_get_net_changes_'+@CaptureInstancePrefix + '_' + object_schema_name(object_id(@TableName)) + '_' + object_name(object_id(@TableName)))ObjectID
				)o
			)


go
