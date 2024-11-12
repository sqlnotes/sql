create or alter function z.fn_IsSQLAgentRunning()
returns bit
as
begin
	return case when not exists(select * from sys.dm_exec_sessions where program_name like '%SQLAgent%') then 0 else 1 end
end