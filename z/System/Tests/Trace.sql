if object_id('z.v_TraceMetaData') is null
begin
	raiserror('Trace Test: Could not find z.v_TraceMetaData', 16, 1)
end

if not exists(
				select *
				from z.v_TraceDefinition
				where TraceID = 1 -- System trace
					and IsEventSelected = 1
			)
begin
	raiserror('Trace Test: Could not find system trace', 16, 1)
end
go
declare @TraceID int
exec z.usp_TraceCreate @TraceName = 'SchemazTestTrace', @Description = 'SchemazTestTrace Description', @ReceivingTable = null, @TraceID = @TraceID output
if not exists(
				select * 
				from z.v_Trace
				where TraceID = @TraceID 
					and Name = 'SchemazTestTrace' 
					and Description = 'SchemazTestTrace Description'
					and CreatorSessionID = @@spid
			)
	raiserror('Trace Test 100 failed', 16, 1)

if not exists(select * from sys.traces where id = @TraceID)
	raiserror('Trace Test 101 failed', 16, 1)
exec z.usp_TraceClose

if exists(select * from sys.traces where id = @TraceID)
	raiserror('Trace Test 201 failed', 16, 1)
if exists(select * from z.Trace where TraceID = @TraceID)
	raiserror('Trace Test 202 failed', 16, 1)
go
declare @TraceID int
exec z.usp_TraceCreate @TraceName = 'SchemazTestTrace', @Description = 'SchemazTestTrace Description', @ReceivingTable = null, @TraceID = @TraceID output
exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
if exists(select * from sys.traces where id = @TraceID)
	raiserror('Trace Test 301 failed', 16, 1)
if exists(select * from z.Trace where TraceID = @TraceID)
	raiserror('Trace Test 302 failed', 16, 1)
go
declare @TraceID int
exec z.usp_TraceCreate @TraceName = 'SchemazTestTrace', @Description = 'SchemazTestTrace Description', @ReceivingTable = null, @TraceID = @TraceID output
exec z.usp_TraceAddEvents	@TraceName = 'SchemazTestTrace', 
							@TraceEventQuery = 'select TraceEventID from z.v_TraceEvent where TraceEventID in (10, 11, 12)', @EventList = 'SQL:BatchStarting',
							@TraceEventColumnQuery = 'select ColumnID from z.v_TraceColumn where ColumnID in(1,3, 12)', @EventColumnList = 'ApplicationName, LoginName,DatabaseName'
if(
	select count(*) 
	from z.v_TraceDefinition 
	where TraceID = @TraceID 
		and IsEventSelected = 1
		and EventName in ('RPC:Completed', 'RPC:Starting', 'SQL:BatchCompleted', 'SQL:BatchStarting')
	) <> 4
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 303 failed', 16, 1)
end
exec z.usp_TraceAddFilter @TraceName = 'SchemazTestTrace', @ColumnName = 'SPID', @ComparisonOperator = '=', @Value = @@spid
if(
		select count(*)
		from z.v_TraceDefinition 
		where TraceID = @TraceID 
			and IsEventSelected = 1
			and EventName in ('RPC:Completed', 'RPC:Starting', 'SQL:BatchCompleted', 'SQL:BatchStarting')
			and SPID = ' and (SPID = ' + cast(@@spid as varchar(20)) + ')'
		) <> 4
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 304 failed', 16, 1)
end

exec z.usp_TraceAddColumns @TraceName = 'SchemazTestTrace', @EventColumnList = 'Duration'

if (
		select count(*)
		from z.v_TraceDefinition 
		where TraceID = @TraceID 
			and IsEventSelected = 1
			and EventName in ('RPC:Completed', 'RPC:Starting', 'SQL:BatchCompleted', 'SQL:BatchStarting')
			and SPID = ' and (SPID = ' + cast(@@spid as varchar(20)) + ')'
			and Duration is not null
		) <> 2
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 305 failed', 16, 1)
end


