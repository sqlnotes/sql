create or alter procedure z.usp_TraceCollectAndClose
(
	@TraceName nvarchar(128) = null,
	@TraceID int = null,
	@MaxDurationInSec int = 2147483647,
	@TransactionDurationInSec int = 3
)
as
begin
	set nocount on
	set textsize 2147483647
	declare @SQL nvarchar(max), @ReceivingTable nvarchar(128), @ColumnName nvarchar(128), @Definition nvarchar(128),
			@StartDate datetime = getutcdate()
	declare @Traces table(TraceID int, ReceivingTable nvarchar(128))
	insert into @Traces(TraceID, ReceivingTable)
		select TraceID, ReceivingTable
		from z.v_Trace
		where (@TraceName is null or Name = @TraceName)
			and (@TraceID is null or TraceID = @TraceID)
			and Status = 'Running'
			and CreatorSessionID = @@SPID
	if @@rowcount = 0
	begin
		print 'No active trace found'
		return
	end
	begin try
	declare c cursor local static for 
		select TraceID, ReceivingTable from @Traces
	open c
	fetch next from c into @TraceID, @ReceivingTable
	while @@fetch_status = 0
	begin
		if object_id(@ReceivingTable) is null
		begin
			select @SQL = 'create table ' + @ReceivingTable + '
(
			TraceSequence bigint not null constraint ' + quotename(cast(newid()  as nvarchar(max))) + ' default (datediff_big(second, ''1900-01-01'', getutcdate()) * 268435456 | next value for z.SeqGeneralID),
			EventID int not null,
			EventName nvarchar(128) not null,
			constraint ' + quotename(cast(newid() as nvarchar(max))) + ' primary key (TraceSequence)  with (data_compression= page) on PS_SchemaZPartitionGeneric(TraceSequence)
) on PS_SchemaZPartitionGeneric(TraceSequence)'
			exec(@SQL)
		end
		declare c1 cursor local fast_forward for
			select ColumnName, Definition from z.v_TraceColumn order by ColumnID
		open c1
		fetch next from c1 into @ColumnName, @Definition
		while @@fetch_status = 0
		begin
			if not exists(select * from sys.columns where object_id = object_id(@ReceivingTable) and name = @ColumnName)
			begin
				select @SQL = 'alter table ' + @ReceivingTable + ' add ' + quotename(@ColumnName) + ' '  + @Definition + ' null'
				exec(@SQL)
			end
			fetch next from c1 into @ColumnName, @Definition
		end
		close c1
		deallocate c1
		exec z.usp_ForceNamingConvention @ReceivingTable
		fetch next from c into @TraceID, @ReceivingTable
	end
	close c
	deallocate c
	select @SQL= 'declare @EndDate datetime = dateadd(second, @TransactionDurationInSec, getutcdate()), @EventCount int = 100, @EventID int, @EventName nvarchar(128),@ColumnID int, @Data varbinary(max), @Length bigint, @TraceSequence bigint'
			+ (
					select ', @C' + cast(ColumnID as nvarchar(max)) + ' ' + Definition
					from z.v_TraceColumn tc
					order by ColumnID
					for xml path(''), type
			).value('.', 'nvarchar(max)') +'
