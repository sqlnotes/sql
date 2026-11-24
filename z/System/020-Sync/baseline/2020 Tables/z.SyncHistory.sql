if object_id('z.SyncHistory', 'U') is null
begin
	create table z.SyncHistory
	(
		SyncHistoryID bigint identity(1,1) not null,
		ConfigID int not null,
		FromValue sql_variant,
		ToValue sql_variant,
		FromValueAdjusted sql_variant,
		ToValueAdjusted sql_variant,
		BatchCount int not null,
		TotalRows bigint not null,
		StartDate datetime2(7) not null,
		EndDate datetime2(7) not null,
		ApplicationName varchar(128),
		LoginName varchar(128),
		RowVersion rowversion not null,
		constraint PK_z_SyncHistory primary key clustered (SyncHistoryID),
		index IX_z_SyncHistory_RowVersion nonclustered (RowVersion),
		index IX_z_SyncHistory_ConfigID nonclustered (ConfigID)
	);
end
go
