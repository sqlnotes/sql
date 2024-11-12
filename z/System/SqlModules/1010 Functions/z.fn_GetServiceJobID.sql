create or alter function z.fn_GetServiceJobID(@Name nvarchar(255))
returns uniqueidentifier
as
begin
	return (select job_id from msdb.dbo.sysjobs where name = z.fn_GetServiceJobName(@Name)) 
end