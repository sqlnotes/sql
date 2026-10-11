create or alter function z.fn_GetZSequenceID(@SeqGeneralID bigint)
returns bigint
as
begin
	return datediff_big(second, '1900-01-01', getutcdate()) * 268435456 | @SeqGeneralID
end
