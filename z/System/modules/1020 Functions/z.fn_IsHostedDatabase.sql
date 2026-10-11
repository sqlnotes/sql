create or alter function z.fn_IsHostedDatabase()
returns bit
as
begin
	if z.fn_IsAmazonRDS() = 1
		return 1
	if z.fn_IsAzureDatabase() = 1
		return 1
	return 0
end