create or alter function z.fn_BuildQueryForcePartitionRetentionPolicy
(
    @PartitionFunctionName nvarchar(128),
    @PartitionRangeType varchar(20),
    @PartitionRangeTypeInterval int,
    @ForwardedPartitionCount int,
    @NextPartitionFileGroup nvarchar(128),
    @PartitionsToKeep int,
    @ArchivedSwappedPartitions bit,
	@Today datetime = null
)
returns @ret table(Ordinal int identity(1,1), Name varchar(300), SQL nvarchar(max))
as
begin
	if @PartitionRangeType not in ('Minute','Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly')
	begin
		insert into @ret(SQL)
			values('raiserror(''Invalid parameter @PartitionRangeType. Supported values Minute, Hourly, Daily, Weekly, Monthly, Yearly.'', 16, 1);')
		return
	end
	select @Today = isnull(@Today, getdate())

	declare @ThisPeriod datetime, @FirstPeriodToKeep datetime
	select @PartitionsToKeep = isnull(abs(@PartitionsToKeep), 0)

	select @ThisPeriod = z.fn_GetPeriodStart(@Today, @PartitionRangeType, @PartitionRangeTypeInterval, default)
	select @FirstPeriodToKeep = case @PartitionRangeType
									when 'Minute' then dateadd(minute, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
									when 'Hourly' then dateadd(hour, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
									when 'Daily' then dateadd(day, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
									when 'Monthly' then dateadd(month, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
									when 'Yearly' then dateadd(year, -@PartitionsToKeep * @PartitionRangeTypeInterval, @ThisPeriod)
								end

	insert into @ret(Name, SQL)
	select 'CreatePartition', SQL 
	from z.fn_BuildQueryCreatePartitionForDateRange(null, @PartitionFunctionName, @PartitionRangeType, @PartitionRangeTypeInterval, @ThisPEriod, null, @ForwardedPartitionCount, @NextPartitionFileGroup)
	order by Ordinal

	insert into @ret(Name, SQL)
		select 'Partition Swapout Partition' + cast(a.PartitionNumber as varchar) + ':' + format(a.BoundaryDateValue, 'yyyy-MM-dd HH:mm') + ' for ' + a.SourceObject,
				' -- Swapout period ' + format(a.BoundaryDateValue, 'yyyy-MM-dd HH:mm') + '
if object_id(' + quotename(a.TargetObject, '''') + ') is not null
begin
	if not exists(select * from ' + a.TargetObject + ')
	begin
		drop table ' + a.TargetObject + '
	end
	else
	begin
		raiserror(''Table ' + a.TargetObject + ' is not empty, please remove it before partition swap-out.'', 16, 1)
		return
	end
end
exec z.usp_CopyTableSchema @FullSourceTableName = ' + quotename(a.SourceObject, '''') + ', @FullTargetTableName = ' + quotename(a.TargetObject, '''') + ', @FileGroupOrPartitionScheme = ' + quotename(a.FileGroupName, '''') + ', @DropTargetTableIfExists = 0, @CopyIdentity = 1
alter table ' + a.SourceObject + ' switch partition ' + cast(a.PartitionNumber - 1 as nvarchar(20)) + ' to ' + a.TargetObject + ';
'
			+	case 
					when @ArchivedSwappedPartitions = 1 then ''
					else 'drop table ' + a.TargetObject + ';'
				end
			+'
'
			+ case when a.rn = 1 then 
				'declare @ID' + cast(rn as varchar(max)) + ' ' + a.BoundaryValueDataType + ' = '
				+	case a.BoundaryValueDataType
						when 'bigint' then cast(a.BoundaryValue as nvarchar(100)) + ';'
						else 'convert(' + a.BoundaryValueDataType + ',' + quotename(convert(nvarchar(100), cast(a.BoundaryValue as datetime2), 121), '''') + ', 121)'
						end + '
alter partition function '+quotename(a.PartitionFunctionName)+'()   merge range (@ID' + cast(rn as varchar(max)) + ');'
					else ''
				end
		from (
				select
						quotename(object_schema_name(i.ObjectID)) + '.' + quotename(object_name(i.ObjectID)) SourceObject, 
						quotename(object_schema_name(i.ObjectID)) + '.' + quotename(object_name(i.ObjectID) + '_Partition_' + format(i.BoundaryDateValue, 'yyyyMMddHHmm')) TargetObject, 
						i.BoundaryDateValue, i.BoundaryValueDataType, i.BoundaryValue, 
						i.PartitionFunctionName, i.PartitionNumber, i.FileGroupName,
						row_number() over (partition by i.PartitionNumber order by object_schema_name(i.ObjectID) +'.' + object_name(i.ObjectID) desc ) rn
				from z.v_PartitionedIndexes i
				where i.PartitionFunctionName = @PartitionFunctionName
					and i.IndexID = 1
					and BoundaryDateValue <= @FirstPeriodToKeep
			) a
		order by a.PartitionNumber, a.SourceObject
	return
end