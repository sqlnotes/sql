-- Procedures
exec z.usp_DropObject @ObjectName = N'z.usp_TaskQueueValidateBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_TaskQueuePrepareCommand';
exec z.usp_DropObject @ObjectName = N'z.usp_AddTaskQueueTask';
exec z.usp_DropObject @ObjectName = N'z.usp_CreateTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_ExecuteTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_ResolveTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_RestartTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_ResumeTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_RunTaskQueueWorker';
exec z.usp_DropObject @ObjectName = N'z.usp_TaskQueueRunWorker';
exec z.usp_DropObject @ObjectName = N'z.usp_SetTaskQueueAction';
exec z.usp_DropObject @ObjectName = N'z.usp_StartTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_StopTaskQueueBatch';
exec z.usp_DropObject @ObjectName = N'z.usp_ValidateTaskQueueBatch';

-- Views
exec z.usp_DropObject @ObjectName = N'z.v_TaskQueueActiveTasks';
