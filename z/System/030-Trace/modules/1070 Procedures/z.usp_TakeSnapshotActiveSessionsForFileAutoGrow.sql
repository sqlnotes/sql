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
    
    insert into z.TraceFileAutoGrowActiveSessions(TraceSequence, SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName)  
        select  @TraceSequence, SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, /*QueryPlan,*/ GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName  
        from z.v_ActiveSessions  
end
