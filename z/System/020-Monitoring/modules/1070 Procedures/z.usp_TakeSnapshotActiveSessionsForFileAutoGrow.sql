/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/modules/1070%20Procedures/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Monitoring/docs/reference/z.usp_TakeSnapshotActiveSessionsForFileAutoGrow.md

Stores active-request snapshots correlated with a file-growth trace event.
*/
create or alter procedure z.usp_TakeSnapshotActiveSessionsForFileAutoGrow
(  
 @TraceSequence bigint,  
 @TraceID int = null,  
 @EventName nvarchar(128) = null  
)  
as  
begin  
    set nocount, xact_abort on  
    set transaction isolation level read uncommitted  
    
    insert into z.TraceFileAutoGrowActiveSessions(TraceSequence, SessionID, StartDate, BlockerSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, ExecutingManagedCode, MaxVersionTraversed, AverageVersionChainTraversed, TranDurationInSecond, LoginName, HostName, HostAddress, ApplicationName, BlockerLoginName, BlockerHostName, BlockerAddress, BlockerApplicationName, BlockerQuery, BlockerLastExecutedCommand)
        select  @TraceSequence, SessionID, StartDate, BlockerSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, ExecutingManagedCode, MaxVersionTraversed, AverageVersionChainTraversed, TranDurationInSecond, LoginName, HostName, HostAddress, ApplicationName, BlockerLoginName, BlockerHostName, BlockerAddress, BlockerApplicationName, BlockerQuery, BlockerLastExecutedCommand
        from z.v_ActiveSessionsNoPlan
end
