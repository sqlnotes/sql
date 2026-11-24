create or alter procedure z.usp_SyncSetProgressPartition(@ConfigID int, @Partition int, @NextOffset bigint)
as
begin
	set nocount on;
	update z.SyncProgressPartition
	set NextOffset = @NextOffset, UpdatedDate = sysdatetime()
	where ConfigID = @ConfigID and [Partition] = @Partition;
	if @@rowcount = 0
		insert into z.SyncProgressPartition (ConfigID, [Partition], NextOffset)
		values (@ConfigID, @Partition, @NextOffset);
end


go
