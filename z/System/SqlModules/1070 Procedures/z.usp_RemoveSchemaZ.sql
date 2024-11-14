create or alter procedure z.usp_RemoveSchemaZ
(
	@Confirm bit = 0
)
as
begin
	set nocount on
	if isnull(@Confirm, 0) = 0
	begin
		raiserror('Please confirm removing z schema by passing value 1', 16, 1)
		return
	end
	declare @SQL nvarchar(max)	
	while 1=1
	begin
		select top 1 @SQL =  'drop ' + '' +
			case type_desc
				when 'USER_TABLE' then 'table '
				when 'SQL_STORED_PROCEDURE' then 'procedure '
				when 'SQL_INLINE_TABLE_VALUED_FUNCTION' then 'function'
				when 'SQL_SCALAR_FUNCTION' then 'function'
				when 'VIEW' then 'view '
			end + ' z.'+  name + ';'
		from sys.objects where schema_id = schema_id('z')
			and  type_desc in ('USER_TABLE', 'SQL_STORED_PROCEDURE', 'SQL_INLINE_TABLE_VALUED_FUNCTION', 'VIEW', 'SQL_SCALAR_FUNCTION')
			and object_id not in (@@procid)
		if @@rowcount = 0
			break
		begin try
		exec(@SQL)
		end try
		begin catch
		print error_message()
		end catch
	end
	drop procedure z.usp_RemoveSchemaZ;
	if schema_id('z') is not null
		exec('drop schema z;')
end