exec z.usp_TraceRemoveColumns @TraceName = 'SchemazTestTrace', @EventColumnList = 'Duration'

if exists(
		select *
		from z.v_TraceDefinition 
		where TraceID = @TraceID 
			and IsEventSelected = 1
			and EventName in ('RPC:Completed', 'RPC:Starting', 'SQL:BatchCompleted', 'SQL:BatchStarting')
			and SPID = ' and (SPID = ' + cast(@@spid as varchar(20)) + ')'
			and Duration is not null
		)
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 306 failed', 16, 1)
end


exec z.usp_TraceAddColumns @TraceName = 'SchemazTestTrace', @EventColumnList = 'Duration' -- add it back

exec z.usp_TraceRemoveEvents @TraceName = 'SchemazTestTrace', @EventList = 'SQL:BatchStarting'

if (
		select count(*)
		from z.v_TraceDefinition 
		where TraceID = @TraceID 
			and IsEventSelected = 1
			and EventName in ('RPC:Completed', 'RPC:Starting', 'SQL:BatchCompleted', 'SQL:BatchStarting')
			and SPID = ' and (SPID = ' + cast(@@spid as varchar(20)) + ')'
		) <> 3
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 307 failed', 16, 1)
end

if (select count(*) from z.fn_BuildQueryCreateTrace(@TraceID)) <> 5
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 410 failed', 16, 1)
end


exec z.usp_TraceStart @TraceName = 'SchemazTestTrace'
if not exists(select * from z.v_Trace where Name = 'SchemazTestTrace' and Status = 'Running')
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 308 failed', 16, 1)
end

exec z.usp_TraceStop @TraceName = 'SchemazTestTrace'
if not exists(select * from z.v_Trace where Name = 'SchemazTestTrace' and Status = 'Stopped')
begin
	exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
	raiserror('Trace Test 309 failed', 16, 1)
end

exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
go

declare @TraceID int, @SQL nvarchar(max)
exec z.usp_TraceCreate @TraceName = 'SchemazTestTrace', @Description = 'SchemazTestTrace Description', @ReceivingTable = null, @TraceID = @TraceID output
select @SQL = 'if not exists(select * from ' + ReceivingTable +' where SPID = ' + cast(@@spid as varchar(max)) + ')
	raiserror(''Trace Test 400 failed'', 16, 1)'
	
from z.v_Trace
where Name = 'SchemazTestTrace'

if object_id('z.Trace_SchemazTestTrace') is not null
	drop table z.Trace_SchemazTestTrace

exec z.usp_TraceAddEvents	@TraceName = 'SchemazTestTrace', 
							@EventList = 'SQL:BatchCompleted, SQL:BatchStarting, SQL:StmtCompleted, SQL:StmtRecompile, SQL:StmtStarting, SP:CacheHit, SP:CacheInsert, SP:CacheMiss, SP:CacheRemove, SP:Completed, SP:Recompile,SP:Starting, SP:StmtCompleted, SP:StmtStarting',
							@EventColumnList = 'TextData, DatabaseID, SPID, ApplicationName, LoginName,DatabaseName'
exec z.usp_TraceAddFilter @TraceName = 'SchemazTestTrace', @ColumnName = 'SPID', @ComparisonOperator = '=', @Value = @@spid
exec z.usp_TraceStart @TraceName = 'SchemazTestTrace'

exec z.usp_TraceCollectAndClose @TraceName = 'SchemazTestTrace', @MaxDurationInSec = 1


exec(@SQL)

exec z.usp_TraceClose @TraceName = 'SchemazTestTrace'
go
if not exists(select * from z.v_PartitionedIndexes where ObjectName = 'Trace_SchemazTestTrace' and SchemaName = 'z' and Rows > 0)
begin
	drop table z.Trace_SchemazTestTrace
	raiserror('Trace Test 420 failed', 16, 1)
end
if object_id('z.Trace_SchemazTestTrace') is not null
	drop table z.Trace_SchemazTestTrace

