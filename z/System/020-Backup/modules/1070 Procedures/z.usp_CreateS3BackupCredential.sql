create or alter procedure z.usp_CreateS3BackupCredential
(
	@CredentialUrl nvarchar(4000),
	@AccessKeyId nvarchar(4000),
	@SecretAccessKey nvarchar(4000),
	@ReplaceExisting bit = 0
)
as
begin
	set nocount, xact_abort on;
	declare @Sql nvarchar(max), @Secret nvarchar(max), @CredentialExists bit;

	if convert(int, serverproperty('ProductMajorVersion')) < 16
		throw 50000, 'S3 backup credentials require SQL Server 2022 or later.', 1;
	if @CredentialUrl is null or left(@CredentialUrl, 5) collate Latin1_General_100_BIN2 <> N's3://'
		throw 50000, 'CredentialUrl must begin with s3://.', 1;
	while right(@CredentialUrl, 1) = N'/' and len(@CredentialUrl) > 5
		select @CredentialUrl = left(@CredentialUrl, len(@CredentialUrl) - 1);
	if len(@CredentialUrl) <= 5 or substring(@CredentialUrl, 6, 1) = N'/'
		or datalength(@CredentialUrl) > 256
		or charindex(N'?', @CredentialUrl) > 0 or charindex(N'#', @CredentialUrl) > 0
		or charindex(N'\', @CredentialUrl) > 0 or charindex(N' ', @CredentialUrl) > 0
		or charindex(nchar(9), @CredentialUrl) > 0 or charindex(nchar(10), @CredentialUrl) > 0
		or charindex(nchar(13), @CredentialUrl) > 0
		throw 50000, 'CredentialUrl must be an S3 prefix of at most 128 UTF-16 code units without whitespace, query or fragment.', 1;
	if nullif(trim(@AccessKeyId), N'') is null or nullif(trim(@SecretAccessKey), N'') is null
		or charindex(N':', @AccessKeyId) > 0 or charindex(N':', @SecretAccessKey) > 0
		throw 50000, 'AccessKeyId and SecretAccessKey are required and cannot contain a colon.', 1;
	select @Secret = convert(nvarchar(max), @AccessKeyId) + N':' + @SecretAccessKey;
	if datalength(@Secret) > 8000
		throw 50000, 'The combined access key and secret exceed the credential secret limit.', 1;
	if @ReplaceExisting is null
		throw 50000, 'ReplaceExisting cannot be null.', 1;

	select @CredentialExists = iif(exists(select 1 from sys.credentials where name = @CredentialUrl), 1, 0);
	if @CredentialExists = 1 and @ReplaceExisting = 0
		throw 50000, 'The credential already exists. Use ReplaceExisting = 1 to replace its keys.', 1;
	select @Sql = iif(@CredentialExists = 1, N'alter credential ', N'create credential ')
		+ quotename(@CredentialUrl) + N' with identity = ''S3 Access Key'', secret = N'''
		+ replace(@Secret, N'''', N'''''') + N''';';
	exec sys.sp_executesql @Sql;
end
GO
