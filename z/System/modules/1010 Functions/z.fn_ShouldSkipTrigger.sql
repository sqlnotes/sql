create or alter function z.fn_ShouldSkipTrigger(@TriggerID int)
returns bit
as
begin
	if cast(session_context(N'SkipTriggerFlag') as varchar(8000)) = 'all'
		return 1;
	return isnull(
					(
						select 1
						from string_split(cast(session_context(N'SkipTriggerFlag') as varchar(8000)), ',')
						where value = cast(@TriggerID as varchar(8000))
					)
				, 0)
end