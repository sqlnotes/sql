/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueCreateBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Creates a Draft batch without starting task execution.
Supply BatchID as an input/output parameter: NULL generates a datetime-encoded
identifier using the shared System sequence; a nonnull value is preserved.
ExecutionID is a separate execution-cycle token supplied by the table default.
Uses the current caller transaction and its batch semaphore when present.
Without an active transaction, the batch semaphore is skipped. The procedure does
not begin, commit or roll back transactions or change transaction session settings.
Clears Action and ActionID after success or error.
*/
create or alter procedure z.usp_TaskQueueCreateBatch
(
	@BatchID bigint =  null output,
	@BatchName nvarchar(128),
	@Description nvarchar(max) = null,
	@MaxConcurrentWorkers int = 0,
	@BatchType nvarchar(50) = N'Unclassified'
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid(), @SequenceValue bigint;
	begin try
		if @BatchID is null
		begin
			select	@SequenceValue = next value for z.SeqGeneralID;
			select	@BatchID = z.fn_GenerateZSequenceID(null, @SequenceValue);
		end;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		exec z.usp_TaskQueueSetAction @Action = N'Create', @ActionID = @ActionID;
		insert z.TaskQueueBatch (BatchID, BatchName, Description, MaxConcurrentWorkers, BatchType)
			values (@BatchID, @BatchName, @Description, @MaxConcurrentWorkers, @BatchType);
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
