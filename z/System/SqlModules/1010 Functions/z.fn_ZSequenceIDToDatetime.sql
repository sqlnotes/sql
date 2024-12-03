create or alter function z.fn_ZSequenceIDToDatetime(@SequenceID bigint)
returns datetime
as
begin
	return (
			select Date
			from (
					select dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01')) Date
					from (select @SequenceID/268435456 as seconds) x0
				) x1
			)
end





