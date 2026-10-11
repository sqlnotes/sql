exec z.usp_TraceRefreshMetaData;
go
exec z.usp_DataInitializationMaster;
go
exec z.usp_ForceNamingConvention;
go
drop procedure if exists z.usp_DatabaseBackup