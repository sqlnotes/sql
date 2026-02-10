create or alter procedure z.usp_CollectInfo
as
begin
	exec z.usp_CheckSystemHealthTrace
	exec z.usp_TakeSnapshotActiveSessions
end