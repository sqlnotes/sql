/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1020%20Views/z.v_TaskQueueActiveTasks.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#active-task-view

Shows executing tasks and tasks eligible to start under batch, retry and level rules.
*/
create or alter view z.v_TaskQueueActiveTasks
as
select t.BatchID, b.ExecutionID, b.BatchName, b.Status BatchStatus, b.MaxConcurrentWorkers,
	t.TaskID, t.TaskName, t.Description, t.TaskBody, t.SortOrder,
	t.CompletionCondition, t.Status, t.MaxRetries, t.RetryIntervalSecond,
	t.AttemptsStarted, t.AvailableAtUTC, t.ClaimToken, t.WorkerSessionID, t.WorkerLoginTime, t.CreatedAtUTC,
	t.StartedAtUTC, t.FinishedAtUTC, t.LastErrorNumber, t.LastErrorMessage,
	cast(case when t.Status = 'Running' then 0 else 1 end as bit) IsReadyToExecute
from z.TaskQueueTasks t
	join z.TaskQueueBatch b on b.BatchID = t.BatchID
where t.Status = 'Running'
	or
	(
		b.Status in ('Ready', 'Running')
		and (b.MaxConcurrentWorkers = 0 or (select count_big(*) from z.TaskQueueTasks r where r.BatchID = t.BatchID and r.Status = 'Running') < b.MaxConcurrentWorkers)
		and t.Status in ('Pending', 'Failed')
		and cast(t.AttemptsStarted as bigint) < cast(t.MaxRetries as bigint) + 1
		and (t.Status = 'Pending' or t.AttemptsStarted > 0)
		and t.AvailableAtUTC <= sysutcdatetime()
		and not exists
		(
			select 1
			from z.TaskQueueTasks p
			where p.BatchID = t.BatchID and p.SortOrder < t.SortOrder
				and not
				(
					(p.Status = 'Succeeded' and p.CompletionCondition in ('Succeeded', 'Finished'))
					or (p.Status = 'Failed' and p.CompletionCondition in ('Failed', 'Finished')
						and cast(p.AttemptsStarted as bigint) >= cast(p.MaxRetries as bigint) + 1)
				)
		)
	);
