/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/modules/1070%20Procedures/z.usp_GetJobStatus.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Jobs/docs/reference/z.usp_GetJobStatus.md

Returns native SQL Agent job summaries, including execution status, for one job or all visible jobs.
*/
create or alter procedure z.usp_GetJobStatus
(
	@JobID uniqueidentifier = null,
	@JobName sysname = null
)
as
begin
	set nocount on;
	declare	@ReturnCode int,
			@JobAspect varchar(9) = case when @JobID is null and nullif(trim(@JobName), N'') is null then null else 'JOB' end;
	exec @ReturnCode = msdb.dbo.sp_help_job @job_id = @JobID, @job_name = @JobName, @job_aspect = @JobAspect;
	return @ReturnCode;
end;
