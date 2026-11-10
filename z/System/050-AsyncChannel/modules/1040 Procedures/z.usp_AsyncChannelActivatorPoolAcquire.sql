/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelActivatorPoolAcquire.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelActivatorPoolAcquire.md

Acquires a Session-owned shared semaphore processing slot.
*/
create or alter procedure z.usp_AsyncChannelActivatorPoolAcquire
(
	@AsyncChannelID int,
	@ActivatorPoolID int output
)
as
begin
	set nocount on
	declare @CandidatePoolID int, @MaxConcurrency int, @TimeoutSeconds int, @IsActive bit, @PoolName nvarchar(128),
			@Result int, @SemaphoreName nvarchar(200), @Info nvarchar(max), @TimeoutMS int
	select @ActivatorPoolID = null
	select	@CandidatePoolID = p.ActivatorPoolID, @PoolName = p.Name, @MaxConcurrency = p.MaxConcurrency,
			@TimeoutSeconds = p.TimeoutSeconds, @IsActive = p.IsActive
	from z.AsyncChannel c
		inner join z.AsyncChannelActivatorPool p on p.ActivatorPoolID = c.ActivatorPoolID
	where c.AsyncChannelID = @AsyncChannelID
	if isnull(@MaxConcurrency, 0) = 0 or @IsActive = 0
		return 0
	select	@SemaphoreName = N'ADPool/' + cast(@CandidatePoolID as nvarchar(11)),
			@TimeoutMS = case when @TimeoutSeconds = -1 then -1
				when cast(@TimeoutSeconds as bigint) * 1000 > 2147483647 then 2147483647
				else cast(@TimeoutSeconds as bigint) * 1000 end
	exec @Result = z.usp_AcquireSemaphore @SemaphoreName = @SemaphoreName, @TotalCount = @MaxConcurrency,
									  @LockOwner = 'Session', @LockTimeout = @TimeoutMS
	if @Result > 0
	begin
		select @ActivatorPoolID = @CandidatePoolID
		return 0
	end
	select @Info = N'activator pool ' + @PoolName + N': semaphore acquisition failed (result ' + cast(@Result as nvarchar(11))
		+ N', timeout ' + cast(@TimeoutMS as nvarchar(11)) + N'ms)'
	exec z.usp_AsyncChannelLog @AsyncChannelID = @AsyncChannelID, @Level = 'Warning', @Info = @Info, @SessionID = @@spid
	return -1
end
