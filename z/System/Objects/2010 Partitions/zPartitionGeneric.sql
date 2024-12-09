if not exists(select * from sys.partition_functions where name = 'PF_zPartitionGeneric')
	create partition function PF_zPartitionGeneric (bigint) as range left for values();
go
if not exists(select * from sys.partition_schemes where name = 'PS_zPartitionGeneric')
	create partition scheme PS_zPartitionGeneric as partition PF_zPartitionGeneric all to ([Default])
go