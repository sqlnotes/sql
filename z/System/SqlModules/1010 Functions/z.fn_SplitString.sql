create or alter function z.fn_SplitString
(
	@Str nvarchar(max),
	@Separator nvarchar(100)
)
returns table
as return
(
	with x0	as
	(
		select cast(1 as bigint) as StartPosition, isnull(cast(datalength(@Str)/2 as bigint), 0) TotalLength, isnull(cast(datalength(@Separator)/2 as bigint), 0) SeparatorLength
	),
	x1 as
	(
		select 1 as Ordinal, x0.StartPosition, x0.TotalLength, x0.SeparatorLength, charindex(@Separator, @Str, x0.StartPosition) NextSeparatorPosition
		from x0
		where TotalLength >0 and SeparatorLength> 0
		union all
		select	x1.Ordinal + 1 Ordinal, 
				x1.NextSeparatorPosition + x1.SeparatorLength StartPosition,
				x1.TotalLength, x1.SeparatorLength,
				charindex(@Separator, @Str, x1.NextSeparatorPosition + x1.SeparatorLength) NextSeparatorPosition
		from x1
		where x1.NextSeparatorPosition > 0
	)
	select Ordinal, case when NextSeparatorPosition > 0 then substring(@str, StartPosition, NextSeparatorPosition - StartPosition) else right(@Str, TotalLength - StartPosition + 1) end Value 
	from x1
)


