/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_SetLargeValueOutOfRow.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_setlargevalueoutofrow

Enables out-of-row large-value storage for current-database tables with max-length columns and
the option disabled.
*/
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


