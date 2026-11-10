/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_ResolveTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Internal helper resolving a required batch selector without changing state.
*/
create or alter procedure z.usp_ResolveTaskQueueBatch
(
	@BatchID bigint output,
	@BatchName nvarchar(128) = null
)
as
begin
	set nocount on;
	declare @NamedBatchID bigint;
	if @BatchID is null and @BatchName is null throw 50000, 'Supply BatchID or BatchName.', 1;
	if @BatchName is not null
	begin
		select @NamedBatchID = BatchID from z.TaskQueueBatch where BatchName = @BatchName;
		if @NamedBatchID is null throw 50000, 'The named TaskQueue batch does not exist.', 1;
		if @BatchID is not null and @BatchID <> @NamedBatchID throw 50000, 'BatchID and BatchName identify different batches.', 1;
		select @BatchID = @NamedBatchID;
	end;
	if not exists (select 1 from z.TaskQueueBatch where BatchID = @BatchID)
		throw 50000, 'The specified TaskQueue batch does not exist.', 1;
end;
