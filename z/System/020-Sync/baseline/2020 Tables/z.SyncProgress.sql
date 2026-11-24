if object_id('z.SyncProgress', 'U') is null
begin
	create table z.SyncProgress
	(
		ConfigID int not null,
		FromValue sql_variant,
		ToValue sql_variant,
		FromValueAdjusted sql_variant,
		ToValueAdjusted sql_variant,
		SessionID int not null,
		BatchCount int,
		RowsInBatch int,
		TotalRows bigint,
		BatchStartDate datetime2(7),
		BatchEndDate datetime2(7),
		StartDate datetime2(7) not null,
		EndDate datetime2(7),
		Error varchar(max),
		SyncHistoryID bigint,
		ApplicationName varchar(128),
		LoginName varchar(128),
		RowVersion rowversion not null,
		constraint PK_z_SyncProgress primary key clustered (ConfigID),
		index IX_z_SyncProgress_RowVersion nonclustered (RowVersion)
	);
end
go
