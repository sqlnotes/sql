/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueAddTask.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Adds one task to a Draft batch.
ExecutorProcedure names the executor; Parameters is passed unchanged as its
@Parameters nvarchar(max) argument. The executor owns interpreting the payload.
No target existence, procedure metadata or payload-member validation is performed.
Supply BatchID or BatchName; both must match if supplied together. Null TaskID and
SortOrder allocate the next values in that batch. TaskID is returned through OUTPUT.
Null TaskName becomes 'Task - <TaskID>'; null AvailableAtUTC uses current UTC.
Uses the current caller transaction and its batch semaphore when present.
Without an active transaction, the batch semaphore is skipped. The procedure does
not begin, commit or roll back transactions or change transaction session settings.
*/
create or alter procedure z.usp_TaskQueueAddTask
(
	@ExecutorProcedure nvarchar(max),
	@Parameters nvarchar(max) = null,
	@BatchID bigint = null,
	@BatchName nvarchar(128) = null,
	@TaskID int = null output,
	@TaskName nvarchar(128) = null,
	@Description nvarchar(max) = null,
	@SortOrder bigint = null,
	@MaxRetries int = 0,
	@CompletionCondition varchar(16) = 'Succeeded',
	@RetryIntervalSecond int = 60,
	@AvailableAtUTC datetime2(7) = null
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid();
	begin try
		exec z.usp_TaskQueueResolveBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		exec z.usp_TaskQueueLockBatchForChange @BatchID = @BatchID;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status = 'Draft')
			throw 50000, 'Tasks can only be added to a Draft batch.', 1;
		if @TaskID is null
			select	@TaskID = isnull(max(TaskID), 0) + 1 from z.TaskQueueTasks where BatchID = @BatchID;
		if @SortOrder is null
			select	@SortOrder = isnull(max(SortOrder), 0) + 1 from z.TaskQueueTasks where BatchID = @BatchID;
		if @TaskName is null select @TaskName = N'Task - ' + convert(nvarchar(11), @TaskID);
		exec z.usp_TaskQueueSetAction @Action = N'AddTask', @ActionID = @ActionID;
		insert z.TaskQueueTasks (BatchID, TaskID, TaskName, Description, ExecutorProcedure, Parameters, SortOrder, CompletionCondition, MaxRetries, RetryIntervalSecond, AvailableAtUTC)
			values (@BatchID, @TaskID, @TaskName, @Description, @ExecutorProcedure, @Parameters, @SortOrder, @CompletionCondition, @MaxRetries, @RetryIntervalSecond, isnull(@AvailableAtUTC, sysutcdatetime()));
		exec z.usp_TaskQueueSetAction;
	end try
	begin catch
		exec z.usp_TaskQueueSetAction;
		throw;
	end catch;
end;
