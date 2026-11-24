create or alter procedure z.usp_SetSyncRowCount(@RowCount int)
as
begin
	exec sp_set_session_context N'SyncRowCount', @RowCount
end

go
