create or alter function z.fn_ReadLinesFromString
(
	@Str nvarchar(max)
)
returns table
as return
(
	with x0	as
	(
		select	cast(1 as bigint) as StartPosition, isnull(cast(datalength(@Str)/2 as bigint), 0) TotalLength, 1 SeparatorLength, 
				cast(char(0x0d) as nvarchar(1)) Separator1, cast(char(0x0a) as nvarchar(1)) Separator2
	),
	x1 as
	(
		select	a1.Ordinal , a1.TotalLength, 
				case 
					when a1.NextSeparatorPosition1 > 0 and a1.NextSeparatorPosition2 = 0 then 1
					when a1.NextSeparatorPosition1 = 0 and a1.NextSeparatorPosition2 > 0 then 1
					when a1.NextSeparatorPosition1 > 0 and a1.NextSeparatorPosition2 > 0 then 
						case when abs(a1.NextSeparatorPosition1 - a1.NextSeparatorPosition2) = 1 then 2 else 1 end
					else 0
				end SeparatorLength, 
				a1.Separator1, a1.Separator2,
				a1.StartPosition,
				case 
					when a1.NextSeparatorPosition1 > 0 and a1.NextSeparatorPosition2 = 0 then a1.NextSeparatorPosition1
					when a1.NextSeparatorPosition1 = 0 and a1.NextSeparatorPosition2 > 0 then a1.NextSeparatorPosition2
					when a1.NextSeparatorPosition1 > 0 and a1.NextSeparatorPosition2 > 0 then 
						case when a1.NextSeparatorPosition1 > a1.NextSeparatorPosition2 then a1.NextSeparatorPosition2 else a1.NextSeparatorPosition1 end
					else 0
				end NextSeparatorPosition
		from (
				select	1 as Ordinal, x0.TotalLength, x0.SeparatorLength, Separator1, Separator2, x0.StartPosition, 
						charindex(Separator1, @Str, x0.StartPosition) NextSeparatorPosition1, 
						charindex(Separator2, @Str, x0.StartPosition) NextSeparatorPosition2
				from x0
				where TotalLength >0
			) a1
		union all
		select	a2. Ordinal, a2.TotalLength, 
				case 
					when a2.NextSeparatorPosition1 > 0 and a2.NextSeparatorPosition2 = 0 then 1
					when a2.NextSeparatorPosition1 = 0 and a2.NextSeparatorPosition2 > 0 then 1
					when a2.NextSeparatorPosition1 > 0 and a2.NextSeparatorPosition2 > 0 then 
						case when abs(a2.NextSeparatorPosition1 - a2.NextSeparatorPosition2) = 1 then 2 else 1 end						
					else 0
				end SeparatorLength, 
				a2.Separator1, a2.Separator2,
				a2.StartPosition StartPosition,
				case 
					when a2.NextSeparatorPosition1 > 0 and a2.NextSeparatorPosition2 = 0 then a2.NextSeparatorPosition1
					when a2.NextSeparatorPosition1 = 0 and a2.NextSeparatorPosition2 > 0 then a2.NextSeparatorPosition2
					when a2.NextSeparatorPosition1 > 0 and a2.NextSeparatorPosition2 > 0 then 
						case when a2.NextSeparatorPosition1 > a2.NextSeparatorPosition2 then a2.NextSeparatorPosition2 else a2.NextSeparatorPosition1 end
					else 0
				end NextSeparatorPosition
		from (
				select	x1.Ordinal + 1 Ordinal, x1.TotalLength, x1.SeparatorLength, x1.Separator1, x1.Separator2,
						x1.NextSeparatorPosition + x1.SeparatorLength StartPosition,
						charindex(x1.Separator1, @Str, x1.NextSeparatorPosition + x1.SeparatorLength) NextSeparatorPosition1,
						charindex(x1.Separator2, @Str, x1.NextSeparatorPosition + x1.SeparatorLength) NextSeparatorPosition2
				from x1
				where x1.NextSeparatorPosition > 0
			) a2
		
	)
	select Ordinal, case when NextSeparatorPosition > 0 then substring(@str, StartPosition, NextSeparatorPosition - StartPosition) else right(@Str, TotalLength - StartPosition + 1) end Value 
	from x1
)
