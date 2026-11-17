/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/versions/0.0.1/z.TaskQueueTasks.Executor.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#task-table

Converts an empty legacy task table to the executor/opaque-payload contract.
Populated TaskBody installations need an explicit executor and payload migration.
*/
set quoted_identifier on;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
set numeric_roundabort off;

if object_id(N'z.TaskQueueTasks', N'U') is not null
begin
	begin try
		begin tran;
		if col_length(N'z.TaskQueueTasks', N'TaskBody') is not null
			or col_length(N'z.TaskQueueTasks', N'ExecutorProcedure') is null
			or col_length(N'z.TaskQueueTasks', N'Parameters') is null
		begin
			-- Hold the empty-table decision through the schema change.
			if exists (select 1 from z.TaskQueueTasks with (tablockx, holdlock))
				throw 50000, 'Migrate existing tasks to ExecutorProcedure and Parameters and remove TaskBody before deploying the executor contract; no executor mapping can be inferred from legacy task bodies.', 1;
			if col_length(N'z.TaskQueueTasks', N'ExecutorProcedure') is null
				exec sys.sp_executesql N'alter table z.TaskQueueTasks add ExecutorProcedure nvarchar(300) not null;';
			if col_length(N'z.TaskQueueTasks', N'Parameters') is null
				exec sys.sp_executesql N'alter table z.TaskQueueTasks add Parameters nvarchar(max);';
			if col_length(N'z.TaskQueueTasks', N'TaskBody') is not null
			begin
				if object_id(N'z.CK_z_TaskQueueTasks_TaskBody', N'C') is not null
					exec sys.sp_executesql N'alter table z.TaskQueueTasks drop constraint CK_z_TaskQueueTasks_TaskBody;';
				exec sys.sp_executesql N'alter table z.TaskQueueTasks drop column TaskBody;';
			end;
		end;
		if not exists (select 1 from sys.columns where object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'ExecutorProcedure'
			and system_type_id = type_id(N'nvarchar') and max_length in (600, 2070) and is_nullable = 0 and is_computed = 0)
			or not exists (select 1 from sys.columns where object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'Parameters'
				and system_type_id = type_id(N'nvarchar') and max_length = -1 and is_computed = 0)
			throw 50000, 'TaskQueueTasks requires a stored not-null ExecutorProcedure nvarchar(300) column and a stored Parameters nvarchar(max) column; finish the explicit schema migration before deployment.', 1;
		if col_length(N'z.TaskQueueTasks', N'ExecutorProcedure') = 2070
		begin
			if exists (select 1 from sys.check_constraints where parent_object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'CK_z_TaskQueueTasks_ExecutorProcedure')
				exec sys.sp_executesql N'alter table z.TaskQueueTasks drop constraint CK_z_TaskQueueTasks_ExecutorProcedure;';
			exec sys.sp_executesql N'alter table z.TaskQueueTasks alter column ExecutorProcedure nvarchar(300) not null;';
		end;
		if not exists (select 1 from sys.check_constraints where parent_object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'CK_z_TaskQueueTasks_ExecutorProcedure')
			exec sys.sp_executesql N'alter table z.TaskQueueTasks with check add constraint CK_z_TaskQueueTasks_ExecutorProcedure check (len(trim(ExecutorProcedure)) > 0);';
		if exists (select 1 from sys.check_constraints where parent_object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'CK_z_TaskQueueTasks_Parameters')
			exec sys.sp_executesql N'alter table z.TaskQueueTasks drop constraint CK_z_TaskQueueTasks_Parameters;';
		if exists (select 1 from sys.columns where object_id = object_id(N'z.TaskQueueTasks', N'U') and name = N'Parameters' and is_nullable = 0)
			exec sys.sp_executesql N'alter table z.TaskQueueTasks alter column Parameters nvarchar(max) null;';
		if exists (select 1 from sys.check_constraints where parent_object_id = object_id(N'z.TaskQueueTasks', N'U')
			and name = N'CK_z_TaskQueueTasks_ExecutorProcedure' and (is_disabled = 1 or is_not_trusted = 1))
			exec sys.sp_executesql N'alter table z.TaskQueueTasks with check check constraint CK_z_TaskQueueTasks_ExecutorProcedure;';
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch;
end;
