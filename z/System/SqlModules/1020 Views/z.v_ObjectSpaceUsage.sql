create or alter view z.v_ObjectSpaceUsage
as
select p.object_id ObjectID, p.index_id IndexID, object_schema_name(p.object_id) SchemaName, object_name(object_id) objectName, max(p.rows) Rows,  sum(au.total_pages) * 8/1024.0 ReservedMB, sum(au.used_pages) * 8/1024.0 UsedMB, sum(au.data_pages) * 8/1024.0 DataMB
from sys.allocation_units au
	inner join sys.partitions p on p.partition_id = au.container_id
group by p.object_id, p.index_id

