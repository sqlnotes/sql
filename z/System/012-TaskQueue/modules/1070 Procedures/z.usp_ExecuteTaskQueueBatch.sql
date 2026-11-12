/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_ExecuteTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#execute-a-batch-with-agent-workers

Runs a Draft batch using temporary unscheduled Agent jobs and waits for their completion.
*/
create or alter procedure z.usp_ExecuteTaskQueueBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount, xact_abort on;
	if @@trancount <> 0 or @@options & 2 = 2
		throw 50000, 'Batch execution requires no transaction and implicit transactions off.', 1;
	declare @Limit int, @Count int, @Worker int = 1, @ExecutionID uniqueidentifier,
		@Name nvarchar(255), @Command nvarchar(max), @JobID uniqueidentifier,
		@Status varchar(16), @Error nvarchar(2048), @Semaphore nvarchar(200), @Slot int,
		@GateHeld bit = 0, @Started bit = 0, @Now datetime2(7), @AgentSessionID int, @CleanupError nvarchar(2048), @BatchSemaphore nvarchar(200);
	declare @Jobs table (WorkerNumber int primary key, Name nvarchar(255), JobID uniqueidentifier, RequestedAt datetime2(7));
	exec z.usp_ResolveTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName;
	select @Semaphore = N'z.TaskQueue.Launch:' + convert(nvarchar(20), @BatchID);
	begin try
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @Semaphore, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
		if @Slot <= 0 throw 50000, 'This batch already has an execution launcher.', 1;
		select @GateHeld = 1, @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		begin tran;
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		if @Slot <= 0 throw 50000, 'Cannot acquire the batch definition gate.', 1;
		select @Limit = MaxConcurrentWorkers, @ExecutionID = ExecutionID, @Status = Status from z.TaskQueueBatch where BatchID = @BatchID;
		if @Status is null or @Status <> 'Draft' or @Limit <= 0
			throw 50000, 'Execution requires a Draft batch with a positive MaxConcurrentWorkers.', 1;
		exec z.usp_ValidateTaskQueueBatch @BatchID = @BatchID, @RequireIdle = 1;
		select @Count = count(*) from z.TaskQueueTasks where BatchID = @BatchID;
		select @Limit = iif(@Count < @Limit, @Count, @Limit);
		if @Limit > 0 and z.fn_IsSQLAgentRunning() <> 1
			throw 50000, 'SQL Server Agent is not running or is not visible to this caller.', 1;
		select @Command = N'while exists (select 1 from z.TaskQueueBatch where BatchID = '
			+ convert(nvarchar(20), @BatchID) + N' and Status in (''Ready'', ''Running''))
 begin
 exec z.usp_RunTaskQueueWorker @BatchID = ' + convert(nvarchar(20), @BatchID) + N';
 if exists (select 1 from z.TaskQueueBatch where BatchID = ' + convert(nvarchar(20), @BatchID)
			+ N' and Status in (''Ready'', ''Running'')) waitfor delay ''00:00:01'';
 end;';
		while @Worker <= @Limit
		begin
			select @Name = N'TQ_' + replace(convert(nvarchar(36), @ExecutionID), N'-', N'') + N'_' + convert(nvarchar(11), @Worker);
			if len(N'z_' + quotename(db_name(), '(') + N'_' + @Name) > 128
				throw 50000, 'The coordination database name is too long for unique worker job names.', 1;
			if z.fn_GetServiceJobID(@Name) is not null
				throw 50000, 'A worker job name is already in use.', 1;
			exec z.usp_CreateServiceJob @Name = @Name, @Command = @Command, @CreateSchedule = 0, @DeleteAfterExecution = 3, @SetJobOwnerToSA = 0;
			select @JobID = z.fn_GetServiceJobID(@Name);
			if @JobID is null throw 50000, 'The worker job was not created.', 1;
			insert @Jobs (WorkerNumber, Name, JobID) values (@Worker, @Name, @JobID);
			select @Worker += 1;
		end;
		exec z.usp_StartTaskQueueBatch @BatchID = @BatchID;
		commit;
		select @Started = 1, @Worker = 1;
		if @Limit = 0 exec z.usp_RunTaskQueueWorker @BatchID = @BatchID;
		while @Worker <= @Limit
		begin
			select @Name = Name from @Jobs where WorkerNumber = @Worker;
			update @Jobs set RequestedAt = sysdatetime() where WorkerNumber = @Worker;
			exec z.usp_StartServiceJob @Name = @Name;
			select @Worker += 1;
		end;
		while 1 = 1
		begin
			select @Status = null;
			select @Status = Status from z.TaskQueueBatch where BatchID = @BatchID;
			select @Now = sysdatetime(), @AgentSessionID = max(session_id) from msdb.dbo.syssessions;
			if @Status in ('Ready', 'Running') and exists
			(
				select 1 from @Jobs j
					left join msdb.dbo.sysjobs b on b.job_id = j.JobID
					left join msdb.dbo.sysjobactivity a on a.job_id = j.JobID and a.session_id = @AgentSessionID
				where b.job_id is null or a.stop_execution_date is not null
					or (a.start_execution_date is null and datediff(second, j.RequestedAt, @Now) >= 60)
			)
			begin
				-- Completion may commit between the status read and Agent metadata reads.
				select @Status = null;
				select @Status = Status from z.TaskQueueBatch where BatchID = @BatchID;
				if @Status in ('Ready', 'Running')
					throw 50000, 'A worker did not start within 60 seconds or exited before the batch finished.', 1;
			end;
			if @Status in ('Ready', 'Running') and z.fn_IsSQLAgentRunning() <> 1
				throw 50000, 'SQL Server Agent stopped while the batch was executing.', 1;
			if @Status in ('Completed', 'Stopped') and not exists
			(
				select 1 from @Jobs j join msdb.dbo.sysjobs b on b.job_id = j.JobID
					left join msdb.dbo.sysjobactivity a on a.job_id = j.JobID and a.session_id = @AgentSessionID
				where a.stop_execution_date is null
					and (a.start_execution_date is not null or datediff(second, j.RequestedAt, @Now) < 60)
			) break;
			if z.fn_IsSQLAgentRunning() <> 1 and @Limit > 0
				throw 50000, 'SQL Server Agent stopped before worker cleanup finished.', 1;
			if @Status is null throw 50000, 'The executing batch was removed.', 1;
			waitfor delay '00:00:01';
		end;
		select @Worker = 1;
		while @Worker <= @Limit
		begin
			select @Name = Name, @JobID = JobID from @Jobs where WorkerNumber = @Worker;
			if z.fn_GetServiceJobID(@Name) = @JobID exec z.usp_RemoveServiceJob @Name = @Name;
			select @Worker += 1;
		end;
		exec z.usp_ReleaseSemaphore @SemaphoreName = @Semaphore, @LockOwner = 'Session';
		select @GateHeld = 0;
		select @BatchID BatchID, count_big(*) TotalTasks,
			count_big(case when Status = 'Succeeded' then 1 end) SucceededTasks,
			count_big(case when Status = 'Failed' then 1 end) FailedTasks
		from z.TaskQueueTasks where BatchID = @BatchID;
		if @Status <> 'Completed' or exists (select 1 from z.TaskQueueTasks where BatchID = @BatchID and Status <> 'Succeeded')
		begin
			select @Error = N'TaskQueue batch ' + convert(nvarchar(20), @BatchID) + N' did not succeed for every task. Inspect its retained task results.';
			throw 50000, @Error, 1;
		end;
	end try
	begin catch
		select @Error = error_message();
		if @@trancount > 0 rollback;
		if @GateHeld = 1
		begin
			begin try
				-- Stop dispatch before draining; never cancel an active backup.
				if @Started = 1 and exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status in ('Ready', 'Running'))
					exec z.usp_StopTaskQueueBatch @BatchID = @BatchID;
				while z.fn_IsSQLAgentRunning() = 1 and exists
				(
					select 1 from @Jobs j join msdb.dbo.sysjobactivity a on a.job_id = j.JobID
					where a.session_id = (select max(session_id) from msdb.dbo.syssessions)
						and a.run_requested_date is not null and a.stop_execution_date is null
						and (a.start_execution_date is not null or datediff(second, j.RequestedAt, sysdatetime()) < 60)
				)
					waitfor delay '00:00:01';
				if @Started = 1
				begin
					-- Recovery tests task semaphores; stale Agent activity is not execution ownership.
					while 1 = 1
					begin
						exec z.usp_RunTaskQueueWorker @BatchID = @BatchID;
						if not exists (select 1 from z.TaskQueueTasks where BatchID = @BatchID and Status = 'Running') break;
						waitfor delay '00:00:01';
					end;
				end;
				select @Worker = 1;
				while @Worker <= (select count(*) from @Jobs)
				begin
					select @Name = Name, @JobID = JobID from @Jobs where WorkerNumber = @Worker;
					begin try
						if z.fn_GetServiceJobID(@Name) = @JobID exec z.usp_RemoveServiceJob @Name = @Name;
					end try
					begin catch
						select @CleanupError = left(coalesce(@CleanupError + N'; ', N'') + error_message(), 2048);
					end catch;
					select @Worker += 1;
				end;
			end try
			begin catch
				select @CleanupError = error_message();
			end catch;
			begin try
				exec z.usp_ReleaseSemaphore @SemaphoreName = @Semaphore, @LockOwner = 'Session';
			end try
			begin catch
				select @CleanupError = coalesce(@CleanupError + N'; ', N'') + error_message();
			end catch;
		end;
		if @CleanupError is not null
		begin
			select @Error = left(@Error + N' Cleanup requires review: ' + @CleanupError, 2048);
			throw 50000, @Error, 1;
		end;
		throw;
	end catch;
end;
