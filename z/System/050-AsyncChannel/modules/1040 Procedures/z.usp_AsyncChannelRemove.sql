/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelRemove.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelRemove.md

Cleans selected channel conversations and generated artifacts, preserving authored objects.
*/
create or alter procedure z.usp_AsyncChannelRemove
(
	@AsyncChannelID int
)
as
begin
	set nocount, xact_abort on;

	declare @Name nvarchar(128), @Queue sysname, @Service sysname,
			@Serializer sysname, @Deserializer sysname, @Trigger sysname,
			@Enqueue sysname, @Activator sysname
	select	@Name = Name, @Queue = QueueName, @Service = ServiceName,
			@Serializer = Serializer, @Deserializer = Deserializer, @Trigger = SourceInterfaceTrigger,
			@Enqueue = EnqueueProcedure, @Activator = ActivatorProcedure
	from z.v_AsyncChannel
	where AsyncChannelID = @AsyncChannelID
	if @Name is null
		return

	-- stop the queue activator so the queue can be dropped
	if object_id(@Queue) is not null and exists (select 1 from sys.service_queues where object_id = object_id(@Queue) and is_activation_enabled = 1)
		exec (N'alter queue ' + @Queue + N' with activation (status = off);')

	-- end every live conversation tied to this channel (both endpoints), then clear sessions
	declare @end nvarchar(max) = N''
	select @end = @end + N'end conversation ''' + cast(h as nvarchar(60)) + N''' with cleanup;'
	from (
			select s.ConversationHandle h
			from z.AsyncChannelSession s
				join sys.conversation_endpoints e on e.conversation_handle = s.ConversationHandle
			where s.AsyncChannelID = @AsyncChannelID
			union
			select e.conversation_handle
			from sys.conversation_endpoints e
			where e.service_id = (select service_id from sys.services where name collate database_default = @Service)
		) x
	if @end <> N''
		exec (@end)
	delete from z.AsyncChannelSession where AsyncChannelID = @AsyncChannelID

	-- drop generated objects; keep the authored Interface view and Processing procedure
	declare @sql nvarchar(max)
	if object_id(@Trigger) is not null       begin set @sql = N'drop trigger ' + @Trigger + N';'; exec (@sql) end
	if object_id(@Enqueue) is not null        begin set @sql = N'drop procedure ' + @Enqueue + N';'; exec (@sql) end
	if object_id(@Activator) is not null     begin set @sql = N'drop procedure ' + @Activator + N';'; exec (@sql) end
	if object_id(@Serializer) is not null     begin set @sql = N'drop function ' + @Serializer + N';'; exec (@sql) end
	if object_id(@Deserializer) is not null   begin set @sql = N'drop function ' + @Deserializer + N';'; exec (@sql) end
	if exists (select 1 from sys.services where name collate database_default = @Service)
	begin set @sql = N'drop service ' + quotename(@Service) + N';'; exec (@sql) end
	if object_id(@Queue) is not null          begin set @sql = N'drop queue ' + @Queue + N';'; exec (@sql) end

	delete from z.AsyncChannel where AsyncChannelID = @AsyncChannelID
end
