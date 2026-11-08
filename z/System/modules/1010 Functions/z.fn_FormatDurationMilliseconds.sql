/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_FormatDurationMilliseconds.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_formatdurationmilliseconds

Formats signed milliseconds as days hh:mm:ss.fff without time-of-day wrapping.
*/
create or alter function z.fn_FormatDurationMilliseconds(@Milliseconds bigint)
returns varchar(32)
as
begin
	declare @Magnitude decimal(20,0) = abs(convert(decimal(20,0), @Milliseconds));
	declare @Seconds bigint = convert(bigint, (@Magnitude - @Magnitude % 1000) / 1000);
	return case when @Milliseconds is null then null else
		iif(@Milliseconds < 0, '-', '') + convert(varchar(12), @Seconds / 86400) + ' '
		+ right('00' + convert(varchar(2), @Seconds % 86400 / 3600), 2) + ':'
		+ right('00' + convert(varchar(2), @Seconds % 3600 / 60), 2) + ':'
		+ right('00' + convert(varchar(2), @Seconds % 60), 2) + '.'
		+ right('000' + convert(varchar(3), @Magnitude % 1000), 3) end;
end
