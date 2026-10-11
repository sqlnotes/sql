create or alter procedure z.usp_SetLargeValueOutOfRow
as
begin
	set nocount on
	declare @FullObjectName nvarchar(300)
	declare c cursor static local for
		select quotename(schema_name(schema_id)) + '.' + quotename(name)
		from sys.tables t
		where exists(select * from sys.columns c where t.object_id = c.object_id and c.max_length = -1)
			and large_value_types_out_of_row = 0
	open c
	fetch next from c into @FullObjectName
	while @@fetch_status = 0
	begin
		exec sp_tableoption @TableNamePattern = @FullObjectName, @OptionName = 'large value types out of row', @OptionValue = 'on'
		fetch next from c into @FullObjectName
	end
	close c
	deallocate c
end


