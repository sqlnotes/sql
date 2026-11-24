/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_TaskQueueResolveBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Returns both batch selectors from one lookup, preferring BatchID when supplied.
*/
create or alter procedure z.usp_TaskQueueResolveBatch
(
	@BatchID bigint = null output,
	@BatchName nvarchar(128) = null output
)
as
begin
	set nocount on;
	if @BatchID is null and @BatchName is null
		throw 50000, 'Supply BatchID or BatchName.', 1;
	if @BatchID is null
	begin
		select	@BatchID = BatchID, @BatchName = BatchName
		from z.TaskQueueBatch
		where BatchName = @BatchName;
	end
	else
	begin
		select	@BatchID = BatchID, @BatchName = BatchName
		from z.TaskQueueBatch
		where BatchID = @BatchID;
	end
	if @@rowcount = 0
		throw 50000, 'The specified TaskQueue batch does not exist.', 1;
end;
