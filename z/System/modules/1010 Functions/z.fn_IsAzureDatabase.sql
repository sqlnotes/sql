create or alter function z.fn_IsAzureDatabase()
returns bit
as
begin
	if @@version like '%Microsoft SQL Azure%'
		return 0
	return 0
end