create or alter function z.fn_GetPeriodStart
(
	@Date datetime,
	@Period varchar(20), --'Second', 'Minute', 'Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly'
	@Interval int,
	@StartDate datetime2 = null
)
returns datetime
as
begin
	return	(
				select
					case @Period
						when 'Second' then dateadd(second, datediff_big(second, StartDate, @Date) / @Interval * @Interval, StartDate)
						when 'Minute' then dateadd(minute, datediff_big(minute, StartDate, @Date) / @Interval * @Interval, StartDate)
						when 'Hourly' then dateadd(hour, datediff_big(hour, StartDate, @Date) / @Interval * @Interval, StartDate)
						when 'Daily' then dateadd(day, datediff_big(day, StartDate, @Date) / @Interval * @Interval, StartDate)
						--when 'Weekly' then dateadd(week, datediff_big(week, StartDate, @Date) / @Interval * @Interval, StartDate)
						when 'Weekly' then dateadd(week, (datediff_big(day, dateadd(day, @@datefirst -7, StartDate), @Date))/7 / @Interval * @Interval, dateadd(day, @@datefirst-7, StartDate))
						when 'Monthly' then dateadd(month, datediff_big(month, StartDate, @Date) / @Interval * @Interval, StartDate)
						when 'Yearly' then dateadd(year, datediff_big(year, StartDate, @Date) / @Interval * @Interval, StartDate)
					end
				from (select convert(datetime2, isnull(@StartDate, '0006-01-01'), 121) StartDate) d -- this day is week start day (Sunday) as well
			)
end
go
