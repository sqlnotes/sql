/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/baseline/2010%20Partitions/SchemaZPartitionGeneric.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/010-Partition/docs/reference/storage.md#pf_schemazpartitiongeneric-and-ps_schemazpartitiongeneric

Creates the shared bigint RANGE LEFT and datetime RANGE RIGHT partition functions and
default-filegroup schemes when absent.
*/
if not exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGeneric')
	create partition function PF_SchemaZPartitionGeneric (bigint) as range left for values();
go
if not exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGeneric')
	create partition scheme PS_SchemaZPartitionGeneric as partition PF_SchemaZPartitionGeneric all to ([Default])
go
if not exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGenericDateTime')
	create partition function PF_SchemaZPartitionGenericDateTime (datetime) as range right for values();
go
if not exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGenericDateTime')
	create partition scheme PS_SchemaZPartitionGenericDateTime as partition PF_SchemaZPartitionGenericDateTime all to ([Default])
go
