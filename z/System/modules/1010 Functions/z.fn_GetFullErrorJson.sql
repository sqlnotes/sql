/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GetFullErrorJson.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_getfullerrorjson

Returns the current CATCH error context as a JSON object.
*/
create or alter function z.fn_GetFullErrorJson()
returns nvarchar(max)
as
begin
	if error_number() is null
		return null;

	return	(
				select	error_number() ErrorNumber, error_severity() ErrorSeverity, error_state() ErrorState,
						error_procedure() ErrorProcedure, error_line() ErrorLine, error_message() ErrorMessage
				for json path, include_null_values, without_array_wrapper
			);
end;
