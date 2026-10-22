create or alter view z.v_DatabaseBackupStatus
as
select d.database_id DatabaseID, d.name DatabaseName, d.create_date CreateDate,
	d.is_read_only IsReadOnly, d.state_desc StateDescription, b.BackupType,
	cast(case when m.MetadataStatus = 'Valid' then p.RunID end as varchar(64)) RunID,
	cast(case when m.MetadataStatus = 'Valid' then p.SettingsHash end as varchar(64)) SettingsHash,
	case when m.MetadataStatus = 'Valid' then t.SessionID end SessionID,
	case when m.MetadataStatus = 'Valid' then t.StartDate end StartDate,
	case when m.MetadataStatus = 'Valid' then t.EndDate end EndDate,
	cast(case when m.MetadataStatus <> 'Valid' then 'Unassigned'
		when t.StartDate is null then 'Pending' when t.EndDate is null then 'Started' else 'Completed' end as varchar(12)) BackupStatus,
	cast(m.MetadataStatus as varchar(12)) MetadataStatus
from sys.databases d
	cross join (values(cast('FULL' as varchar(4))), ('DIFF'), ('LOG')) b(BackupType)
	left join sys.extended_properties e on e.class = 0 and e.major_id = 0 and e.minor_id = 0
		and e.name = N'z.Backup.Work.' + convert(nvarchar(20), d.database_id) + N'.' + b.BackupType
	cross apply (select convert(nvarchar(4000), e.value) PropertyValue) r
	cross apply (select case when isjson(r.PropertyValue) = 1 then r.PropertyValue else N'{}' end JsonValue) j
	cross apply (select json_value(j.JsonValue, '$.DatabaseID') DatabaseID,
		json_value(j.JsonValue, '$.DatabaseName') DatabaseName, json_value(j.JsonValue, '$.CreateDate') CreateDate,
		json_value(j.JsonValue, '$.BackupType') BackupType, json_value(j.JsonValue, '$.RunID') RunID, json_value(j.JsonValue, '$.SettingsHash') SettingsHash, json_value(j.JsonValue, '$.SessionID') SessionID,
		json_value(j.JsonValue, '$.StartDate') StartDate, json_value(j.JsonValue, '$.EndDate') EndDate) p
	cross apply (select try_convert(int, p.DatabaseID) DatabaseID, try_convert(datetime, p.CreateDate) CreateDate,
		try_convert(int, p.SessionID) SessionID, try_convert(datetime2(7), p.StartDate) StartDate,
		try_convert(datetime2(7), p.EndDate) EndDate) t
	cross apply (select case when e.name is null then 'Missing'
		when isnull(isjson(r.PropertyValue), 0) <> 1 or t.DatabaseID is null or p.DatabaseName is null or t.CreateDate is null
			or isnull(datalength(p.RunID), 0) <> 128 or p.RunID collate Latin1_General_100_BIN2 like N'%[^0-9A-F]%'
			or isnull(datalength(p.SettingsHash), 0) <> 128 or p.SettingsHash collate Latin1_General_100_BIN2 like N'%[^0-9A-F]%'
			or p.BackupType is null or p.BackupType collate Latin1_General_100_BIN2 <> b.BackupType collate Latin1_General_100_BIN2
			or datalength(p.BackupType) <> datalength(convert(nvarchar(4), b.BackupType))
			or (p.SessionID is not null and (t.SessionID is null or t.SessionID <= 0))
			or (p.StartDate is not null and t.StartDate is null) or (p.EndDate is not null and t.EndDate is null)
			or (t.StartDate is null and (t.SessionID is not null or t.EndDate is not null))
			or (t.StartDate is not null and t.SessionID is null) or t.EndDate < t.StartDate
			or exists(select * from openjson(j.JsonValue) where
				([key] collate Latin1_General_100_BIN2 = N'DatabaseID' and [type] <> 2)
				or ([key] collate Latin1_General_100_BIN2 = N'SessionID' and [type] not in (0, 2))
				or ([key] collate Latin1_General_100_BIN2 in (N'DatabaseName', N'CreateDate', N'BackupType', N'RunID', N'SettingsHash') and [type] <> 1)
				or ([key] collate Latin1_General_100_BIN2 in (N'StartDate', N'EndDate') and [type] not in (0, 1)))
			or (select count(*) from openjson(j.JsonValue)) <> 9
			or (select count(distinct [key] collate Latin1_General_100_BIN2) from openjson(j.JsonValue)
				where [key] collate Latin1_General_100_BIN2 in (N'DatabaseID', N'DatabaseName', N'CreateDate', N'BackupType', N'RunID', N'SettingsHash', N'SessionID', N'StartDate', N'EndDate')) <> 9 then 'Invalid'
		when t.DatabaseID <> d.database_id or t.CreateDate <> d.create_date
			or p.DatabaseName collate Latin1_General_100_BIN2 <> d.name collate Latin1_General_100_BIN2
			or datalength(p.DatabaseName) <> datalength(d.name) then 'Stale' else 'Valid' end MetadataStatus) m;
go
