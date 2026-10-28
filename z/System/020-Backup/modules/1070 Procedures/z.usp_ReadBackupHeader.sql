create or alter procedure z.usp_ReadBackupHeader
(
	@BackupFile nvarchar(4000),
	@Position int = null,
	@HeaderJson nvarchar(max) = null output,
	@ReturnResult bit = 1
)
as
begin
	set nocount on;
	declare @Major int = try_convert(int, serverproperty('ProductMajorVersion')),
		@IsS3 bit, @IsUrl bit, @RestoreSql nvarchar(max), @Sql nvarchar(max), @Columns nvarchar(max);
	select @HeaderJson = null;
	if @Major is null or @Major not in (15, 16, 17)
		throw 50000, 'Unsupported RESTORE HEADERONLY layout. Supported SQL Server versions are 2019, 2022 and 2025.', 1;
	if nullif(trim(@BackupFile), N'') is null
		throw 50000, 'BackupFile is required.', 1;
	if @Position <= 0
		throw 50000, 'Position must be positive or null for all backup sets.', 1;
	if @ReturnResult is null
		throw 50000, 'ReturnResult cannot be null.', 1;
	select @IsS3 = iif(left(@BackupFile, 5) collate Latin1_General_100_CI_AS = N's3://', 1, 0),
		@IsUrl = iif(left(@BackupFile, 8) collate Latin1_General_100_CI_AS = N'https://'
			or left(@BackupFile, 5) collate Latin1_General_100_CI_AS = N's3://', 1, 0);
	if @IsS3 = 1 and @Major < 16
		throw 50000, 'S3 backup headers require SQL Server 2022 or later.', 1;

	create table #Header
	(
		BackupName nvarchar(128),
		BackupDescription nvarchar(255),
		BackupType smallint,
		ExpirationDate datetime,
		Compressed bit,
		Position smallint,
		DeviceType tinyint,
		UserName nvarchar(128),
		ServerName nvarchar(128),
		DatabaseName nvarchar(128),
		DatabaseVersion int,
		DatabaseCreationDate datetime,
		BackupSize numeric(20,0),
		FirstLSN numeric(25,0),
		LastLSN numeric(25,0),
		CheckpointLSN numeric(25,0),
		DatabaseBackupLSN numeric(25,0),
		BackupStartDate datetime,
		BackupFinishDate datetime,
		SortOrder smallint,
		CodePage smallint,
		UnicodeLocaleId int,
		UnicodeComparisonStyle int,
		CompatibilityLevel tinyint,
		SoftwareVendorId int,
		SoftwareVersionMajor int,
		SoftwareVersionMinor int,
		SoftwareVersionBuild int,
		MachineName nvarchar(128),
		Flags int,
		BindingID uniqueidentifier,
		RecoveryForkID uniqueidentifier,
		Collation nvarchar(128),
		FamilyGUID uniqueidentifier,
		HasBulkLoggedData bit,
		IsSnapshot bit,
		IsReadOnly bit,
		IsSingleUser bit,
		HasBackupChecksums bit,
		IsDamaged bit,
		BeginsLogChain bit,
		HasIncompleteMetaData bit,
		IsForceOffline bit,
		IsCopyOnly bit,
		FirstRecoveryForkID uniqueidentifier,
		ForkPointLSN numeric(25,0),
		RecoveryModel nvarchar(60),
		DifferentialBaseLSN numeric(25,0),
		DifferentialBaseGUID uniqueidentifier,
		BackupTypeDescription nvarchar(60),
		BackupSetGUID uniqueidentifier,
		CompressedBackupSize bigint,
		Containment tinyint,
		KeyAlgorithm nvarchar(32),
		EncryptorThumbprint varbinary(20),
		EncryptorType nvarchar(32)
	);
	-- Match the reader engine's native result before capturing it.
	if @Major in (16, 17)
		exec(N'alter table #Header add LastValidRestoreTime datetime, TimeZone nvarchar(32), CompressionAlgorithm nvarchar(32);');
	select @RestoreSql = N'restore headeronly from ' + iif(@IsUrl = 1, N'url', N'disk')
		+ N' = N''' + replace(@BackupFile, N'''', N'''''') + N''''
		+ iif(@Position is null, N'', N' with file = ' + convert(nvarchar(11), @Position)) + N';';
	insert #Header exec sys.sp_executesql @RestoreSql;
	-- Complete the stable output schema after capturing the SQL Server 2019 layout.
	if @Major = 15
		exec(N'alter table #Header add LastValidRestoreTime datetime, TimeZone nvarchar(32), CompressionAlgorithm nvarchar(32);');
	select @Columns = N'BackupName, BackupDescription, BackupType, ExpirationDate, Compressed, Position, DeviceType, UserName, ServerName, DatabaseName,
		DatabaseVersion, DatabaseCreationDate, BackupSize, FirstLSN, LastLSN, CheckpointLSN, DatabaseBackupLSN, BackupStartDate, BackupFinishDate,
		SortOrder, CodePage, UnicodeLocaleId, UnicodeComparisonStyle, CompatibilityLevel, SoftwareVendorId, SoftwareVersionMajor, SoftwareVersionMinor,
		SoftwareVersionBuild, MachineName, Flags, BindingID, RecoveryForkID, Collation, FamilyGUID, HasBulkLoggedData, IsSnapshot, IsReadOnly,
		IsSingleUser, HasBackupChecksums, IsDamaged, BeginsLogChain, HasIncompleteMetaData, IsForceOffline, IsCopyOnly, FirstRecoveryForkID,
		ForkPointLSN, RecoveryModel, DifferentialBaseLSN, DifferentialBaseGUID, BackupTypeDescription, BackupSetGUID, CompressedBackupSize, Containment,
		KeyAlgorithm, EncryptorThumbprint, EncryptorType, LastValidRestoreTime, TimeZone, CompressionAlgorithm';
	-- Compile the projection only after the version-specific schema changes.
	select @Sql = N'select @Json = (select ' + @Columns + N' from #Header order by Position for json path, include_null_values);'
		+ iif(@ReturnResult = 1, N'select ' + @Columns + N' from #Header order by Position;', N'');
	exec sys.sp_executesql @Sql, N'@Json nvarchar(max) output', @Json = @HeaderJson output;
end
GO
