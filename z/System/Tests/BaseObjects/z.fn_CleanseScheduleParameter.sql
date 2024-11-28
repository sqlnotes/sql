declare @Frequency varchar(20), @Interval int = 1, @ByDay varchar(1000), @IntradayFrequency varchar(20), @IntradayInterval int = 10, @ByTime varchar(1000), @StartDate date = null, @EndDate date = null, @Description


select * from z.fn_CleanseScheduleParameter('Monthly', 1, '1stmon, 1, 2, 3, last sat, last day','second', 1, '06:00', '2024-01-01', '2025-01-01')

select * from z.fn_CleanseScheduleParameter('Monthly', 1, '1stmon, 1, 2, 3, last sat, last day','second', 1, '06:00-13:00', '2024-01-01', '2025-01-01')

select * from z.fn_CleanseScheduleParameter('once', 1, '1980-01-01 12:30, 1980-01-01 12:50','second', 1, '06:00-13:00', '2024-01-01', '2025-01-01')

select * from z.fn_CleanseScheduleParameter(null, 1, '1980-01-01 12:30, 1980-01-01 12:50','second', 1, '06:00-13:00', '2024-01-01', '2025-01-01')


