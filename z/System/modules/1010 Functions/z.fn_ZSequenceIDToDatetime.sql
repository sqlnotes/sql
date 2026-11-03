/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_ZSequenceIDToDatetime.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_zsequenceidtodatetime

Decodes the datetime component of a bigint identifier while ignoring its sequence bits.
*/
create or alter function z.fn_ZSequenceIDToDatetime(@SequenceID bigint)
returns datetime
as
begin
	return (
			select Date
			from (
					select dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01')) Date
					from (select @SequenceID/268435456 as seconds) x0
				) x1
			)
end





