create or alter function z.fn_IsAmazonRDS()
returns bit
as
begin
	if @@servername like 'EC2AMAZ%%' and object_id('rdsadmin.dbo.rds_configuration') is not null
		return 1
	return 0
end
go
