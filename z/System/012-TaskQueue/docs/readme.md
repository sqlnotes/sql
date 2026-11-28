# TaskQueue

TaskQueue runs stored procedures in ordered groups. Tasks at the same `SortOrder` can run concurrently. A higher group waits for every task in the preceding groups to satisfy its completion condition. SQL Server Agent supplies the workers. The calling application decides whether the recorded outcomes meet its own success criteria.

Use it when you need a persistent list of work, a limit on parallel execution, retry rules and a record of each task's outcome. A task is one call to a procedure you supply. For example, several item-processing tasks can run together, followed by a summary task after they succeed.

TaskQueue uses the [Jobs module](../../010-Jobs/docs/readme.md) to launch workers and System semaphores to coordinate them. Install it in the database that will hold the batch definitions and history. The executor procedure must accept the `@Parameters` argument described below.

## Define and execute a batch

This example assumes `dbo.usp_ProcessItem` exists in the coordination database and accepts `@Parameters nvarchar(max)`. Use a unique batch name for each new batch. The transaction publishes the definition as one unit. Launch after commit on a connection with implicit transactions off.

```sql
declare @BatchID bigint;
begin try
	begin tran;
	exec z.usp_TaskQueueCreateBatch @BatchID = @BatchID output,
		@BatchName = N'Process items 101 and 102', @MaxConcurrentWorkers = 2;
	exec z.usp_TaskQueueAddTask @BatchID = @BatchID, @TaskName = N'Item 101',
		@SortOrder = 1, @ExecutorProcedure = N'dbo.usp_ProcessItem', @Parameters = N'101';
	exec z.usp_TaskQueueAddTask @BatchID = @BatchID, @TaskName = N'Item 102',
		@SortOrder = 1, @ExecutorProcedure = N'dbo.usp_ProcessItem', @Parameters = N'102';
	commit;
end try
begin catch
	if @@trancount > 0
		rollback;
	throw;
end catch;

exec z.usp_TaskQueueExecuteBatch @BatchID = @BatchID;

select	BatchID, Status, StartedAtUTC, FinishedAtUTC
from z.TaskQueueBatch
where BatchID = @BatchID;

select	TaskID, TaskName, Status, AttemptsStarted, CompletionCondition, LastErrorMessage
from z.TaskQueueTasks
where BatchID = @BatchID
order by SortOrder, TaskID;
```

The example creates two tasks at the same sort level and permits two workers, so the tasks can run together. `@BatchID output` gives you the ID needed to inspect their results. The last query is the important success check: a Completed batch means the launcher finished, not that every task succeeded. Read each task's `Status` and `LastErrorMessage` before treating the work as successful.

## Main inputs and results

