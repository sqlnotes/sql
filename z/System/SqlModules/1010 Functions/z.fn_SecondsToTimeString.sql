create or alter function z.fn_SecondsToTimeString(@Seconds bigint)
returns varchar(30)
as
begin
	return  (
				select 
						iif(Seconds >= 86400, cast(Seconds / 86400 as varchar(30)) + '.' , '') + -- Day
						iif(Seconds >= 3600, format(Seconds % 86400 / 3600, '00') + ':', '') + -- Hour
						format((Seconds % 3600) / 60, '00') + ':' + -- minutes
						format(Seconds % 60, '00') -- second
				from (select abs(@Seconds) Seconds) s
			)
end
go