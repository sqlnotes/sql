create or alter function z.fn_GetFullErrorMessage()
returns nvarchar(max)
as
begin
return	N'Msg ' + isnull(cast(error_number() as nvarchar(max)), '') + N','
	+ N' Level ' + isnull(cast(error_severity() as nvarchar(max)), '')
	+ N', State ' + isnull(cast(error_state() as nvarchar(max)), '')
	+ N', Line ' + isnull(cast(error_line() as nvarchar(max)), '') + '
' + isnull(error_message(), '')
end