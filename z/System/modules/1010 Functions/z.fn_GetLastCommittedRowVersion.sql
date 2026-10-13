create or alter function z.fn_GetLastCommittedRowVersion()
returns binary(8)
as
begin 
	/*
		Returns an inclusive polling watermark: one less than the lowest active
		rowversion in the current database. Capture it before reading changes and
		use RowVersion > @PreviousWatermark and RowVersion <= @Watermark.

		With no active rowversions, min_active_rowversion() returns @@dbts + 1,
		so this function returns @@dbts. With active rowversions, later committed
		values can lie above the watermark and are deferred to a subsequent poll.
		The watermark need not belong to an existing or committed row: rolled-back
		changes also consume rowversions. It does not determine snapshot visibility.

		Treat the eight bytes as an unsigned counter. Casting to bigint preserves
		the bits but interprets the high bit as a sign. Subtraction still yields the
		correct predecessor except at 0x8000000000000000 (bigint minimum), where
		subtracting one would overflow; return 0x7FFFFFFFFFFFFFFF instead.
		This assumes a nonzero counter; zero has no unsigned predecessor.
	*/
	declare @MinActiveRowVersion binary(8) = min_active_rowversion()
	return cast(case when @MinActiveRowVersion = 0x8000000000000000 then 0x7FFFFFFFFFFFFFFF else cast(@MinActiveRowVersion as bigint) - 1 end as binary(8))
end
