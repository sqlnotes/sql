/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueExecuteBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#execute-a-batch-with-agent-workers

Runs a Draft or Ready batch using temporary unscheduled Agent jobs and finalizes its status after they exit.
*/
create or alter procedure z.usp_TaskQueueExecuteBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	if z.fn_IsSQLAgentRunning() <> 1
		throw 50000, 'SQL Server Agent is not running or is not visible to this caller.', 1;
	if @@trancount <> 0 or @@options & 2 = 2
		throw 50000, 'Batch execution requires no transaction and implicit transactions off.', 1;
	declare	@MaxConcurrentWorkers int, @WorkerNumber int = 1, @ExecutionID uniqueidentifier,
			@WorkerNamePrefix nvarchar(255), @Name nvarchar(255), @Command nvarchar(max), @JobID uniqueidentifier,
			@Now datetime2(7), @LaunchStartedAtUTC datetime2(7), @StartErrorDetails nvarchar(max);
	declare @Jobs table (WorkerNumber int primary key, Name nvarchar(255), JobID uniqueidentifier not null);
	exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName output;
	begin try
		begin tran;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		select	@MaxConcurrentWorkers = MaxConcurrentWorkers, @ExecutionID = ExecutionID,
				@LaunchStartedAtUTC = StartedAtUTC
		from z.TaskQueueBatch
		where BatchID = @BatchID and Status in ('Draft', 'Ready') and MaxConcurrentWorkers > 0;
		if @@rowcount = 0
			throw 50000, 'Only a Draft or Ready batch with a positive worker limit can be executed.', 1;
		select	@Command = N'exec z.usp_TaskQueueExecuteBatchWorker @BatchID = ' + convert(nvarchar(20), @BatchID) + N';',
				@WorkerNamePrefix = N'TaskQueue-' + convert(nvarchar(20), @BatchID) + N'-' + convert(nvarchar(36), @ExecutionID) + N'-';
		if len(N'z_' + quotename(db_name(), '(') + N'_' + @WorkerNamePrefix + convert(nvarchar(11), @MaxConcurrentWorkers)) > 128
			throw 50000, 'The coordination database name is too long for unique worker job names.', 1;
		while @WorkerNumber <= @MaxConcurrentWorkers
		begin
			select	@Name = @WorkerNamePrefix + convert(nvarchar(11), @WorkerNumber);
			select	@JobID = z.fn_GetServiceJobID(@Name);
			if @JobID is null
			begin
				exec z.usp_CreateServiceJob @Name = @Name, @Command = @Command, @CreateSchedule = 0, @DeleteAfterExecution = 3, @SetJobOwnerToSA = 0, @JobID = @JobID output;
			end;
			insert @Jobs (WorkerNumber, Name, JobID) values (@WorkerNumber, @Name, @JobID);
			select	@WorkerNumber += 1;
		end;
		select	@Now = sysutcdatetime();
		-- The gate makes this stamp distinct even when Resume retains the execution ID.
		select	@LaunchStartedAtUTC = case when @LaunchStartedAtUTC is null or @LaunchStartedAtUTC < @Now then @Now
				else dateadd(nanosecond, 100, @LaunchStartedAtUTC) end;
		exec z.usp_TaskQueueSetAction @Action = N'Start';
		update z.TaskQueueBatch
			set Status = 'Running', StartedAtUTC = @LaunchStartedAtUTC, FinishedAtUTC = null, LastErrorMessage = null
		where BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction;
		commit;
		select	@WorkerNumber = 1;
		while @WorkerNumber <= @MaxConcurrentWorkers
		begin
			select	@JobID = JobID, @Name = Name from @Jobs where WorkerNumber = @WorkerNumber;
			if z.fn_IsSQLJobRunning(@JobID) = 0
			begin
				begin try
					exec z.usp_StartServiceJob @Name = @Name;
				end try
				begin catch
					select	@StartErrorDetails = (
								select	@BatchName BatchName, @LaunchStartedAtUTC StartedAtUTC, @WorkerNumber WorkerNumber,
										z.fn_GetServiceJobName(@Name) JobName, @JobID JobID,
										error_number() ErrorNumber, error_severity() ErrorSeverity, error_state() ErrorState,
										error_procedure() ErrorProcedure, error_line() ErrorLine, error_message() ErrorMessage
								for json path, include_null_values, without_array_wrapper
							);
					begin try
						insert z.TaskQueueLog (BatchID, ExecutionID, ActionID, Action, ChangeType,
							LoginName, ApplicationName, HostName, SessionID, AfterJson)
						values (@BatchID, @ExecutionID, newid(), N'WorkerJobStartError', 'Insert',
							original_login(), app_name(), host_name(), @@spid, @StartErrorDetails);
					end try
					begin catch
						print concat(N'Could not log worker job start error for TaskQueue batch ', @BatchID,
							N', execution ', @ExecutionID, N'. ', error_message());
						print @StartErrorDetails;
					end catch;
				end catch;
			end;
			select	@WorkerNumber += 1;
		end;
		while exists(	select *
						from @Jobs j
							inner join msdb.dbo.sysjobs b on b.job_id = j.JobID
					)
		begin
			waitfor delay '00:00:01';
		end;
		begin tran;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction @Action = N'Reconcile';
		update z.TaskQueueBatch set Status = 'Completed', FinishedAtUTC = sysutcdatetime()
		where BatchID = @BatchID and Status = 'Running'
			and ExecutionID = @ExecutionID and StartedAtUTC = @LaunchStartedAtUTC;
		exec z.usp_TaskQueueSetAction;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