declare @Buffer table(ColumnID int, Length int, Data varbinary(max))
while getutcdate() <= @EndDate
begin
	if @EventCount = 0
		waitfor delay ''00:00:00.010''
	select @EventCount = 0'
	+(
		select '
	select @EventID = null, @EventName = null'+ (
				select ', @C' + cast(ColumnID as nvarchar(max)) + ' = null ' 
				from z.v_TraceColumn tc
				order by ColumnID
				for xml path(''), type
			).value('.', 'nvarchar(max)') + '
	delete @Buffer
	insert into @Buffer (ColumnID, Length, Data)
		exec sp_trace_getdata ' + cast(TraceID as nvarchar(max)) + ', 1
	if @@rowcount <= 2
		goto ___Next_' + cast(TraceID as nvarchar(max)) + '___

	declare b cursor static local for
		select ColumnID, Length, Data from @Buffer
	open b
	fetch next from b into @ColumnID, @Length, @Data
	while @@fetch_status = 0
	begin
		if @ColumnID = 65526
		begin
			if @EventID is null
			begin
				select @EventID = cast(cast(reverse(substring(@Data, 1, 2)) as binary(2)) as smallint)
				select @EventName = case @EventID ' + (select ' when ' + cast(TraceEventID as nvarchar(max)) + ' then ' + quotename(EventName, '''') + ' ' from z.v_TraceEvent order by TraceEventID for xml path(''), type).value('.', 'nvarchar(max)') + ' end
				if @EventName is null
					select @EventID = null
			end
		end'
		+
		(
				select '
		else if @ColumnID = ' + cast(ColumnID as nvarchar(max)) + '
		begin
			select @C' + cast(ColumnID as nvarchar(max)) + ' = ' 
			+
				case tc.DataType
					when 'bigint' then 'cast(cast(reverse(substring(@Data, 1, 8)) as binary(8)) as bigint)'
					when 'datetime' then 'convert(datetime, cast(Y as varchar(10)) + ''-'' + right(''00'' + cast(m as varchar(2)), 2) + ''-'' + right(''00'' + cast(d as varchar(2)), 2) + '' '' + right(''00'' + cast(HH as varchar(2)), 2) + '':'' + right(''00'' + cast(MM as varchar(2)), 2) + '':'' + right(''00'' + cast(SS as varchar(2)), 2) + ''.'' + cast(ms as varchar(3)), 121)
				from (
						select	cast(cast(reverse(substring(d, 1, 2)) as binary(2)) as smallint) Y,
								cast(cast(reverse(substring(d, 3, 2)) as binary(2)) as smallint) M,
								cast(cast(reverse(substring(d, 5, 2)) as binary(2)) as smallint) x1,
								cast(cast(reverse(substring(d, 7, 2)) as binary(2)) as smallint) D,
								cast(cast(reverse(substring(d, 9, 2)) as binary(2)) as smallint) HH,
								cast(cast(reverse(substring(d, 11, 2)) as binary(2)) as smallint) MM,
								cast(cast(reverse(substring(d, 13, 2)) as binary(2)) as smallint) SS,
								cast(cast(reverse(substring(d, 15, 2)) as binary(2)) as smallint) ms
						from (select @Data d) d
					) d'
					when 'int' then 'cast(cast(reverse(substring(@Data, 1, 4)) as binary(4)) as int)'
					else 'cast(@Data as ' + tc.Definition + ')'
				end
			+ '
		end'
				from z.v_TraceColumn tc
				order by ColumnID
				for xml path(''), type
			).value('.', 'nvarchar(max)')
		+'

		fetch next from b into @ColumnID, @Length, @Data
	end
	close b
	deallocate b
	if @EventName is not null
	begin
		select @TraceSequence = datediff_big(second, ''1900-01-01'', getutcdate()) * 268435456 | next value for z.SeqGeneralID
		insert into ' + ReceivingTable + '(TraceSequence, EventID, EventName' + (select ', ' + quotename(tc.ColumnName) from z.v_TraceColumn tc order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)') + ')
			values(@TraceSequence, @EventID, @EventName' + (select ', @C' + cast(ColumnID as nvarchar(max)) from z.v_TraceColumn tc order by ColumnID for xml path(''), type).value('.', 'nvarchar(max)') + ')
		' 
		+
			case 
				when not exists(select * from z.TraceTrigger tt where tt.TraceID = t.TraceID) then ''
				when exists(select * from z.TraceTrigger tt where tt.TraceID = t.TraceID and tt.EventName = 'all') then 'exec '+(select tt.ProcedureName from z.TraceTrigger tt where tt.TraceID = t.TraceID and tt.EventName = 'all' and object_id(tt.ProcedureName) is not null) + ' @TraceSequence'
				else 
					stuff((
							select 'else if @EventName = ' + quotename(tt.EventName, '''') + '
		begin
			exec '+tt.ProcedureName + ' @TraceSequence
		end
		'
								from z.TraceTrigger tt 
								where tt.TraceID = t.TraceID
									and object_id(tt.ProcedureName) is not null
									and EventName <> 'all'
								order by tt.EventName
								for xml path(''), type
							).value('.', 'nvarchar(max)')
							, 1, 5, '')
			end
		+'
		select @EventCount = @EventCount + 1
	end
___Next_' + cast(TraceID as nvarchar(max)) + '___:
	'
		from @Traces t
		order by TraceID
		for xml path, type
	) .value('.', 'nvarchar(max)') +'
end
	'

	select @StartDate = getutcdate()
	while(1=1)
	begin
		begin tran
		exec sp_executesql @SQL, N'@TransactionDurationInSec int', @TransactionDurationInSec
		commit

		if exists(
					select *
					from @Traces t1
						left join z.v_Trace t on t.TraceID = t1.TraceID and t.Status in ('Running') and t.ReceivingTable = t1.ReceivingTable
					where t.TraceID is null 
				)
		begin
			print 'Traces are changed or terminated by other sessions.'
			break; -- some of the traces are closed.
		end

___Next___:
		if datediff(second, @StartDate , getutcdate()) >= @MaxDurationInSec
			break
	end
	
	declare c cursor local static for
		select TraceID from @Traces
	open c
	fetch next from c into @TraceID
	while @@fetch_status = 0
	begin
		exec z.usp_TraceClose @TraceID = @TraceID
		fetch next from c into @TraceID
	end
	close c
	deallocate c
	
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end
go


