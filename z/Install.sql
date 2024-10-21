set textsize 2147483647
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on
set transaction isolation level read committed
set context_info 0x446F6E742774204B696C6C
go
if schema_id('z') is null
begin
	exec('create schema z authorization z;')
end
go
if object_id('z.Systems') is null
begin
	create table z.Systems
	(
		Name nvarchar(128) not null,
		Version varchar(100) not null,
		Date datetime not null,
		constraint PK_z_SystemVersion primary key(Name, Version)
	)
end
--drop table z.SystemUpdateBatch
if object_id('z.SystemUpdateBatch') is null
begin
	create table z.SystemUpdateBatch
	(
		BatchID bigint not null identity(1,1),
		SystemName nvarchar(128) not null,
		SystemVersion varchar(100) not null,
		HasError bit not null constraint DF_z_SystemUpdateBatch_HasError default(0),
		StartDate datetime not null constraint DF_z_SystemUpdateBatch_StartDate default(getutcdate()),
		EndDate datetime,
		constraint PK_z_SystemUpdateBatch primary key(BatchID)
	)
end
if object_id('z.SystemScriptHash') is null
begin
	create table z.SystemScriptHash
	(
		SystemName nvarchar(128) not null,
		FileHash binary(64) not null,
		FileName nvarchar(max) not null,
		FileContent nvarchar(max) not null,
		CreationDate datetime not null constraint DF_z_SystemScriptHash_CreationDate default(getutcdate()),
		constraint PK_z_SystemScriptHash primary key(SystemName, FileHash)
	)
end
if object_id('z.SystemUpdateBatchLog') is null
begin
	create table z.SystemUpdateBatchLog
	(
		BatchID bigint not null,
		BatchLogID bigint not null identity(1,1), 
		FileHash binary(64) not null,
		ErrorMessage nvarchar(max),
		StartDate datetime not null constraint DF_z_SystemUpdateBatchLog_StartDate default(getutcdate()),
		EndDate datetime,
		constraint PK_z_SystemUpdateBatchLog primary key(BatchID, BatchLogID)
	)
end
go
if object_id('z.CreateDatabaseUpdateLog') is null
begin
	exec('create procedure z.CreateDatabaseUpdateLog as --')
end
go
alter procedure z.CreateDatabaseUpdateLog
(
	@BatchID bigint output, 
	@BatchLogID bigint output, 
	@SystemName nvarchar(128), 
	@SystemVersion varchar(100), 
	@FileHash binary(64),
	@FileName varchar(max) = null, 
	@FileContent nvarchar(max) = null, 
	@ErrorMessage varchar(max) = null	
)
as
begin
	set nocount on
	set xact_abort on
	declare @Date datetime = getutcdate()
	begin try
	begin tran
	if @FileContent like '%password%'
		select @FileContent = '***'

	update z.Systems
		set Version = @SystemVersion, 
			Date = @Date
	where Name = @SystemName
	
	if @BatchID = -1
	begin
		insert into z.SystemUpdateBatch(SystemName, SystemVersion, StartDate)
			values(@SystemName, @SystemVersion, @Date)
		select @BatchID = scope_identity()
	end
	if @BatchLogID = -1
	begin
		insert into z.SystemUpdateBatchLog(BatchID, FileHash, StartDate)
			values(@BatchID, @FileHash, @Date)
		select @BatchLogID = scope_identity()
	end
	else
	begin
		update z.SystemUpdateBatchLog
			set ErrorMessage = @ErrorMessage,
				EndDate = @Date
		where BatchID = @BatchID
			and BatchLogID = @BatchLogID
	
		update z.SystemUpdateBatch
			set EndDate = @Date,
				HasError =  case when nullif(ltrim(rtrim(@ErrorMessage)), '') is not null then 1 else 0 end
		where BatchID = @BatchID
	end


	if @FileContent is not null and @FileName is not null and @FileHash is not null
	begin
		;with s as
		(
			select @SystemName SystemName, @FileHash FileHash, @FileName FileName, @FileContent FileContent, @Date CreationDate
		)
		merge z.SystemScriptHash t
		using s on s.SystemName = t.SystemName and s.FileHash = t.FileHash
		when not matched then 
			insert(SystemName, FileHash, FileName, FileContent, CreationDate) 
				values(s.SystemName, s.FileHash, s.FileName, s.FileContent, s.CreationDate)
		;
	end		

___Exit___:
	commit
	select @BatchID BatchID, @BatchLogID BatchLogID
	end try
	begin catch
		if @@trancount > 0
			rollback;
		throw;
	end catch
end