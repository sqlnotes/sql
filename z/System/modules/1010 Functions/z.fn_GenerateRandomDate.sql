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