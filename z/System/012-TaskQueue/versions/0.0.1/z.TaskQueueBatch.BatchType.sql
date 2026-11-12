/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/versions/0.0.1/z.TaskQueueBatch.BatchType.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-table

Adds batch classification to existing TaskQueue installations.
*/
if object_id(N'z.TaskQueueBatch', N'U') is not null and col_length(N'z.TaskQueueBatch', N'BatchType') is null
begin
	alter table z.TaskQueueBatch add BatchType nvarchar(50) not null constraint DF_z_TaskQueueBatch_BatchType default (N'Unclassified') with values;
end;
