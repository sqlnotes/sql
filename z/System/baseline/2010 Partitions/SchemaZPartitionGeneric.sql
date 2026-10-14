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
