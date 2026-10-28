create or alter procedure z.usp_ReadBackupFileList
(
	@BackupFile nvarchar(4000),
	@Position int = 1,
	@FileListJson nvarchar(max) = null output,
	@ReturnResult bit = 1
)
as
begin
	set nocount on;
	declare @Major int = try_convert(int, serverproperty('ProductMajorVersion')),
		@IsS3 bit, @IsUrl bit, @RestoreSql nvarchar(max);
	select @FileListJson = null;
	if @Major is null or @Major not in (15, 16, 17)
		throw 50000, 'Unsupported RESTORE FILELISTONLY layout. Supported SQL Server versions are 2019, 2022 and 2025.', 1;
	if nullif(trim(@BackupFile), N'') is null
		throw 50000, 'BackupFile is required.', 1;
	if @Position is null or @Position <= 0
		throw 50000, 'Position must be positive.', 1;
	if @ReturnResult is null
		throw 50000, 'ReturnResult cannot be null.', 1;
	select @IsS3 = iif(left(@BackupFile, 5) collate Latin1_General_100_CI_AS = N's3://', 1, 0),
		@IsUrl = iif(left(@BackupFile, 8) collate Latin1_General_100_CI_AS = N'https://'
			or left(@BackupFile, 5) collate Latin1_General_100_CI_AS = N's3://', 1, 0);
	if @IsS3 = 1 and @Major < 16
		throw 50000, 'S3 backup file lists require SQL Server 2022 or later.', 1;

	create table #FileList
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
		TDEThumbprint varbinary(32),
		SnapshotURL nvarchar(360)
	);
	select @RestoreSql = N'restore filelistonly from ' + iif(@IsUrl = 1, N'url', N'disk')
		+ N' = N''' + replace(@BackupFile, N'''', N'''''') + N''' with file = '
		+ convert(nvarchar(11), @Position) + N';';
	insert #FileList exec sys.sp_executesql @RestoreSql;
	select @FileListJson = (select LogicalName, PhysicalName, Type, FileGroupName, Size, MaxSize, FileID, CreateLSN, DropLSN, UniqueID, ReadOnlyLSN, ReadWriteLSN, BackupSizeInBytes, SourceBlockSize, FileGroupID, LogGroupGUID, DifferentialBaseLSN, DifferentialBaseGUID, IsReadOnly, IsPresent, TDEThumbprint, SnapshotURL from #FileList order by FileID for json path, include_null_values);
	if @ReturnResult = 1
		select LogicalName, PhysicalName, Type, FileGroupName, Size, MaxSize, FileID, CreateLSN, DropLSN, UniqueID, ReadOnlyLSN, ReadWriteLSN, BackupSizeInBytes, SourceBlockSize, FileGroupID, LogGroupGUID, DifferentialBaseLSN, DifferentialBaseGUID, IsReadOnly, IsPresent, TDEThumbprint, SnapshotURL from #FileList order by FileID;
end
GO
