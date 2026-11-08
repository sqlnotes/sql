/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1020%20Views/z.v_BackupRestoreRequests.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/backup-restore-history.md#zv_backuprestorerequests

Reports currently executing backup and restore requests and their native progress.
ExecutionDatabaseName is the request context, which can differ from the restore target.
*/
create or alter view z.v_BackupRestoreRequests
as
select r.command Command,
	r.status Status,
	db_name(r.database_id) ExecutionDatabaseName,
	r.percent_complete PercentComplete,
	r.start_time StartTime,
	r.total_elapsed_time ElapsedTimeMs,
	z.fn_FormatDurationMilliseconds(r.total_elapsed_time) ElapsedDuration,
	r.estimated_completion_time EstimatedCompletionTimeMs,
	z.fn_FormatDurationMilliseconds(r.estimated_completion_time) EstimatedRemainingDuration,
	r.wait_type WaitType,
	r.wait_time WaitTimeMs,
	z.fn_FormatDurationMilliseconds(r.wait_time) WaitDuration,
	r.wait_resource WaitResource,
	r.cpu_time CpuTimeMs,
	z.fn_FormatDurationMilliseconds(r.cpu_time) CpuDuration,
	r.reads Reads,
	r.writes Writes,
	r.logical_reads LogicalReads,
	substring(t.text, r.statement_start_offset / 2 + 1,
		(case when r.statement_end_offset = -1 then datalength(t.text) else r.statement_end_offset end
			- r.statement_start_offset) / 2 + 1) StatementText,
	s.host_name HostName,
	s.program_name ProgramName,
	s.login_name LoginName,
	r.session_id SessionID,
	r.request_id RequestID,
	r.database_id ExecutionDatabaseID,
	r.blocking_session_id BlockingSessionID
from sys.dm_exec_requests r
	left join sys.dm_exec_sessions s on s.session_id = r.session_id
	outer apply sys.dm_exec_sql_text(r.sql_handle) t
where r.command like N'BACKUP%' or r.command like N'RESTORE%';
