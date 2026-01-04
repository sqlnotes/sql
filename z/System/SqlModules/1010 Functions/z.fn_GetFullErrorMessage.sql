create or alter function z.fn_GetFullErrorMessage()
returns nvarchar(max)
as
begin
return	case when error_number() is not null then
			N'Msg ' + isnull(cast(error_number() as nvarchar(4000)), '') + N','
		+ N' Level ' + isnull(cast(error_severity() as nvarchar(4000)), '')
		+ N', State ' + isnull(cast(error_state() as nvarchar(4000)), '')
		+ N', Procedure ' + isnull(cast(error_procedure() as nvarchar(4000)), '')
		+ N', Line ' + isnull(cast(error_line() as nvarchar(4000)), '') + '
			' + isnull(error_message(), '(NULL)')
		end
end