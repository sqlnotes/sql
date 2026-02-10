create or alter procedure z.usp_TakeSnapshotActiveSessions
as
begin
      set nocount, xact_abort on
      insert into z.ActiveSessions(SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName)
            select  SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName
            from z.v_ActiveSessions           
end
