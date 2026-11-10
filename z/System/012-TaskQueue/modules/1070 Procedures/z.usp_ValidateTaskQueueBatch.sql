/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/modules/1070%20Procedures/z.usp_ValidateTaskQueueBatch.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/012-TaskQueue/docs/readme.md#batch-lifecycle

Internal helper validating task definitions and optionally rejecting execution ownership.
*/
create or alter procedure z.usp_ValidateTaskQueueBatch
(
	@BatchID bigint,
	@RequireIdle bit = 0,
	@ValidateCommands bit = 1
)
as
begin
	set nocount on;
	if @RequireIdle = 1 and exists (select 1 from z.TaskQueueTasks where BatchID = @BatchID and Status = 'Running')
		throw 50000, 'The batch has Running tasks; wait for completion or recover ownership before changing it.', 1;
	declare @TaskID int, @Body nvarchar(max), @Command nvarchar(4000), @Parameters nvarchar(max),
		@SchemaName sysname, @ProcedureName sysname, @ObjectID int, @LockResource nvarchar(255);
	declare Definitions cursor local fast_forward for
		select TaskID, TaskBody from z.TaskQueueTasks where BatchID = @BatchID order by TaskID;
	begin try
		open Definitions;
		fetch next from Definitions into @TaskID, @Body;
		while @@fetch_status = 0
		begin
			if @RequireIdle = 1
			begin
				select @LockResource = N'1-z.TaskQueue.Task:' + convert(nvarchar(20), @BatchID) + N':' + convert(nvarchar(11), @TaskID);
				if applock_mode('public', @LockResource, 'Session') <> 'NoLock'
					or applock_test('public', @LockResource, 'Exclusive', 'Session') <> 1
					throw 50000, 'A task execution lock is still held; disconnect the owner or wait for completion.', 1;
			end;
			if @ValidateCommands = 1
			begin
				if isjson(@Body) <> 1 throw 50000, 'TaskBody must be valid JSON.', 1;
				if (select count(*) from openjson(@Body) where [key] = 'command') <> 1
					or not exists (select 1 from openjson(@Body) where [key] = 'command' and [type] = 1)
					or (select count(*) from openjson(@Body) where [key] = 'parameters') <> 1
					or not exists (select 1 from openjson(@Body) where [key] = 'parameters' and [type] = 4)
					throw 50000, 'TaskBody requires one command string and one parameters array.', 1;
				select @Command = json_value(@Body, '$.command'), @Parameters = json_query(@Body, '$.parameters');
				select @SchemaName = parsename(@Command, 2), @ProcedureName = parsename(@Command, 1);
				if @SchemaName is null or @ProcedureName is null or parsename(@Command, 3) is not null or parsename(@Command, 4) is not null
					throw 50000, 'Task commands must name local schema-qualified SQL procedures.', 1;
				select @ObjectID = object_id(quotename(@SchemaName) + N'.' + quotename(@ProcedureName), N'P');
				if @ObjectID is null or @ObjectID = object_id(N'z.usp_RunTaskQueueWorker', N'P')
					throw 50000, 'A task command does not identify an allowed existing SQL procedure.', 1;
				if exists (select 1 from openjson(@Parameters) where [type] <> 5)
					throw 50000, 'Each task parameter must be a JSON object.', 1;
				if exists
				(
					select 1 from openjson(@Parameters) p
					where (select count(*) from openjson(p.value) where [key] = 'name') <> 1
						or not exists (select 1 from openjson(p.value) where [key] = 'name' and [type] = 1)
						or (select count(*) from openjson(p.value) where [key] = 'value') <> 1
						or not exists (select 1 from openjson(p.value) where [key] = 'value' and [type] in (0, 1, 2, 3))
				)
					throw 50000, 'Each parameter requires one name and one scalar or null value.', 1;
				if exists
				(
					select n.ParameterName
					from openjson(@Parameters) p
						cross apply (values (case when left(json_value(p.value, '$.name'), 1) = N'@' then json_value(p.value, '$.name') else N'@' + json_value(p.value, '$.name') end)) n(ParameterName)
					group by n.ParameterName having count(*) > 1
				)
					throw 50000, 'Task parameter names must be unique.', 1;
				if exists
				(
					select 1 from openjson(@Parameters) p
						cross apply (values (case when left(json_value(p.value, '$.name'), 1) = N'@' then json_value(p.value, '$.name') else N'@' + json_value(p.value, '$.name') end)) n(ParameterName)
					where n.ParameterName is null or len(n.ParameterName) < 2 or len(n.ParameterName) > 128
						or substring(n.ParameterName, 2, 4000) collate Latin1_General_100_BIN2 like N'%[^A-Za-z0-9_]%'
						or substring(n.ParameterName, 2, 1) collate Latin1_General_100_BIN2 like N'[^A-Za-z_]'
						or not exists
						(
							select 1 from sys.parameters m
								join sys.types d on d.user_type_id = m.user_type_id and d.is_user_defined = 0 and d.is_table_type = 0
								join sys.types y on y.user_type_id = m.system_type_id and y.user_type_id = y.system_type_id
							where m.object_id = @ObjectID and m.name = n.ParameterName and m.is_output = 0
								and y.name in ('bigint', 'int', 'smallint', 'tinyint', 'bit', 'decimal', 'numeric', 'money', 'smallmoney',
									'float', 'real', 'date', 'datetime', 'smalldatetime', 'datetime2', 'datetimeoffset', 'time',
									'char', 'varchar', 'nchar', 'nvarchar', 'binary', 'varbinary', 'uniqueidentifier', 'xml')
						)
				)
					throw 50000, 'A task parameter name or metadata type is unsupported.', 1;
			end;
			fetch next from Definitions into @TaskID, @Body;
		end;
		close Definitions;
		deallocate Definitions;
	end try
	begin catch
		if cursor_status('local', 'Definitions') >= 0 close Definitions;
		if cursor_status('local', 'Definitions') > -3 deallocate Definitions;
		throw;
	end catch;
end;
