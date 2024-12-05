create or alter function z.fn_PreviousCommittedRowVersion()
returns binary(8)
as
begin 
	/*
		This function calculates the row version just before the current minimum active row version 
		('min_active_rowversion()'). This is useful in scenarios where the exact boundary of committed 
		data needs to be identified for ETL.

		Explanation:
		- The min_active_rowversion() function returns an unsigned 8-byte binary value 
		  representing the minimum active transaction row version.
		- To compute the previous version, we cannot directly cast it to a bigint and subtract 1 
		  because of a special case:
		  - When min_active_rowversion() is 0x8000000000000000, its bigint representation is 
			-9223372036854775808 (the minimum value for a bigint).
		  - Subtracting 1 from this value causes an overflow.
		- Instead:
		  - For the special case (0x8000000000000000), the result should be 0x7FFFFFFFFFFFFFFF 
			(9223372036854775807 in bigint).
		  - For all other cases, simply subtract 1 from the bigint representation of the row version.
    
		Return Value:
		A binary(8) value representing the previous row version
	*/
	declare @MinActiveRowVersion binary(8) = min_active_rowversion()
	return cast(case when @MinActiveRowVersion = 0x8000000000000000 then 0x7FFFFFFFFFFFFFFF else cast(@MinActiveRowVersion as bigint) - 1 end as binary(8))
end


    
