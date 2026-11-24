create or alter view z.v_SyncableTables
as
select s.name SchemaName, t.name as TableName, t.object_id ObjectID
from sys.tables t
	inner join sys.schemas s on s.schema_id = t.schema_id
where exists(select * from sys.indexes i where i.object_id = t.object_id and i.is_primary_key = 1)
	and exists(select * from sys.columns c where c.object_id = t.object_id and c.name = 'RowVersion')
	and s.name <> 'z'

go
