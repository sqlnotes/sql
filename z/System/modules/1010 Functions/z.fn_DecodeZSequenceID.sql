/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_DecodeZSequenceID.sql
*/
create or alter function z.fn_DecodeZSequenceID(@SequenceID bigint)
returns table
as
return 
(
	select dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01')) Date, x0.Sequence
	from (select @SequenceID/268435456 as seconds, @SequenceID%268435456 as Sequence) x0
)