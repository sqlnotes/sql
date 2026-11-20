/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1020%20Views/z.v_TaskQueuePendingTasks.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#pending-task-view

Shows pending and retryable failed tasks in Running batches; workers apply availability, order and capacity rules.
*/
create or alter view z.v_TaskQueuePendingTasks
as
select	t.BatchID, b.ExecutionID, b.BatchName, b.BatchType, b.Status BatchStatus, b.MaxConcurrentWorkers,
		t.TaskID, t.TaskName, t.Description, t.ExecutorProcedure, t.Parameters, t.SortOrder,
		t.CompletionCondition, t.Status, t.MaxRetries, t.RetryIntervalSecond,
		t.AttemptsStarted, t.AvailableAtUTC, t.CreatedAtUTC, t.LastErrorNumber, t.LastErrorMessage
from z.TaskQueueTasks t
	inner join z.TaskQueueBatch b on b.BatchID = t.BatchID
where b.Status = 'Running' and t.CompletionState = 0
	and t.Status in ('Pending', 'Failed')
	and t.AttemptsStarted <= t.MaxRetries;
