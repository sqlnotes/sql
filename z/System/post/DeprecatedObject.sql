-- Triggers

-- Procedures
exec z.usp_DropObject @ObjectName = N'z.usp_DataInitialization_DatabaseSchemas';
exec z.usp_DropObject @ObjectName = N'z.usp_RemoveZSchema';

-- Views

-- Functions
exec z.usp_DropObject @ObjectName = N'z._fn_SecondToTimeString';
exec z.usp_DropObject @ObjectName = N'z.fn_BuildQueryCopyTableSchema';
exec z.usp_DropObject @ObjectName = N'z.fn_CopyTableSchema';
exec z.usp_DropObject @ObjectName = N'z.fn_GetZSequenceID';
exec z.usp_DropObject @ObjectName = N'z.fn_LettersOnly';
exec z.usp_DropObject @ObjectName = N'z.fn_NumbersOnly';
exec z.usp_DropObject @ObjectName = N'z.fn_PreviousCommittedRowVersion';
exec z.usp_DropObject @ObjectName = N'z.fn_ReadLinesFromString';
exec z.usp_DropObject @ObjectName = N'z.fn_SecondsToTimeString';

-- Synonyms

-- Tables
exec z.usp_DropObject @ObjectName = N'z.DatabaseSchemas';

-- Sequences

-- Types

-- Partition schemes
if exists (select 1 from sys.partition_schemes where name = N'PS_zPartitionGeneric')
begin
	if not exists (select 1 from sys.indexes i inner join sys.partition_schemes s on s.data_space_id = i.data_space_id where s.name = N'PS_zPartitionGeneric')
		drop partition scheme PS_zPartitionGeneric;
	else
		print 'Deprecated partition scheme PS_zPartitionGeneric is still in use; retained.';
end

-- Partition functions
if exists (select 1 from sys.partition_functions where name = N'PF_zPartitionGeneric')
begin
	if not exists (select 1 from sys.partition_schemes s inner join sys.partition_functions f on f.function_id = s.function_id where f.name = N'PF_zPartitionGeneric')
		drop partition function PF_zPartitionGeneric;
	else
		print 'Deprecated partition function PF_zPartitionGeneric is still in use; retained.';
end

-- Schemas
