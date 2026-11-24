create or alter function z.fn_IsSyncInitialization()
returns bit
as
begin
	return isnull(cast(session_context(N'IsSyncInitialization') as int), 0)
end

go
