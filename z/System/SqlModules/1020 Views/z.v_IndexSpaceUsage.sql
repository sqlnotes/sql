create or alter view z.v_IndexSpaceUsage
as
select	ps.partition_id PartitionID,
		ps.object_id ObjectID,
		object_schema_name(ps.object_id) SchemaName,
		object_name(ps.object_id) ObjectName,
		ps.index_id IndexID,
		i.name IndexName,
		ps.partition_number PartitionNumber,
		ps.row_count Rows,
		ps.used_page_count * 8.192 / 1024 SpaceUsedMB,
		ps.reserved_page_count  * 8.192 / 1024 SpaceReservedMB,
		(ps.reserved_page_count - ps.used_page_count) * 8.192 / 1024 FreeSpaceMB,

		ps.in_row_data_page_count InRowDataPageCount,
		ps.in_row_used_page_count InRowUsedPageCount,
		ps.in_row_reserved_page_count InRowReservedPageCount,
		ps.lob_used_page_count LOBUsedPageCount,
		ps.lob_reserved_page_count LOBREservedPageCount,
		ps.row_overflow_used_page_count RowEverflowUsedPageCount,
		ps.row_overflow_reserved_page_count RowOverflowReservedPageCount,
		ps.used_page_count UsedPageCount,
		ps.reserved_page_count ReservedPageCount	
from sys.dm_db_partition_stats ps
	left join sys.indexes i on i.object_id = ps.object_id and i.index_id = ps.index_id
