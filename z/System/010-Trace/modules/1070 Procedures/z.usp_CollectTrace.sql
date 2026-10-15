create or alter procedure z.usp_CollectTrace
as
begin
	set nocount on
	declare @TraceID int, @TraceName nvarchar(128) = 'BlockedProcessReport'

	exec z.usp_TraceStop @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceClose @TraceName = @TraceName, @CurrentSessionOnly = 0

	exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect blocking information', @ReceivingTable = 'z.TraceBlockedProcessReport', @TraceID = @TraceID output
	exec z.usp_TraceAddEvents	@TraceName = @TraceName,
								@EventList = 'Blocked process report',
								@EventColumnList = 'TextData,DatabaseID,TransactionID,SPID,Duration,StartTime, EndTime,ObjectID,IndexID,EventClass,Mode,LoginSid,EventSequence,IsSystem,SessionLoginName'
	 exec z.usp_TraceAddFilter	@TraceName = 'BlockedProcessReport',
								@ColumnName = 'SPID',
								@LogicOperator = 'and',
								@ComparisonOperator = '<>',
								@Value = @@spid
	if not exists(select* from z.TraceTrigger where TraceID = @TraceID and EventName = 'all')
	begin
		insert into z.TraceTrigger(TraceID, EventName, ProcedureName)
			values(@TraceID, 'all', 'z.usp_TakeSnapshotActiveSessionsForBlockedProcessReport')
	end
	exec z.usp_TraceStart @TraceName = @TraceName


	select @TraceName = 'LongRunningQueryTrace'
	exec z.usp_TraceStop @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceClose @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect long running queries', @ReceivingTable = 'z.TraceLongRunningQuery', @TraceID = @TraceID output
	exec z.usp_TraceAddEvents	@TraceName = @TraceName,
								@EventList = 'SQL:BatchCompleted,SQL:StmtCompleted,RPC:Completed,SP:CompletedSP:StmtCompleted',
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
	exec z.usp_TraceStop @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceClose @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect exceptions', @ReceivingTable = 'z.TraceError', @TraceID = @TraceID output
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
	exec z.usp_TraceStop @TraceName = @TraceName, @CurrentSessionOnly = 0
	exec z.usp_TraceClose @TraceName = @TraceName, @CurrentSessionOnly = 0

	exec z.usp_TraceCreate @TraceName = @TraceName, @Description = 'Collect database file auto growth information ', @ReceivingTable = 'z.TraceFileAutoGrow', @TraceID = @TraceID output
	exec z.usp_TraceAddEvents	@TraceName = @TraceName,
								@EventList = 'Data File Auto Grow,Log File Auto Grow',
								@EventColumnList = 'DatabaseID,NTDomainName,HostName,ClientProcessID,ApplicationName,LoginName,SPID,Duration,StartTime,EndTime,IntegerData,ServerName,EventClass,DatabaseName,FileName,LoginSid,EventSequence,IsSystem,SessionLoginName'
	 
	if not exists(select* from z.TraceTrigger where TraceID = @TraceID and EventName = 'all')
	begin
		insert into z.TraceTrigger(TraceID, EventName, ProcedureName)
			values(@TraceID, 'all', 'z.usp_TakeSnapshotActiveSessionsForFileAutoGrow')
	end
	exec z.usp_TraceStart @TraceName = @TraceName

	exec z.usp_TraceCollectAndClose --@MaxDurationInSec = 120
end
