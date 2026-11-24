create or alter procedure z.usp_SyncGetInitializationScript
(
	@ConfigID int
)
as
begin
	set nocount on
	select Script
	from z.SyncPublisherInitializationScript with(forceseek)
	where ConfigID = @ConfigID
	order by ScriptOrder
end


go
