/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_AddTaskQueueTask.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Adds one task atomically to a Draft batch using scalar metadata parameters.

Signature:
  @TaskBody nvarchar(max), @BatchID bigint = null, @BatchName nvarchar(128) = null,
  @TaskID int = null output, @TaskName nvarchar(128) = null,
  @Description nvarchar(max) = null, @SortOrder bigint = null,
  @MaxRetries int = 0, @CompletionCondition varchar(16) = 'Succeeded',
  @RetryIntervalSecond int = 60, @AvailableAtUTC datetime2(7) = null

TaskBody is one JSON object containing only the executable body, for example:
{
  "command": "z.usp_BackupDatabase",
  "parameters": [
    {"name": "Databases", "value": "Sales"},
    {"name": "BackupType", "value": "FULL"}
  ]
}

Task metadata is supplied through the scalar parameters, not a JSON envelope or array.
Supply BatchID or BatchName; both must match if supplied together. Null TaskID and
SortOrder allocate the next values in that batch. TaskID is returned through OUTPUT.
Null TaskName becomes 'Task - <TaskID>'; null AvailableAtUTC uses current UTC at insert.
Explicit SortOrder values may be shared by parallel tasks. The worker validates
the executable command and parameters when running the task.

Example:
  declare @TaskID int;
  exec z.usp_AddTaskQueueTask @BatchName = N'FullBackup', @TaskID = @TaskID output,
      @TaskName = N'Backup Sales', @SortOrder = 10, @MaxRetries = 2,
      @TaskBody = N'{"command":"z.usp_BackupDatabase","parameters":[{"name":"Databases","value":"Sales"},{"name":"BackupType","value":"FULL"}]}';
Uses a short transaction and the batch semaphore for atomic mutation.
A successful nested call leaves its caller transaction open; errors roll back the
active transaction. The procedure does not change transaction session settings.
*/
create or alter procedure z.usp_AddTaskQueueTask
(
	@TaskBody nvarchar(max),
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
	declare @ActionID uniqueidentifier = newid(), @Slot int, @BatchSemaphore nvarchar(200);
	begin try
		if left(trim(translate(@TaskBody, nchar(9) + nchar(10) + nchar(13), N'   ')), 1) <> N'{'
			throw 50000, 'TaskBody must be one JSON object containing the executable command and parameters.', 1;
		begin tran;
		exec z.usp_ResolveTaskQueueBatch @BatchID = @BatchID output, @BatchName = @BatchName;
		select @BatchSemaphore = N'z.TaskQueue.Batch:' + convert(nvarchar(20), @BatchID);
		exec @Slot = z.usp_AcquireSemaphore @SemaphoreName = @BatchSemaphore, @TotalCount = 1, @LockOwner = 'Transaction';
		if @Slot <= 0 throw 50000, 'Cannot acquire the TaskQueue batch semaphore.', 1;
		if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID and Status = 'Draft')
			throw 50000, 'Tasks can only be added to a Draft batch.', 1;
		if @TaskID is null
			select @TaskID = coalesce(max(TaskID), 0) + 1 from z.TaskQueueTasks where BatchID = @BatchID;
		if @SortOrder is null
			select @SortOrder = coalesce(max(SortOrder), 0) + 1 from z.TaskQueueTasks where BatchID = @BatchID;
		if @TaskName is null select @TaskName = N'Task - ' + convert(nvarchar(11), @TaskID);
		exec z.usp_SetTaskQueueAction @Action = N'AddTask', @ActionID = @ActionID;
		insert z.TaskQueueTasks (BatchID, TaskID, TaskName, Description, TaskBody, SortOrder, CompletionCondition, MaxRetries, RetryIntervalSecond, AvailableAtUTC)
			values (@BatchID, @TaskID, @TaskName, @Description, @TaskBody, @SortOrder, @CompletionCondition, @MaxRetries, @RetryIntervalSecond, coalesce(@AvailableAtUTC, sysutcdatetime()));
		commit;
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		if @@trancount > 0 rollback;
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
