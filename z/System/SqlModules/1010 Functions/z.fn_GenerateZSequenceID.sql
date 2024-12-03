create or alter function z.fn_GenerateZSequenceID(@Date datetime, @SeqGeneralID bigint)
returns bigint
as
begin
	return datediff_big(second, '1900-01-01', @Date) * 268435456 | @SeqGeneralID
end
