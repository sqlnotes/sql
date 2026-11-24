create or alter function z.fn_GetSyncRange(@Name varchar(128))
returns table
as
return  (
			select p.ConfigID, p.FromValue, p.ToValue, p.FromValueAdjusted, p.ToValueAdjusted, p.Error
			from z.SyncProgress p
				inner join z.SyncConfig c on p.ConfigID = c.ConfigID
			where c.Name = @Name
		)

go
