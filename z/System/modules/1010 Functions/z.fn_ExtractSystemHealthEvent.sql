create or alter function z.fn_ExtractSystemHealthEvent()
returns @ret table(Date datetime, EventName varchar(128), EventBody xml, DateUTC datetime)
as
begin
	declare @x xml
	if object_id('sys.dm_xe_sessions') is not null
	begin
		select @x = cast(t.target_data as xml) 
		from sys.dm_xe_sessions s
			inner join sys.dm_xe_session_targets t on s.address = t.event_session_address
		where s.name = 'system_health'
			and t.target_name = 'ring_buffer'
		if @@rowcount = 0
			return
	end
	insert into @ret(Date, EventName, EventBody, DateUTC)
		select Date, EventName, EventBody, DateUTC
		from (
				select Date, EventName, EventBody, DateUTC, row_number() over(partition by Date order by Date)  rn
				from (
						select	
								convert(datetime, switchoffset(convert(datetimeoffset, d.value('@timestamp', 'datetime')), datename(tzoffset, sysdatetimeoffset()))) Date,
								d.value('@name', 'nvarchar(128)') EventName,
								isnull(d.query('.'), '') EventBody,
								d.value('@timestamp', 'datetime') DateUTC
						from @x.nodes('RingBufferTarget/event') n(d)
					)x1
			) x2
	return
end
go