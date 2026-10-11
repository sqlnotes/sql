create or alter function z.fn_SQLAgentScheduleTimeToTime(@Time as int)
returns time(0)
as
begin
	return (
				select left(t.i, 2) + ':' + substring(t.i, 3, 2) + ':' + right(t.i, 2)
				from (select right('000000' + cast(@Time as varchar(100)), 6) i ) t
			)
			
end