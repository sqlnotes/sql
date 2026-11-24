create or alter procedure z.usp_SyncGetLock
(
	@ConfigID int,
	@Result int output
)
as
begin
	set nocount on
	declare @Resource nvarchar(200) = cast(@ConfigID as nvarchar(20)) + '-z.usp_SyncGetLock'
	select @Result = -1
	if applock_test('public',@Resource, 'Exclusive', 'Session') = 0
		return;
	if applock_mode('public',@Resource, 'Session') = 'Exclusive'
		return;
	exec @Result = sp_getapplock @Resource, 'Exclusive', 'Session', 0
end

go
