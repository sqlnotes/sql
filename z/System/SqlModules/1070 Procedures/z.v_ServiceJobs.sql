create or alter view z.v_ServiceJobs
as
with x0 as
(
	select 'z_' + quotename(db_name(), '(') + '_' Padding, len('z_' + quotename(db_name(), '(') + '_') PaddingLength
)
select 
		j.job_id JobID, j.name JobName, j.description Description, j.enabled IsActive,
		case when exists(select * from sys.dm_exec_sessions s where s.program_name like 'SQLAgent%' + convert(varchar(100), convert(binary(16), j.job_id), 1) +'%') then 1 else 0 end IsExecuting,
		case when left(j.name, x0.PaddingLength) = x0.Padding then 1 else 0 end IszServiceJob,
		case when left(j.name, x0.PaddingLength) = x0.Padding then 
					stuff(j.name, 1, x0.PaddingLength, '') 
		end ServiceName
from msdb.dbo.sysjobs j
	cross join x0