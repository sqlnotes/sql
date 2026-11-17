/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueExecuteBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#execute-a-batch-with-agent-workers

Runs a Draft batch using temporary unscheduled Agent jobs and waits for their completion.
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
			@Name nvarchar(255), @Command nvarchar(max), @JobID uniqueidentifier,
			@Status varchar(16), @Error nvarchar(4000);
	declare @Jobs table (WorkerNumber int primary key, Name nvarchar(255), JobID uniqueidentifier not null);
	exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName;
	begin try
		begin tran;
		exec z.usp_TaskQueueStartBatch @BatchID = @BatchID, @MaxConcurrentWorkers = @MaxConcurrentWorkers output, @RequireWorkerLimit = 1, @ExecutionID = @ExecutionID output;
		select	@Command = N'exec z.usp_TaskQueueRunWorker @BatchID = ' + convert(nvarchar(20), @BatchID) + N';';
		while @WorkerNumber <= @MaxConcurrentWorkers
		begin
			select	@Name = N'TaskQueue-' + convert(nvarchar(20), @BatchID) + N'-' + convert(nvarchar(36), @ExecutionID) + N'-' + convert(nvarchar(11), @WorkerNumber);
			if len(N'z_' + quotename(db_name(), '(') + N'_' + @Name) > 128
				throw 50000, 'The coordination database name is too long for unique worker job names.', 1;
			select	@JobID = z.fn_GetServiceJobID(@Name);
			if @JobID is null
			begin
				exec z.usp_CreateServiceJob @Name = @Name, @Command = @Command, @CreateSchedule = 0, @DeleteAfterExecution = 3, @SetJobOwnerToSA = 0, @JobID = @JobID output;
			end;
			insert @Jobs (WorkerNumber, Name, JobID) values (@WorkerNumber, @Name, @JobID);
			select	@WorkerNumber += 1;
		end;
		update z.TaskQueueBatch
			set Status = 'Running', StartedAtUTC = getutcdate()
		where BatchID = @BatchID;
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
					-- Another caller may have started the job after the session check.
				end catch;
			end;
			select	@WorkerNumber += 1;
		end;
		while exists
		(
			select	1 from @Jobs j
				inner join msdb.dbo.sysjobs b on b.job_id = j.JobID
		)
		begin
			waitfor delay '00:00:01';
		end;
		begin tran;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and ExecutionID = @ExecutionID)
			throw 50000, 'The batch execution changed before finalization.', 1;
		select	@Status = Status, @Error = LastErrorMessage from z.TaskQueueBatch where BatchID = @BatchID;
		if @Status = 'Ready'
			throw 50000, 'The batch was resumed before finalization.', 1;
		select	top (1) @Error = LastErrorMessage from z.TaskQueueTasks
		where BatchID = @BatchID and Status in ('Failed', 'NeedsReview') and LastErrorMessage is not null
		order by TaskID desc;
		if @Status = 'Running'
		begin
			select	@Status = case when exists (select 1 from z.TaskQueueTasks where BatchID = @BatchID and CompletionState < 2)
					then 'Stopped' else 'Completed' end;
			if @Status = 'Stopped'
				select	@Error = isnull(@Error, N'The batch has unresolved task completion conditions; inspect its retained task results.');
			exec z.usp_TaskQueueSetAction @Action = N'Reconcile';
			update z.TaskQueueBatch
				set Status = @Status, LastErrorMessage = @Error,
					FinishedAtUTC = case when @Status = 'Completed' then sysutcdatetime() end
			where BatchID = @BatchID and Status = 'Running';
			exec z.usp_TaskQueueSetAction;
		end;
		if @Status = 'Stopped'
			select	@Error = isnull(@Error, N'The batch was stopped before execution completed.');
		commit;
		if @Error is not null
			throw 50000, @Error, 1;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
