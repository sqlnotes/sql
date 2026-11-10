/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_CreateTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Creates a Draft batch without starting task execution.
Supply BatchID as an input/output parameter: NULL generates a datetime-encoded
identifier using the shared System sequence; a nonnull value is preserved.
ExecutionID is a separate execution-cycle token supplied by the table default.
The caller owns transaction settings and atomicity; this procedure performs one
batch insert and clears Action and ActionID after success or error.
*/
create or alter procedure z.usp_CreateTaskQueueBatch
(
	@BatchID bigint =  null output,
	@BatchName nvarchar(128),
	@Description nvarchar(max) = null,
	@MaxConcurrentWorkers int = 0
)
as
begin
	set nocount on;
	declare @ActionID uniqueidentifier = newid(), @SequenceValue bigint;
	begin try
		if @BatchID is null
		begin
			select @SequenceValue = next value for z.SeqGeneralID;
			select @BatchID = z.fn_GenerateZSequenceID(null, @SequenceValue);
		end;
		exec z.usp_SetTaskQueueAction @Action = N'Create', @ActionID = @ActionID;
		insert z.TaskQueueBatch (BatchID, BatchName, Description, MaxConcurrentWorkers)
			values (@BatchID, @BatchName, @Description, @MaxConcurrentWorkers);
		exec z.usp_SetTaskQueueAction;
	end try
	begin catch
		exec z.usp_SetTaskQueueAction;
		throw;
	end catch;
end;
