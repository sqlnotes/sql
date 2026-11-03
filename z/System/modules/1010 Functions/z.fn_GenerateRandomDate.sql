/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GenerateRandomDate.sql
*/
create or alter function z.fn_GenerateRandomDate(@Rand float, @DateFrom datetime, @DateTo datetime)
returns datetime
as
begin
	return	(
				select dateadd(second, floor(datediff_big(second, DateFrom, DateTo) * @Rand), DateFrom)
				from (
						select isnull(@DateFrom, dateadd(year, -1, getdate())) DateFrom, isnull(@DateTo, dateadd(year, 1, getdate())) DateTo
					) x0
			)
end