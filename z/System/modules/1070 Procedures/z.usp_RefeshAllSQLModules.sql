create or alter procedure z.usp_RefeshAllSQLModules @RefreshTimes int = 1
as
begin
    declare @ObjectName nvarchar(max)
    declare c cursor local static for
        select quotename(object_schema_name(object_id))+ '.'+quotename(object_name(object_id))
        from sys.sql_modules
        where definition is not null
		order by 1
    open c
    fetch next from c into @ObjectName
    while @@fetch_status = 0
        begin
            begin try
                if @ObjectName is not null
                    exec sp_refreshsqlmodule @ObjectName
            end try
            begin catch
                select @ObjectName = 'Refreshing object ' + @ObjectName + '
' + error_message();
                throw 50000, @ObjectName, 12;
            end catch
            fetch next from c into @ObjectName
        end
    close c
    deallocate c
    select @RefreshTimes -= 1
    if @RefreshTimes > 0
        exec z.usp_RefeshAllSQLModules @RefreshTimes
end