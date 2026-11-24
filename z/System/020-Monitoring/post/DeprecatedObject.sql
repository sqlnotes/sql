-- Procedures
exec z.usp_DropObject @ObjectName = N'z.usp_CheckSystemHealthTrace';
exec z.usp_DropObject @ObjectName = N'z.usp_CollectInfo';

-- Views
exec z.usp_DropObject @ObjectName = N'z.v_IndexSpaceUsage';
exec z.usp_DropObject @ObjectName = N'z.v_ObjectSpaceUsage';
