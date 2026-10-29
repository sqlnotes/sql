create or alter procedure z.usp_TakeSnapshotActiveSessions
as
begin
      set nocount, xact_abort on
      insert into z.ActiveSessions(SessionID, StartDate, BlockerSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, ExecutingManagedCode, MaxVersionTraversed, AverageVersionChainTraversed, TranDurationInSecond, LoginName, HostName, HostAddress, ApplicationName, BlockerLoginName, BlockerHostName, BlockerAddress, BlockerApplicationName, BlockerQuery, BlockerLastExecutedCommand)
            select  SessionID, StartDate, BlockerSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, [RowCount], OpenTranCount, TransactionIsolationLevel, ExecutingManagedCode, MaxVersionTraversed, AverageVersionChainTraversed, TranDurationInSecond, LoginName, HostName, HostAddress, ApplicationName, BlockerLoginName, BlockerHostName, BlockerAddress, BlockerApplicationName, BlockerQuery, BlockerLastExecutedCommand
            from z.v_ActiveSessions           
end
