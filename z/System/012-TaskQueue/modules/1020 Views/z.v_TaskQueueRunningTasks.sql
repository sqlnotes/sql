/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1020%20Views/z.v_TaskQueueRunningTasks.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#running-task-view

Shows currently running task attempts, including tasks in stopped batches.
*/
create or alter view z.v_TaskQueueRunningTasks
as
select	t.BatchID, b.ExecutionID, b.BatchName, b.BatchType, b.Status BatchStatus, b.MaxConcurrentWorkers,
		t.TaskID, t.TaskName, t.Description, t.ExecutorProcedure, t.Parameters, t.SortOrder,
		t.CompletionCondition, t.Status, t.MaxRetries, t.RetryIntervalSecond,
		t.AttemptsStarted, t.ClaimToken, t.WorkerSessionID, t.WorkerLoginTime, t.CreatedAtUTC, t.StartedAtUTC,
		cast(
				case
					when applock_mode('public', s.TaskSemaphoreSlot, 'Session') <> 'NoLock'
						or applock_test('public', s.TaskSemaphoreSlot, 'Exclusive', 'Session') <> 1 then 1
					else 0
				end as bit
			) IsTaskLockHeld
from z.TaskQueueTasks t
	inner join z.TaskQueueBatch b on b.BatchID = t.BatchID
	cross apply (select z.fn_TaskQueueGetTaskSemaphoreSlot(t.BatchID, t.TaskID) TaskSemaphoreSlot) s
where t.Status = 'Running';
