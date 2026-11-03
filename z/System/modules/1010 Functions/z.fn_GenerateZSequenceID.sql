/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GenerateZSequenceID.sql
*/
create or alter function z.fn_GenerateZSequenceID(@Date datetime, @SeqGeneralID bigint)
returns bigint
as
begin
	return datediff_big(second, '1900-01-01', isnull(@Date, getutcdate())) * 268435456 | @SeqGeneralID
end
