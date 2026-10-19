create or alter function z.fn_ValidateScheduleParameter
(
	@Frequency varchar(20) = 'Daily',
	@Interval int = 1,
	@ByDay varchar(8000) = null,
	@IntradayFrequency varchar(20) = 'Second',
	@IntradayInterval int = 10,
	@ByTime varchar(8000) = '00:00',
	@StartDate date = null,
	@EndDate date = null
)
returns nvarchar(4000)
as
begin
	declare @Mode varchar(20), @IntradayMode varchar(20), @Days varchar(8000), @Times varchar(8000);
	select @Frequency = lower(replace(@Frequency collate Latin1_General_100_CI_AS, ' ', '')),
		@IntradayFrequency = lower(replace(@IntradayFrequency collate Latin1_General_100_CI_AS, ' ', '')),
		@Days = lower(replace(@ByDay collate Latin1_General_100_CI_AS, ' ', '')), @Times = replace(@ByTime, ' ', '');

	select @Mode = case
		when @Frequency collate Latin1_General_100_CI_AS in ('daily', 'days', 'day', 'd', 'dd') then 'Daily'
		when @Frequency collate Latin1_General_100_CI_AS in ('weekly', 'weeks', 'week', 'w', 'wk') then 'Weekly'
		when @Frequency collate Latin1_General_100_CI_AS in ('monthly', 'months', 'month', 'm', 'mon', 'mm') then 'Monthly'
		when @Frequency collate Latin1_General_100_CI_AS in ('specific', 'custom', 'adhoc', 'one', 'once', 'onetime', 'one-time') then 'Specific'
		when @Frequency collate Latin1_General_100_CI_AS in ('start', 'starts', 'agentstart', 'agentstarts', 'sqlagentstart', 'sqlagentstarts', 's') then 'Agent Starts'
		when @Frequency collate Latin1_General_100_CI_AS in ('idle', 'i') then 'Idle' end;
	if @Mode is null return N'Frequency must be Daily, Weekly, Monthly, Specific, Agent Start or Idle (or a supported alias).';

	if @Mode <> 'Specific'
	begin
		select @StartDate = isnull(@StartDate, convert(date, getdate()));
		if isnull(@StartDate, '19900101') < '19900101' or isnull(@EndDate, '99991231') < '19900101'
			return N'StartDate and EndDate must be on or after 1990-01-01.';
		if isnull(@StartDate, '19900101') > isnull(@EndDate, '99991231')
			return N'StartDate must not be after EndDate.';
	end;

	-- Validate the original complete list; normalization must never discard an invalid member.
	if @Mode in ('Weekly', 'Monthly', 'Specific')
	begin
		if nullif(@Days, '') is null or left(@Days, 1) = ',' or right(@Days, 1) = ',' or @Days like '%,,%'
			return N'ByDay must contain a nonempty comma-separated list without empty members.';

		if @Mode = 'Weekly' and exists
		(
			select 1 from string_split(@Days, ',')
			where value collate Latin1_General_100_CI_AS not in ('monday', 'mon', '1', 'tuesday', 'tue', 'tues', '2', 'wednesday', 'wed', '3',
				'thursday', 'thur', 'thurs', '4', 'friday', 'fri', '5', 'saturday', 'sat', '6', 'sunday', 'sun', '7')
		) return N'ByDay for Weekly must contain weekday names, weekday abbreviations or numbers 1 through 7.';

		if @Mode = 'Monthly' and exists
		(
			select 1 from string_split(@Days, ',') d
			where not (isnull(try_convert(int, d.value), 0) between 1 and 31 and d.value collate Latin1_General_100_CI_AS not like '%[^0-9]%')
				and not exists
				(
					select 1
					from (values ('first'), ('1st'), ('second'), ('2nd'), ('third'), ('3rd'), ('fourth'), ('4th'), ('last')) o(Name)
						cross join (values ('monday'), ('mon'), ('tuesday'), ('tue'), ('tues'), ('wednesday'), ('wed'),
							('thursday'), ('thur'), ('thurs'), ('friday'), ('fri'), ('saturday'), ('sat'), ('sunday'), ('sun'),
							('weekday'), ('weekend'), ('day')) w(Name)
					where d.value collate Latin1_General_100_CI_AS = o.Name + w.Name
				)
		) return N'ByDay for Monthly must contain days 1 through 31 or relative days such as First Monday or Last Weekday.';

		if @Mode = 'Specific' and exists
		(
			select 1 from string_split(@ByDay, ',')
			where try_convert(datetime2(0), trim(value), 121) is null
				or try_convert(datetime2(0), trim(value), 121) < convert(datetime2(0), '19900101', 112)
		) return N'ByDay for Specific must contain valid date-time values on or after 1990-01-01.';
	end;

	if @Mode in ('Daily', 'Weekly', 'Monthly')
	begin
		select @IntradayMode = case
			when @IntradayFrequency collate Latin1_General_100_CI_AS in ('hourly', 'hours', 'hour', 'h', 'hh') then 'Hourly'
			when @IntradayFrequency collate Latin1_General_100_CI_AS in ('minutes', 'minute', 'min', 'm', 'mm') then 'Minute'
			when @IntradayFrequency collate Latin1_General_100_CI_AS in ('seconds', 'second', 'sec') then 'Second'
			when @IntradayFrequency collate Latin1_General_100_CI_AS in ('specific', 'custom', 'adhoc', 'one', 'once', 'onetime', 'one-time') then 'Specific' end;
		if @IntradayMode is null return N'IntradayFrequency must be Hourly, Minute, Second or Specific (or a supported alias).';
		if nullif(@Times, '') is null or left(@Times, 1) = ',' or right(@Times, 1) = ',' or @Times like '%,,%'
			return N'ByTime must contain a nonempty comma-separated list without empty members.';

		if exists
		(
			select 1 from string_split(@Times, ',') t
				cross apply (select charindex('-', t.value) Position) p
				cross apply (select left(t.value, iif(p.Position = 0, len(t.value), p.Position - 1)) StartTime,
					case when p.Position > 0 then substring(t.value, p.Position + 1, 8000) end EndTime) r
			where r.StartTime not like '%:%' or r.StartTime like '%[^0-9:]%' or try_convert(time(0), r.StartTime) is null
				or (p.Position > 0 and (@IntradayMode = 'Specific' or r.EndTime not like '%:%'
					or r.EndTime like '%[^0-9:]%' or try_convert(time(0), r.EndTime) is null
					or try_convert(time(0), r.StartTime) > try_convert(time(0), r.EndTime)))
		) return N'ByTime must contain valid times; repeating ranges must end on or after their start, and Specific accepts times only.';
	end;

	-- Recurrence and intraday interval minimum/default normalization is intentionally retained.
	return null;
end;
go
