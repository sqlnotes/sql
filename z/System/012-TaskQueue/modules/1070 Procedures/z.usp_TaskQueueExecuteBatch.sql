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
	if @@trancount <> 0
		or @@options & 2 = 2
		throw 50000, 'Batch execution requires no transaction and implicit transactions off.', 1;
	declare	@MaxConcurrentWorkers int, @WorkerNumber int = 1, @ExecutionID uniqueidentifier,
			@WorkerNamePrefix nvarchar(255), @Name nvarchar(255), @Command nvarchar(max), @JobID uniqueidentifier,
			@LaunchStartedAtUTC datetime2(7), @NextStartAttemptAtUTC datetime2(7),
			@StartAttempts tinyint, @Started bit, @AnyWorkerStarted bit = 0,
			@RemoveReturnCode int, @JobAction nvarchar(64), @JobDetails nvarchar(max), @LaunchError nvarchar(2048);
	declare @Jobs table
	(
		WorkerNumber int primary key,
		JobID uniqueidentifier not null,
		ServiceName sysname not null,
		StartAttempts tinyint not null default (0),
		NextStartAttemptAtUTC datetime2(7),
		Started bit not null default (0)
	);
	exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName output;
	begin try
		begin tran;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		select	@MaxConcurrentWorkers = MaxConcurrentWorkers, @ExecutionID = ExecutionID,
				@LaunchStartedAtUTC = sysutcdatetime()
		from z.TaskQueueBatch
		where BatchID = @BatchID
			and Status in ('Draft', 'Ready')
			and MaxConcurrentWorkers > 0;
		if @@rowcount = 0
			throw 50000, 'Only a Draft or Ready batch with a positive worker limit can be executed or the batch has already been started by the other session.', 1;
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
				exec z.usp_CreateServiceJob @Name = @Name, @Command = @Command,
					@CreateSchedule = 0, @DeleteAfterExecution = 3, @SetJobOwnerToSA = 0, @JobID = @JobID output;
			end;
			insert @Jobs (WorkerNumber, JobID, ServiceName, StartAttempts, NextStartAttemptAtUTC)
				values (@WorkerNumber, @JobID, @Name, 0, sysutcdatetime());
			select	@WorkerNumber += 1;
		end;

		exec z.usp_TaskQueueSetAction @Action = N'Start';
		update z.TaskQueueBatch
			set Status = 'Running', StartedAtUTC = @LaunchStartedAtUTC, FinishedAtUTC = null, LastErrorMessage = null
		where BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction;
		commit;

		waitfor delay '00:00:00.005';

		select	@WorkerNumber = 0;
		while exists (select * from @Jobs)
		begin
			select	top (1)
					@WorkerNumber = WorkerNumber, @JobID = JobID, @Name = ServiceName, @Started = Started,
					@StartAttempts = StartAttempts, @NextStartAttemptAtUTC = NextStartAttemptAtUTC,
					@JobAction = null
			from @Jobs
			where WorkerNumber > @WorkerNumber
			order by WorkerNumber;
			if @@rowcount = 0
			begin
				select	@WorkerNumber = 0;
				waitfor delay '00:00:01';
				continue;
			end;
			if not exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID)
			begin
				select	@AnyWorkerStarted = 1;
				delete @Jobs where WorkerNumber = @WorkerNumber;
				continue;
			end;
			if @Started = 1
				continue;
			if z.fn_IsSQLJobRunning(@JobID) = 1
			begin
				update @Jobs
					set Started = 1, @AnyWorkerStarted = 1
				where WorkerNumber = @WorkerNumber;
				continue;
			end;
			if @NextStartAttemptAtUTC > sysutcdatetime()
				continue;
			begin try
				if @StartAttempts < 3
				begin
					select	@JobAction = N'WorkerJobStartError', @StartAttempts += 1;
					exec msdb.dbo.sp_start_job @job_id = @JobID;
					select	@JobAction = null;
				end
				else
				begin
					select	@JobAction = N'WorkerJobRemoveError';
					delete @Jobs where WorkerNumber = @WorkerNumber;
					exec @RemoveReturnCode = msdb.dbo.sp_delete_job @job_id = @JobID,
						@delete_unused_schedule = 1, @delete_history = 1;
					if @RemoveReturnCode <> 0
						throw 50000, 'SQL Agent rejected the removal of the idle worker job.', 1;
					select	@JobAction = N'WorkerJobRemoved',
							@JobDetails = (
								select	@BatchName BatchName, @LaunchStartedAtUTC StartedAtUTC, @WorkerNumber WorkerNumber,
										@Name JobName, @JobID JobID, @StartAttempts StartAttempts
								for json path, without_array_wrapper
							);
				end;
			end try
			begin catch
				if @@trancount > 0
					rollback;
				if not exists (select 1 from msdb.dbo.sysjobs where job_id = @JobID)
				begin
					select	@AnyWorkerStarted = 1;
					continue;
				end
				select	@JobDetails = (
							select	@BatchName BatchName, @LaunchStartedAtUTC StartedAtUTC, @WorkerNumber WorkerNumber,
									@Name JobName, @JobID JobID, @StartAttempts StartAttempts,
									z.fn_GetFullErrorMessage() ErrorMessage
							for json path, include_null_values, without_array_wrapper
						);
			end catch;
			update @Jobs
				set StartAttempts = @StartAttempts, NextStartAttemptAtUTC = dateadd(second, 10, sysutcdatetime())
			where WorkerNumber = @WorkerNumber;

			if @JobAction is null
				continue;

			begin try
				insert z.TaskQueueLog (
					BatchID, ExecutionID, ActionID, Action, ChangeType,
					LoginName, ApplicationName, HostName, SessionID, AfterJson
				)
				values (
					@BatchID, @ExecutionID, newid(), @JobAction, 'Insert',
					original_login(), app_name(), host_name(), @@spid, @JobDetails
				);
			end try
			begin catch
				print concat(N'Could not log ', @JobAction, N' for TaskQueue batch ', @BatchID, N', execution ', @ExecutionID, N'. ', z.fn_GetFullErrorMessage());
				print @JobDetails;
			end catch;
		end;
		if @AnyWorkerStarted = 0
			select	@LaunchError = concat(N'No SQL Agent worker jobs started for TaskQueue batch ', @BatchID, N'.');

		begin tran;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction @Action = N'Reconcile';
		update z.TaskQueueBatch
			set Status = 'Completed', FinishedAtUTC = sysutcdatetime(), LastErrorMessage = isnull(@LaunchError, LastErrorMessage)
		where BatchID = @BatchID
			and Status = 'Running'
			and ExecutionID = @ExecutionID
			and StartedAtUTC = @LaunchStartedAtUTC;
		if @@rowcount = 0
			select	@LaunchError = null;
		exec z.usp_TaskQueueSetAction;
		commit;
	end try
	begin catch
		if @@trancount > 0
			rollback;
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;

	if @LaunchError is null
		return;

	begin try
		select	@JobDetails = (
					select	@BatchName BatchName, @LaunchStartedAtUTC StartedAtUTC, @LaunchError ErrorMessage
					for json path, without_array_wrapper
				);
		insert z.TaskQueueLog (
			BatchID, ExecutionID, ActionID, Action, ChangeType,
			LoginName, ApplicationName, HostName, SessionID, AfterJson
		)
		values (
			@BatchID, @ExecutionID, newid(), N'WorkerLaunchError', 'Insert',
			original_login(), app_name(), host_name(), @@spid, @JobDetails
		);
	end try
	begin catch
		print concat(N'Could not log WorkerLaunchError for TaskQueue batch ', @BatchID, N', execution ', @ExecutionID, N'. ', z.fn_GetFullErrorMessage());
	end catch;
	throw 50000, @LaunchError, 1;
end;
