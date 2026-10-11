create or alter function z.fn_GetJobIDFromJobName(@JobName nvarchar(128))
returns uniqueidentifier
as
begin
    return cast(try_convert(binary(16), left(stuff(@JobName, 1, 29, ''), 34), 1) as uniqueidentifier)
end
go
---select maint.fn_GetJobIDFromJobName('SQLAgent - TSQL JobStep (Job 0x5F101A23612B1D4EAC0E10007682F003 : Step 2)')
--select * from msdb..sysjobs where job_id = '231A105F-2B61-4E1D-AC0E-10007682F003'