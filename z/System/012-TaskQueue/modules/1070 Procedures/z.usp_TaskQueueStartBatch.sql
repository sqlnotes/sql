/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueStartBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Publishes a Draft batch as Ready, or accepts an already Ready batch, without scanning task bodies.
Returns MaxConcurrentWorkers and the existing ExecutionID. RequireWorkerLimit requires a positive limit;
otherwise zero retains its unlimited-worker meaning.
ResolveBatch validates and resolves selectors before acquiring the batch semaphore.
One UPDATE changes status and returns batch values.
Uses the current caller transaction and its batch semaphore when present.
Without an active transaction, the batch semaphore is skipped. The procedure does
not begin, commit or roll back transactions or change transaction session settings.
*/
create or alter procedure z.usp_TaskQueueStartBatch
(
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null,
	@MaxConcurrentWorkers int = null output,
	@RequireWorkerLimit bit = 0,
	@ExecutionID uniqueidentifier = null output
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid();
	begin try
		exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName output;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction @Action = N'Start', @ActionID = @ActionID;
		update z.TaskQueueBatch set Status = 'Ready', @MaxConcurrentWorkers = MaxConcurrentWorkers, @ExecutionID = ExecutionID
		where BatchID = @BatchID
			and Status in ('Draft', 'Ready')
			and (@BatchName is null or BatchName = @BatchName)
			and (isnull(@RequireWorkerLimit, 0) = 0 or MaxConcurrentWorkers > 0);
		if @@rowcount = 0 throw 50000, 'Only a Draft or Ready batch satisfying the requested worker limit can be started.', 1;
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
