create or alter function z.fn_SplitStringFixedLength
(
	@Str nvarchar(max),
	@Length int
)
returns table
as return
(
	with x0	as
	(
		select cast(1 as bigint) as StartPosition, cast(datalength(@Str)/2 as bigint) TotalLength
		where isnull(@Length, 0) > 0
	),
	x1 as
	(
		select	1 as Ordinal, x0.TotalLength, x0.StartPosition, 
				case when x0.StartPosition + @Length <= x0.TotalLength then @Length else x0.TotalLength - x0.StartPosition end Length
		from x0
		where TotalLength > 0
		union all
		select	x1.Ordinal + 1 Ordinal, x1.TotalLength, x1.StartPosition + x1.Length StartPosition,
				case when x1.StartPosition + @Length <= x1.TotalLength then @Length else x1.TotalLength - x1.StartPosition end Length
		from x1
		where x1.TotalLength >= x1.StartPosition + @Length
	)
	select x1.Ordinal, substring(@Str, x1.StartPosition, x1.Length) Value
	from x1
)
