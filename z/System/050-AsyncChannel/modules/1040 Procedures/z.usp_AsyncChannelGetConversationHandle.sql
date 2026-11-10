/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelGetConversationHandle.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelGetConversationHandle.md

Creates or reuses a channel conversation for the calling session.
*/
create or alter procedure z.usp_AsyncChannelGetConversationHandle
(
	@AsyncChannelID int,
	@ConversationHandle uniqueidentifier output,
	@MaxRowsPerMessage int = null output
)
as
begin
	set nocount on

	declare @Readers tinyint, @IsActive bit, @DebugMode bit, @LockResult int,
			@SavedGroupBucket smallint, @ConversationGroup uniqueidentifier,
			@SessionID smallint = @@spid, @GroupBucket smallint, @TargetService sysname,
			@LockResource nvarchar(128) = cast(@AsyncChannelID as nvarchar(128)) + '-z.usp_AsyncChannelGetConversationHandle'
	select @ConversationHandle = null, @MaxRowsPerMessage = null
	if @AsyncChannelID is null
		return
	begin try
	begin tran
	exec @LockResult = z.usp_AcquireSemaphore @SemaphoreName = @LockResource, @TotalCount = 1,
										 @LockOwner = 'Transaction', @LockTimeout = -1
	if @LockResult <= 0
		throw 50000, 'Could not acquire the AsyncChannel conversation semaphore.', 1;

	select	@Readers = c.Readers, @IsActive = c.IsActive, @DebugMode = c.DebugMode,
			@MaxRowsPerMessage = c.MaxRowsPerMessage,
			@SavedGroupBucket = isnull(s.GroupBucket, -1), @GroupBucket = @SessionID % c.Readers,
			@ConversationHandle = s.ConversationHandle
	from z.AsyncChannel c
		left join z.AsyncChannelSession s on c.AsyncChannelID = s.AsyncChannelID and s.SessionID = @SessionID
	where c.AsyncChannelID = @AsyncChannelID
		and c.IsActive = 1
	if @@rowcount = 0
		goto ___Exit___

	if @SavedGroupBucket <> @GroupBucket
	begin
		select @TargetService = ServiceName from z.v_AsyncChannel where AsyncChannelID = @AsyncChannelID
		select @ConversationGroup = hashbytes('MD5', cast(cast(@GroupBucket as nvarchar(20)) + '-' +  @TargetService as varbinary(max)))
		if @ConversationHandle is not null
		begin
			end conversation @ConversationHandle;
			set @ConversationHandle = null;
		end

		begin dialog conversation @ConversationHandle
		from service [/SchemaZ/AsyncChannel/Sender]
		to service @TargetService, 'CURRENT DATABASE'
		on contract [/SchemaZ/AsyncChannel/Contract]
		with related_conversation_group  = @ConversationGroup, encryption = off;

		merge z.AsyncChannelSession t
		using (select @AsyncChannelID AsyncChannelID, @SessionID SessionID, @GroupBucket GroupBucket, @ConversationHandle ConversationHandle, getutcdate() StartTimeUTC) s on s.AsyncChannelID = t.AsyncChannelID and s.SessionID = t.SessionID
		when not matched then
			insert (AsyncChannelID, SessionID, GroupBucket, ConversationHandle, StartTimeUTC)
				values (s.AsyncChannelID, s.SessionID, s.GroupBucket, s.ConversationHandle, getutcdate())
		when matched then
			update set t.GroupBucket = s.GroupBucket, t.ConversationHandle = s.ConversationHandle, t.StartTimeUTC = s.StartTimeUTC
		;
	end

___Exit___:
	commit
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
