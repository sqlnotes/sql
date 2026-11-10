/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/modules/1070%20Procedures/z.usp_CollectTrace.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/z.usp_CollectTrace.md

Configures and collects the framework's blocked-process, long-query, error and file-growth trace
presets.
*/
create or alter procedure z.usp_CollectTrace
(
	@TransactionDurationInSec int = 5
)
as
begin
	set nocount on;
	if @TransactionDurationInSec is null or @TransactionDurationInSec < 1
		throw 50000, N'Transaction duration must be positive.', 1;
	declare @TraceID int, @TraceName nvarchar(128) = N'BlockedProcessReport',
		@OwnerLoginTime datetime = (select login_time from sys.dm_exec_sessions where session_id = @@spid);
	declare @ExistingTraces table (TraceID int not null primary key);
	declare @CreatedTraces table (TraceID int not null primary key);
	insert @ExistingTraces select TraceID from z.Trace where CreatorSessionID = @@spid and CreatorLoginTime = @OwnerLoginTime;
	begin try
		exec z.usp_TraceCleanup;
		exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect blocking information', @ReceivingTable = 'z.TraceBlockedProcessReport', @TraceID = @TraceID output
		if not exists(select 1 from @ExistingTraces where TraceID = @TraceID)
			insert @CreatedTraces values(@TraceID);
		exec z.usp_TraceAddEvents	@TraceName = @TraceName,
									@EventList = 'Blocked process report',
									@EventColumnList = 'TextData,DatabaseID,TransactionID,SPID,Duration,StartTime, EndTime,ObjectID,IndexID,EventClass,Mode,LoginSid,EventSequence,IsSystem,SessionLoginName'
		 exec z.usp_TraceAddFilter	@TraceName = 'BlockedProcessReport',
									@ColumnName = 'SPID',
									@LogicOperator = 'and',
									@ComparisonOperator = '<>',
									@Value = @@spid
		exec z.usp_TraceSetTrigger @TraceID = @TraceID, @EventName = N'all', @ProcedureName = N'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport';
		exec z.usp_TraceStart @TraceName = @TraceName


		select @TraceName = 'LongRunningQueryTrace'
		exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect long running queries', @ReceivingTable = 'z.TraceLongRunningQuery', @TraceID = @TraceID output
		if not exists(select 1 from @ExistingTraces where TraceID = @TraceID)
			insert @CreatedTraces values(@TraceID);
		exec z.usp_TraceAddEvents	@TraceName = @TraceName,
									@EventList = 'SQL:BatchCompleted,SQL:StmtCompleted,RPC:Completed,SP:Completed,SP:StmtCompleted',
									@EventColumnList = 'TextData,DatabaseID,TransactionID,LineNumber,NTUserName,NTDomainName,HostName,ClientProcessID,ApplicationName,LoginName,SPID,Duration,StartTime,EndTime,Reads,Writes,CPU,EventClass,NestLevel,Error,ObjectName,DatabaseName,LoginSid,RowCounts,RequestID,XactSequence,EventSequence,IntegerData2,IsSystem,Offset,SessionLoginName,GroupID'
		exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'SPID',
									@LogicOperator = 'and',
									@ComparisonOperator = '<>',
									@Value = @@spid
		exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'Duration',
									@LogicOperator = 'and',
									@ComparisonOperator = '>',
									@Value = 1300000
		exec z.usp_TraceStart @TraceName = @TraceName

		select @TraceName = 'TraceErrors'
		exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect exceptions', @ReceivingTable = 'z.TraceError', @TraceID = @TraceID output
		if not exists(select 1 from @ExistingTraces where TraceID = @TraceID)
			insert @CreatedTraces values(@TraceID);
		exec z.usp_TraceAddEvents	@TraceName = @TraceName,
									@EventList = 'Exception,User Error Message',
									@EventColumnList = 'TextData,DatabaseID,TransactionID,NTUserName,NTDomainName,HostName,ClientProcessID,ApplicationName,LoginName,SPID,StartTime,Severity,ServerName,EventClass,State,Error,DatabaseName,LoginSid,RequestID,XactSequence,EventSequence,IsSystem,SessionLoginName,GroupID'
		 exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'SPID',
									@LogicOperator = 'and',
									@ComparisonOperator = '<>',
									@Value = @@spid
		exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'TextData',
									@LogicOperator = 'and',
									@ComparisonOperator = 'notlike',
									@Value = N'Changed database context to%'
		exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'TextData',
									@LogicOperator = 'and',
									@ComparisonOperator = 'notlike',
									@Value = N'%Changed language setting%'
		exec z.usp_TraceAddFilter	@TraceName = @TraceName,
									@ColumnName = 'TextData',
									@LogicOperator = 'and',
									@ComparisonOperator = 'notlike',
									@Value = N'%Warning: Null value is eliminated by an aggregate or other SET operation%'


		exec z.usp_TraceStart @TraceName = @TraceName

		select @TraceName = 'FileAutoGrowTrace'
		exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect database file auto growth information ', @ReceivingTable = 'z.TraceFileAutoGrow', @TraceID = @TraceID output
		if not exists(select 1 from @ExistingTraces where TraceID = @TraceID)
			insert @CreatedTraces values(@TraceID);
		exec z.usp_TraceAddEvents	@TraceName = @TraceName,
									@EventList = 'Data File Auto Grow,Log File Auto Grow',
									@EventColumnList = 'DatabaseID,NTDomainName,HostName,ClientProcessID,ApplicationName,LoginName,SPID,Duration,StartTime,EndTime,IntegerData,ServerName,EventClass,DatabaseName,FileName,LoginSid,EventSequence,IsSystem,SessionLoginName'

		exec z.usp_TraceAddFilter @TraceName = @TraceName,
									@ColumnName = 'SPID',
									@LogicOperator = 'and',
									@ComparisonOperator = '<>',
									@Value = @@spid
		exec z.usp_TraceSetTrigger @TraceID = @TraceID, @EventName = N'all', @ProcedureName = N'z.usp_TakeSnapshotActiveSessionsForFileAutoGrow';
		exec z.usp_TraceStart @TraceName = @TraceName

		exec z.usp_TraceCollectAndClose @TransactionDurationInSec = @TransactionDurationInSec;
	end try
	begin catch
		-- Startup can fail before CollectAndClose takes responsibility for cleanup.
		declare c cursor local static read_only for select TraceID from @CreatedTraces;
		open c;
		fetch next from c into @TraceID;
		while @@fetch_status = 0
		begin
			begin try
				exec z.usp_TraceClose @TraceID = @TraceID, @ExpectedCreatorSessionID = @@spid,
					@ExpectedCreatorLoginTime = @OwnerLoginTime;
			end try
			begin catch
				print concat(N'CollectTrace cleanup failed for trace ', @TraceID, N': ', error_message());
			end catch;
			fetch next from c into @TraceID;
		end;
		close c;
		deallocate c;
		throw;
	end catch;
end;
go
