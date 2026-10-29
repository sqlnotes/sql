create or alter function z.fn_ExtractSystemHealthEvent
(
	@TargetData xml
)
returns table
as
return
(
	with x as
	(
		select convert(datetime, switchoffset(try_convert(datetimeoffset(7), d.value('@timestamp', 'nvarchar(50)'), 127), '+00:00')) EventDateUTC,
			d.value('@name', 'nvarchar(128)') EventName,
			d.query('.') EventBody
		from @TargetData.nodes('RingBufferTarget/event') n(d)
	)
	select x.EventDateUTC, x.EventName,
		cast(hashbytes('MD5', cast(x.EventBody as varbinary(max))) as uniqueidentifier) EventHash, x.EventBody
	from x
)
