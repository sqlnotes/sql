create or alter view z.v_IndexSpaceUsed
as
select	ps.partition_id PartitionID,
		ps.object_id ObjectID,
		object_schema_name(ps.object_id) SchemaName,
		object_name(ps.object_id) ObjectName,
		ps.index_id IndexID,
		i.name IndexName,
		ps.partition_number PartitionNumber,
		ps.row_count [RowCount],

		ps.used_page_count UsedPageCount,
		ps.used_page_count * 8 UsedSpaceKB,

		ps.reserved_page_count ReservedPageCount,
		ps.reserved_page_count * 8 ReservedSpaceKB,

		ps.reserved_page_count - ps.used_page_count FreePageCount,
		(ps.reserved_page_count - ps.used_page_count) * 8 FreeSpaceKB,

		ps.in_row_data_page_count InRowDataPageCount,
		ps.in_row_data_page_count * 8 InRowDataSpaceKB,

		ps.in_row_used_page_count InRowUsedPageCount,
		ps.in_row_used_page_count * 8 InRowUsedSpaceKB,

		ps.in_row_reserved_page_count InRowReservedPageCount,
		ps.in_row_reserved_page_count * 8 InRowReservedSpaceKB,

		ps.lob_used_page_count LOBUsedPageCount,
		ps.lob_used_page_count * 8 LOBUsedSpaceKB,

		ps.lob_reserved_page_count LOBReservedPageCount,
		ps.lob_reserved_page_count * 8 LOBReservedSpaceKB,

		ps.row_overflow_used_page_count RowOverflowUsedPageCount,
		ps.row_overflow_used_page_count * 8 RowOverflowUsedSpaceKB,

		ps.row_overflow_reserved_page_count RowOverflowReservedPageCount,
		ps.row_overflow_reserved_page_count * 8 RowOverflowReservedSpaceKB,

		ps.row_count [Rows],
		ps.used_page_count * 8.192 / 1024 SpaceUsedMB,
		ps.reserved_page_count * 8.192 / 1024 SpaceReservedMB,
		(ps.reserved_page_count - ps.used_page_count) * 8.192 / 1024 FreeSpaceMB
from sys.dm_db_partition_stats ps
	left join sys.indexes i on i.object_id = ps.object_id and i.index_id = ps.index_id
