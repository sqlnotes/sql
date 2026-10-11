create or alter function z.fn_IsLinux() 
returns bit 
as 
begin 
	return case when @@version like '%linux%' then 1 else 0 end
end