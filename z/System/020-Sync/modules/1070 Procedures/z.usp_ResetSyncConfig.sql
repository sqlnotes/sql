create or alter procedure z.usp_ResetSyncConfig
(
	@Name varchar(128)
)
as
begin
	set nocount on
	delete p
	from z.SyncProgress p
		inner join z.SyncConfig c on c.ConfigID = p.ConfigID
	where c.Name = @Name
end

go