| Input | Meaning |
| --- | --- |
| `@BatchName` | A unique name for a new batch. Existing batches can be selected by ID or name. |
| `@BatchID` | The batch identifier. Creation can generate one and return it through `OUTPUT`. |
| `@MaxConcurrentWorkers` | Maximum number of tasks allowed to execute at once in the batch. Execution requires a positive value. |
| `@TaskName`, `@TaskID` | A display name and identifier for one task. Omit the task ID to assign the next available ID. |
| `@ExecutorProcedure` | The procedure to call for the task. Use a schema-qualified name. |
| `@Parameters` | Text passed unchanged to that procedure's named `@Parameters` argument. Your procedure interprets it. |
| `@SortOrder` | The task's group. Equal values permit parallel work; higher values wait for earlier groups. Omitted values assign successive groups. |
| `@MaxRetries`, `@RetryIntervalSecond` | Additional attempts after the initial attempt, and the delay between attempts. Defaults are zero retries and 60 seconds. |
| `@CompletionCondition` | What result permits later groups to proceed: Succeeded, Failed or Finished. See [task table](#task-table). |

Executors signal failure by raising a SQL error. Return codes do not fail an attempt, and result sets are not stored as task results. TaskQueue records statuses, attempt counts and error details in its tables; your executor stores any business output it needs to retain.

## Batch lifecycle

| Procedure | Input state | Result |
| --- | --- | --- |
| `z.usp_TaskQueueCreateBatch` | New ID and name | Creates a Draft batch. A NULL `@BatchID` generates a datetime-encoded bigint. Pass `OUTPUT` to receive it. |
| `z.usp_TaskQueueAddTask` | Draft | Adds one task. Omitted `@TaskID` and `@SortOrder` each use the current batch maximum plus one, starting at 1. Pass `@TaskID OUTPUT` to receive the assigned ID. |
| `z.usp_TaskQueueStartBatch` | Draft or Ready | Publishes Ready and returns the existing `@ExecutionID` and `@MaxConcurrentWorkers` through optional outputs. `@RequireWorkerLimit = 1` requires a positive limit. |
| `z.usp_TaskQueueExecuteBatch` | Draft or Ready with a positive worker limit | Sets Running, starts worker jobs, waits for them, then marks its own still-Running launch Completed. |
| `z.usp_TaskQueueStopBatch` | Ready, Running or Stopped | Sets Stopped. Active attempts finish and record their results. Workers stop claiming new tasks. |
| `z.usp_TaskQueueResumeBatch` | Stopped, no Running tasks | Sets Ready, preserving execution ID, progress and retry times. Reconcile terminal unmet conditions and Pending tasks with no attempts left before resuming. |
| `z.usp_TaskQueueRestartBatch` | Any state, no Running tasks | Sets Ready with a new execution ID. Resets all tasks to Pending with zero attempts and immediate availability. Earlier executor side effects persist. |

Supply `@BatchID` or `@BatchName` to select an existing batch. `z.usp_TaskQueueResolveBatch` returns the stored ID and name through optional outputs. An explicitly supplied ID takes precedence, including when it is unknown.

Create, Add and Start participate in the caller's transaction and leave its transaction settings intact. Use an explicit transaction to serialize concurrent ID/order allocation or publish several changes atomically. In autocommit, a competing insert can claim the same ID. With implicit transactions on, table access can start a caller-owned transaction. Stop, Resume and Restart open a transaction and roll back the active transaction on error, including caller work.

## Executor contract

Each executor receives a single named `@Parameters nvarchar(max)` argument. The worker passes the stored value unchanged, including NULL and whitespace. The executor owns interpretation and validation. SQL Server resolves the stored procedure name at execution time. Use a schema-qualified name to select a specific procedure, with database or server qualifiers as needed. Remote calls need linked-server RPC and permissions. For a global temporary executor (`##...`), keep its creating connection open and database-qualify references inside it.

The worker invokes executors with `XACT_ABORT ON`. Raise a SQL error to fail an attempt. The worker catches the error, rolls back any open executor transaction, records the error and next retry time, and continues under the normal scheduling rules. A procedure return code is ignored. A successful attempt clears the prior error. Executors run with worker privileges. Limit who can write tasks accordingly. Executor result sets can reach a direct worker caller. The queue stores only status and diagnostics.

## Execute a batch with Agent workers

`z.usp_TaskQueueExecuteBatch` starts worker jobs for one batch and waits for those jobs to finish or leave tracking. Use this as the normal entry point after defining the batch. It manages the launch; your application still checks the task results.

The launcher requires a running, visible local SQL Server Agent, a positive `MaxConcurrentWorkers`, no active transaction and implicit transactions off. This also applies to an empty batch. Callers need Agent job-management permissions and visibility into worker jobs and T-SQL sessions. Each job runs as its owner. [Jobs permissions and visibility](../../010-Jobs/docs/reference/supporting-objects.md#zfn_issqljobrunning)

The launcher resolves one batch and captures `StartedAtUTC` during admission. Admission and unscheduled job definitions commit together, followed by a short delay before polling begins. Job names include the coordination database, BatchID, ExecutionID and worker number. A concurrent launcher cannot admit the same Running batch. An existing matching **name** is reused as configured, so its command must run the correct worker and its deletion mode must be “on completion.”

One loop polls the tracked jobs with a one-second delay between passes. It requests up to three starts per job, at least 10 seconds apart. A visible worker session marks the job as started, and the launcher tracks that job until it disappears. A tracked job found missing also counts as a start, including a job that finished between polls.

Ten seconds after the third request, if the job still exists and no worker session has been seen, the launcher stops tracking it and attempts to delete it with its history and unused schedules. Successful launcher deletion does not count as a worker start. If the Agent call errors and the job is already missing, the launcher counts it as a start. If the job is still present, the launcher logs the removal error. The job can remain in Agent for manual cleanup.

When the launcher finishes tracking jobs, it sets Completed and records `FinishedAtUTC` only if its batch is still Running with the same `ExecutionID` and `StartedAtUTC`. Stop, Resume or a newer launch can make that update a successful no-op. If no job counted as started and the guarded update succeeds, the launcher records the error in `LastErrorMessage`, commits, then logs and raises it. Completed means the launch ended. Tasks can remain Failed, Pending or waiting for a retry. Inspect task rows to decide whether the work succeeded.

## Worker and execution ownership

`z.usp_TaskQueueExecuteBatchWorker` runs one task at a time in one selected Running batch. Use a dedicated connection outside a transaction, with implicit transactions off and no MARS or interleaved commands. A direct worker caller owns the Running transition and finalization. Calling a worker on a Ready batch returns without processing tasks.

The worker chooses due tasks from the earliest group whose completion conditions are not yet satisfied. It waits when a task is delayed or all worker slots are busy. It stops when the batch is no longer Running, all groups are satisfied, or the current group cannot make progress. A worker returning therefore does not imply that every task succeeded.

Only one worker can claim a particular attempt. The claim is saved before the executor is called, and completion is tied to that claim so an old worker cannot overwrite a newer attempt. After execution, the worker saves the outcome and tries to release its execution slots. Caught cleanup exceptions are printed; release failures do not undo the saved task outcome.

For wait diagnostics, due-task polling uses 300 milliseconds and capacity polling uses one second. A negative capacity status other than timeout ends the worker; a task-lock acquisition failure raises an error after cleanup is attempted. The [worker source](../modules/1070%20Procedures/z.usp_TaskQueueExecuteBatchWorker.sql) contains the lock and claim details.

Recovery marks unlocked Running attempts Failed, keeps the recorded attempt count, and applies the normal retry interval and limit. It uses the task lock rather than elapsed time or a missing DMV row. A disconnected executor may already have committed effects. Design retried tasks to tolerate repetition. An interrupted but still-connected session can retain locks. Disconnect it before recovery or reuse. A worker recovers only Running batches. An orphaned Running task in a Stopped batch requires reconciliation before Resume or Restart.

### Batch change lock

`z.usp_TaskQueueLockBatchForChange @BatchID` acquires one transaction-owned slot on `z.TaskQueue.Batch:<BatchID>` with unlimited wait. Commit or rollback releases it. Without an active transaction the helper returns immediately. The same lock serializes lifecycle changes, worker claims, recovery and outcome recording for one batch.

### Task semaphore

`z.fn_TaskQueueGetTaskSemaphore` builds `z.TaskQueue.Task:<BatchID>:<TaskID>`. `z.fn_TaskQueueGetTaskSemaphoreSlot` adds the `1-` prefix for its single slot. The worker holds the session-owned slot during execution. Avoid manually changing running task definitions, ownership or locks.

### Batch worker semaphore

`z.fn_TaskQueueGetBatchSemaphore` builds `z.TaskQueue.Worker:<BatchID>`. Each worker takes one session-owned slot before claiming a task. `StartBatch` can mark a batch with a zero limit Ready by default, but both execution procedures require a positive limit for work. Changes to the limit affect subsequent claims. An increased limit can admit workers already waiting for capacity. The number of Agent jobs is set when the batch launches.

## Batch table

[`z.TaskQueueBatch`](../baseline/2020%20Tables/z.TaskQueueBatch.sql) stores the caller-supplied or generated BatchID, unique nonblank BatchName, BatchType (default `Unclassified`), optional description, worker limit and lifecycle state. ExecutionID changes on creation and restart. CreatedAtUTC, StartedAtUTC and FinishedAtUTC describe the batch. The launcher clears LastErrorMessage at admission. Look on the task rows for executor errors.

## Task table

[`z.TaskQueueTasks`](../baseline/2020%20Tables/z.TaskQueueTasks.sql) is keyed by (BatchID, TaskID). It stores the executor, payload, sort level, retry policy and operational state. TaskName defaults to `Task - <TaskID>` and can repeat. ExecutorProcedure is stored as nvarchar(300). Task states are Pending, Running, Succeeded and Failed.

| CompletionCondition | What permits the next level to run |
| --- | --- |
| Succeeded (default) | The task succeeded. |
| Failed | The task failed and cannot retry. A successful task blocks later levels. |
| Finished | The task succeeded or failed with no retries left. |

An unmet condition blocks higher levels while other eligible tasks at the same level can still run. `MaxRetries` counts retries **after** the initial attempt and defaults to 0. `RetryIntervalSecond` defaults to 60. Retry scheduling uses a minimum of one second. AddTask stores a supplied zero as one, and the worker treats previously stored zeros as one. `AvailableAtUTC` defaults to the time of insertion. After failure it is the earliest retry time. A Failed row at the maximum int attempt count is terminal. WorkerSessionID, WorkerLoginTime and ClaimToken identify the current attempt. AttemptsStarted and the latest finish/error fields describe progress.

### Running task view

`z.v_TaskQueueRunningTasks` shows Running rows in any batch, including Stopped batches. `IsTaskLockHeld` reports whether the current session holds the execution lock or another exclusive session acquisition would be denied at that instant. It cannot identify the lock owner. Resume and Restart reject any Running row, including an unlocked row awaiting recovery.

### Pending task view

`z.v_TaskQueuePendingTasks` shows Pending and retryable Failed rows of Running batches with attempts available. It exposes the stored availability time, sort level and worker limit. It includes delayed tasks, later levels and tasks waiting on capacity. Read the view to inspect outstanding work. Only a worker claims it under the batch lock.

## Audit log

Use `z.TaskQueueLog` to trace what happened to a batch or task: when it was created, claimed, completed, retried or changed. Filter by `BatchID` and `ExecutionID` for one run, or by `ActionID` for one operation. The entries below explain which fields to use when diagnosing a failure.

`z.TRI_TaskQueueBatch` and `z.TRI_TaskQueueTasks` write each changed row to [`z.TaskQueueLog`](../baseline/2020%20Tables/z.TaskQueueLog.sql) in the same transaction. NULL TaskID denotes a batch entry. For row changes, BeforeJson and AfterJson contain operational values including the executor payload and nulls, excluding the derived CompletionState. A restart logs both the batch update and the reset tasks under the new ExecutionID and shared ActionID, retaining the previous ExecutionID in the batch row's BeforeJson.

The worker logs the task claim and executor outcome under `ExecuteTask` with one ActionID per attempt. On executor failure, the finish entry includes `LastErrorNumber` and `LastErrorMessage` in AfterJson. Each retry gets a new ActionID.

`WorkerError` entries have ChangeType `Insert` and store the caught SQL error in AfterJson, with the task ID when one was selected. The JSON has separate `ErrorNumber`, `ErrorSeverity`, `ErrorState`, `ErrorProcedure`, `ErrorLine`, and `ErrorMessage` fields. The worker rolls back any open transaction before writing the entry and rethrows the original error even if the log write fails. [Error JSON format](../../docs/reference/functions.md#zfn_getfullerrorjson)

`WorkerJobStartError`, `WorkerJobRemoved` and `WorkerJobRemoveError` include `BatchName`, `StartedAtUTC`, `WorkerNumber`, `JobName` (the service name), `JobID`, and `StartAttempts` in AfterJson. The two job error entries include formatted SQL error text in `ErrorMessage`. `WorkerLaunchError` records `BatchName`, `StartedAtUTC`, and `ErrorMessage` after a zero-worker launch is finalized. Each entry has ChangeType `Insert` and stores BatchID and ExecutionID in log columns. If a diagnostic log write fails, the launcher prints the failure to the caller.

Action identifies the lifecycle or worker operation. `z.usp_TaskQueueSetAction` sets the optional Action and ActionID session-context keys. Calling it without arguments clears both. Direct writes with no action context are labeled DirectInsert, DirectUpdate or DirectDelete. Client-supplied host/application and action labels are diagnostic. Rolled-back changes leave no history.

Query by BatchID/ExecutionID for a batch run, or by ActionID for one operation. `z.fn_ZSequenceIDToDatetime(LogID)` decodes UTC time to the second. The log uses the shared bigint partition scheme, page compression and its [retention policy](../../010-Partition/docs/reference/retention.md).

## Execution indexes and retained history

The indexed computed CompletionState is 0 for unresolved, 1 for terminal unmet and 2 for satisfied. The worker uses it to find the first unsatisfied level, then looks for due work at that level. A status/order/availability index supports the task lookup, and a filtered Running index supports recovery. Task writes require ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL and QUOTED_IDENTIFIER ON with NUMERIC_ROUNDABORT OFF.

## Procedure names

When upgrading, drain workers first and update external callers, job steps and object-specific EXECUTE grants. The [TaskQueue post script](../post/DeprecatedObject.sql) lists retired procedures and the old active-task view. Current procedure names follow `z.usp_TaskQueue<Verb><Object>`. Use the running and pending views for their respective populations. For example, replace `z.usp_TaskQueueExecuteWorker` and `z.usp_TaskQueueRunWorker` with `z.usp_TaskQueueExecuteBatchWorker`. No compatibility aliases are installed.

[Version 0.0.1 migrations](../versions/0.0.1) add BatchType and the executor/index schema to eligible existing tables. A populated legacy TaskBody table needs an explicit executor/payload mapping before deployment. Retired task statuses with no started attempts become Pending and preserve availability. Those with prior attempts become Failed and take their retry delay from migration time. Ownership fields clear, and attempt counts, payloads, retry settings and errors are retained. The migration supports the known prior computed definition and matching single-partition filegroup indexes. Review dependencies if it rejects an unfamiliar definition.
