if not exists(select * from sys.partition_functions where name = 'PF_SchemaZPartitionGeneric')
	create partition function PF_SchemaZPartitionGeneric (bigint) as range left for values();
go
if not exists(select * from sys.partition_schemes where name = 'PS_SchemaZPartitionGeneric')
	create partition scheme PS_SchemaZPartitionGeneric as partition PF_SchemaZPartitionGeneric all to ([Default])
go