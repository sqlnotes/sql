create or alter function z.fn_DecodeBackupFileList
(
	@FileListJson nvarchar(max)
)
returns table
as
return
(
	-- JSON comes from the corresponding reader; binary properties are base64.
	select j.LogicalName,
		j.PhysicalName,
		j.Type,
		j.FileGroupName,
		j.Size,
		j.MaxSize,
		j.FileID,
		j.CreateLSN,
		j.DropLSN,
		j.UniqueID,
		j.ReadOnlyLSN,
		j.ReadWriteLSN,
		j.BackupSizeInBytes,
		j.SourceBlockSize,
		j.FileGroupID,
		j.LogGroupGUID,
		j.DifferentialBaseLSN,
		j.DifferentialBaseGUID,
		j.IsReadOnly,
		j.IsPresent,
		case when j.TDEThumbprint is null then null else x.XmlValue.value('xs:base64Binary(sql:column("j.TDEThumbprint"))', 'varbinary(32)') end TDEThumbprint,
		j.SnapshotURL
	from openjson(@FileListJson)
	with
	(
		LogicalName nvarchar(128),
		PhysicalName nvarchar(260),
		Type char(1),
		FileGroupName nvarchar(128),
		Size numeric(20,0),
		MaxSize numeric(20,0),
		FileID bigint,
		CreateLSN numeric(25,0),
		DropLSN numeric(25,0),
		UniqueID uniqueidentifier,
		ReadOnlyLSN numeric(25,0),
		ReadWriteLSN numeric(25,0),
		BackupSizeInBytes bigint,
		SourceBlockSize int,
		FileGroupID int,
		LogGroupGUID uniqueidentifier,
		DifferentialBaseLSN numeric(25,0),
		DifferentialBaseGUID uniqueidentifier,
		IsReadOnly bit,
		IsPresent bit,
		TDEThumbprint nvarchar(max),
		SnapshotURL nvarchar(360)
	) j
		 cross apply (values(convert(xml, N''))) x(XmlValue)
);
GO
