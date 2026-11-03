/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GenerateZSequenceID.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_generatezsequenceid

Combines seconds since 1900 with supplied sequence bits into a bigint identifier, using UTC time
when the date is null.
*/
create or alter function z.fn_GenerateZSequenceID(@Date datetime, @SeqGeneralID bigint)
returns bigint
as
begin
	return datediff_big(second, '1900-01-01', isnull(@Date, getutcdate())) * 268435456 | @SeqGeneralID
end
