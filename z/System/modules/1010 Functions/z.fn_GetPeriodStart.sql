/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_GetPeriodStart.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_getperiodstart

Calculates the start of a requested date interval, using Monday-based weekly anchors.
*/
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
	declare	@Anchor datetime2 = isnull(@StartDate, '20200101'), @At datetime2 = @Date,
			@Step bigint = abs(convert(bigint, nullif(@Interval, 0))), @Units bigint, @Boundary datetime2;
	if @Period = 'Weekly'
	begin
		-- Multiweek periods start on the Monday of the anchor's week, at midnight.
		select	@Anchor = convert(date, isnull(@StartDate, '19000101'));
		select	@Anchor = dateadd(day, -((datediff(day, '19000101', @Anchor) % 7 + 7) % 7), @Anchor),
				@Step = 7 * @Step, @Period = 'Daily';
	end;

	-- DATEDIFF counts calendar boundaries. Match the original anchor's position
	-- within the input unit before deciding how many whole units have elapsed.
	declare @DayAnchor datetime2 = dateadd(day, datediff(day, @Anchor, @At), @Anchor);
	select	@Units = case @Period
				when 'Second' then datediff_big(second, @Anchor, @At)
				when 'Minute' then datediff_big(minute, @Anchor, @At)
				when 'Hourly' then datediff_big(hour, @Anchor, @At)
				when 'Daily' then datediff(day, @Anchor, @At)
				when 'Monthly' then datediff(month, @Anchor, @At)
				when 'Yearly' then datediff(year, @Anchor, @At)
			end,
			@Boundary = case @Period
				when 'Second' then dateadd(second, datediff(second, @DayAnchor, @At), @DayAnchor)
				when 'Minute' then dateadd(minute, datediff(minute, @DayAnchor, @At), @DayAnchor)
				when 'Hourly' then dateadd(hour, datediff(hour, @DayAnchor, @At), @DayAnchor)
				when 'Daily' then @DayAnchor
				when 'Monthly' then dateadd(month, datediff(month, @Anchor, @At), @Anchor)
				when 'Yearly' then dateadd(year, datediff(year, @Anchor, @At), @Anchor)
			end;
	if @Boundary > @At select @Units -= 1;
	-- Normalize a negative remainder to floor dates on both sides of the anchor.
	select	@Units = @Units - ((@Units % @Step + @Step) % @Step);
	return case @Period
		when 'Second' then dateadd(second, @Units, @Anchor)
		when 'Minute' then dateadd(minute, @Units, @Anchor)
		when 'Hourly' then dateadd(hour, @Units, @Anchor)
		when 'Daily' then dateadd(day, @Units, @Anchor)
		when 'Monthly' then dateadd(month, @Units, @Anchor)
		when 'Yearly' then dateadd(year, @Units, @Anchor)
	end;
end
go
