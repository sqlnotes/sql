create or alter function z.fn_TraceLongRunningQueryByDay(@Days int)
returns table
as
return(
	select  cast(Date as date) Date,
			count(case when DurationInMS < 5000 then  1 end) [1.3-5],
			count(case when DurationInMS >= 5000 and DurationInMS < 10000 then 1 end) [5-10],
			count(case when DurationInMS >= 10000 and DurationInMS < 15000 then 1 end) [10-15],
			count(case when DurationInMS >= 15000 and DurationInMS < 20000 then 1 end) [15-20],
			count(case when DurationInMS >= 20000 and DurationInMS < 25000 then 1 end) [20-25],
			count(case when DurationInMS >= 25000 and DurationInMS < 30000 then 1 end) [25-30],
			count(case when DurationInMS >= 30000 and DurationInMS < 60000 then 1 end) [30-60],
			count(case when DurationInMS >= 60000 and DurationInMS < 90000 then 1 end) [60-90],
			count(case when DurationInMS >= 90000 and DurationInMS < 120000 then 1 end) [90-120],
			count(case when DurationInMS >= 120000 and DurationInMS < 180000 then 1 end) [120-180],
			count(case when DurationInMS >= 180000 and DurationInMS < 240000 then 1 end) [180-240],
			count(case when DurationInMS >= 240000 then 1 end) [240+]
	from (
			select /*z.fn_ZSequenceIDToDatetime(TraceSequence)*/ StartTime Date, Duration / 1000.0 DurationInMS
			from z.TraceLongRunningQuery
			where ApplicationName not like 'SQLAgent%'
      		  and ApplicationName not like 'SSIS%'
      		  and ApplicationName not like '%Microsoft SQL Server Management Studio%'
      		  and ApplicationName not in('SQLServerCEIP')
      		  and TextData not like '%backup%'
      		  and TraceSequence >= z.fn_GenerateZSequenceID(cast(dateadd(day, -abs(@Days), getdate()) as date), 0)
		) s
	group by cast(Date as date)

	)

