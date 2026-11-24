create or alter function z.fn_SyncGetConfigName(@PublisherID int, @TableName nvarchar(128))
returns varchar(128)
as
begin
	return 'Pub' + cast(@PublisherID as varchar(128)) + '-' + object_schema_name(object_id(@TableName)) + '-' + object_name(object_id(@TableName))
end

go
