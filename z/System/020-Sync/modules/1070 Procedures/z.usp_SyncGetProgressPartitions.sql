create or alter procedure z.usp_SyncGetProgressPartitions(@ConfigID int)
as
begin
	set nocount on;
	select [Partition], [NextOffset]
	from z.SyncProgressPartition
	where ConfigID = @ConfigID
	order by [Partition];
end


go
