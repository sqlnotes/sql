:on error exit
-- DatabaseName must be supplied by a SQLcmd-capable deployment client.
if N'$(DatabaseName)' = N'$' + N'(DatabaseName)' or nullif(N'$(DatabaseName)', N'') is null
begin
	set noexec on;
	throw 50000, 'Deploy.sql requires SQLcmd mode and a nonempty DatabaseName variable.', 1;
end
if len(N'$(DatabaseName)') > 128
begin
	set noexec on;
	throw 50001, 'DatabaseName exceeds the SQL Server identifier length.', 1;
end
go
set textsize 2147483647;
set ansi_nulls, ansi_padding, ansi_warnings, arithabort, quoted_identifier, ansi_null_dflt_on, concat_null_yields_null on;
set numeric_roundabort off;
set transaction isolation level read committed;
set context_info 0x73716C6E6F7465732E696E666F;
go
if db_id(N'$(DatabaseName)') is null
begin
	declare @Sql nvarchar(max) = N'create database ' + quotename(N'$(DatabaseName)') + N';';
	exec sys.sp_executesql @Sql;
	print N'Database ' + quotename(N'$(DatabaseName)') + N' is created.';
end
go
use [$(DatabaseName)]
go
if schema_id(N'z') is null
begin
	exec(N'create schema z authorization dbo;');
	print N'Schema z is created on database ' + quotename(db_name()) + N'.';
end
go
-- Initialize deployment metadata atomically for the current schema.
set nocount, xact_abort on;
begin try
	begin tran;
	if object_id(N'z.Systems', N'U') is null
	begin
		create table z.Systems
		(
			SystemID uniqueidentifier not null,
			CodeBase nvarchar(4000) not null,
			Version varchar(100) not null,
			Date datetime not null,
			constraint PK_z_Systems primary key(SystemID),
			constraint CK_z_Systems_SystemID check(SystemID = convert(uniqueidentifier, hashbytes('MD5', trim(lower(CodeBase)))))
		);
	end
	if object_id(N'z.SystemUpdateBatch', N'U') is null
	begin
		create table z.SystemUpdateBatch
		(
			BatchID bigint identity(1,1) not null,
			SystemID uniqueidentifier not null,
			SystemVersion varchar(100) not null,
			HasError bit not null constraint DF_z_SystemUpdateBatch_HasError default(0),
			StartDate datetime not null constraint DF_z_SystemUpdateBatch_StartDate default(getutcdate()),
			EndDate datetime,
			constraint PK_z_SystemUpdateBatch primary key(BatchID),
			constraint FK_z_SystemUpdateBatch_SystemID foreign key(SystemID) references z.Systems(SystemID)
		);
	end
	if object_id(N'z.SystemScriptHash', N'U') is null
	begin
		create table z.SystemScriptHash
		(
			ScriptHashID bigint identity(1,1) not null,
			SystemID uniqueidentifier not null,
			FileHash varbinary(32) not null,
			FileName nvarchar(max) not null,
			FileContent nvarchar(max) not null,
			CreationDate datetime not null constraint DF_z_SystemScriptHash_CreationDate default(getutcdate()),
			IsCurrent bit not null constraint DF_z_SystemScriptHash_IsCurrent default(1),
			HasSucceeded bit not null constraint DF_z_SystemScriptHash_HasSucceeded default(0),
			constraint PK_z_SystemScriptHash primary key(ScriptHashID),
			constraint CK_z_SystemScriptHash_FileHash check(datalength(FileHash) = 32),
			constraint FK_z_SystemScriptHash_SystemID foreign key(SystemID) references z.Systems(SystemID),
			index IX_z_SystemScriptHash_SystemID_FileHash unique(SystemID, FileHash)
		);
		exec sys.sp_tableoption N'z.SystemScriptHash', 'large value types out of row', 1;
	end
	if object_id(N'z.SystemUpdateBatchLog', N'U') is null
	begin
		create table z.SystemUpdateBatchLog
		(
			BatchID bigint not null,
			BatchLogID bigint identity(1,1) not null,
			SystemID uniqueidentifier not null,
			FileHash varbinary(32),
			ErrorMessage nvarchar(max),
			StartDate datetime not null constraint DF_z_SystemUpdateBatchLog_StartDate default(getutcdate()),
			EndDate datetime,
			constraint PK_z_SystemUpdateBatchLog primary key(BatchID, BatchLogID),
			constraint CK_z_SystemUpdateBatchLog_FileHash check(datalength(FileHash) = 32),
			constraint FK_z_SystemUpdateBatchLog_SystemID foreign key(SystemID) references z.Systems(SystemID),
			constraint FK_z_SystemUpdateBatchLog_BatchID foreign key(BatchID) references z.SystemUpdateBatch(BatchID),
			constraint FK_z_SystemUpdateBatchLog_SystemID_FileHash foreign key(SystemID, FileHash) references z.SystemScriptHash(SystemID, FileHash)
		);
		exec sys.sp_tableoption N'z.SystemUpdateBatchLog', 'large value types out of row', 1;
	end
	commit;
end try
begin catch
	if @@trancount > 0 rollback;
	throw;
end catch
go
create or alter procedure z.usp_CreateDatabaseUpdateLog
(
	@BatchID bigint output,
	@BatchLogID bigint output,
	@SystemID uniqueidentifier,
	@SystemVersion varchar(100) = null,
	@FileHash varbinary(32) = null,
	@FileName nvarchar(max) = null,
	@FileContent nvarchar(max) = null,
	@ErrorMessage nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	declare @Date datetime = getutcdate(), @BatchVersion varchar(100);
	select @ErrorMessage = nullif(ltrim(rtrim(@ErrorMessage)), N'');
	if @FileHash is not null and datalength(@FileHash) <> 32
		throw 50008, 'FileHash must contain a 32-byte SHA-256 digest.', 1;
	begin try
		begin tran;
		if not exists(select 1 from z.Systems where SystemID = @SystemID)
			throw 50004, 'The deployment subsystem is not registered.', 1;
		if @BatchID = -1
		begin
			if nullif(ltrim(rtrim(@SystemVersion)), '') is null
				throw 50005, 'A deployment version is required to create a batch.', 1;
			insert into z.SystemUpdateBatch(SystemID, SystemVersion, StartDate)
				values(@SystemID, @SystemVersion, @Date);
			select @BatchID = scope_identity();
		end
		select @BatchVersion = SystemVersion from z.SystemUpdateBatch with (updlock, holdlock) where BatchID = @BatchID and SystemID = @SystemID;
		if @BatchVersion is null throw 50006, 'The deployment batch is missing or belongs to another subsystem.', 1;
		if @BatchVersion = 'Test' and @FileHash is not null
			throw 50009, 'Test batches cannot register script hashes.', 1;
		if @BatchLogID = -1
		begin
			if @FileHash is not null
			begin
				if not exists(select 1 from z.SystemScriptHash with (updlock, holdlock) where SystemID = @SystemID and FileHash = @FileHash)
				begin
					if @FileName is null or @FileContent is null
						throw 50010, 'A hashed script requires its sanitized filename and content.', 1;
					insert into z.SystemScriptHash(SystemID, FileHash, FileName, FileContent, CreationDate)
						values(@SystemID, @FileHash, @FileName, @FileContent, @Date);
				end
				else
					update z.SystemScriptHash set IsCurrent = 1 where SystemID = @SystemID and FileHash = @FileHash;
			end
			insert into z.SystemUpdateBatchLog(BatchID, SystemID, FileHash, StartDate)
				values(@BatchID, @SystemID, @FileHash, @Date);
			select @BatchLogID = scope_identity();
		end
		else
		begin
			update z.SystemUpdateBatchLog
				set ErrorMessage = @ErrorMessage, EndDate = @Date, @FileHash = FileHash
			where BatchID = @BatchID and BatchLogID = @BatchLogID and SystemID = @SystemID;
			if @@rowcount = 0 throw 50007, 'The deployment log record does not exist for this subsystem and batch.', 1;
			if @ErrorMessage is null and @FileHash is not null
				update z.SystemScriptHash set HasSucceeded = 1 where SystemID = @SystemID and FileHash = @FileHash;
			update z.SystemUpdateBatch
				set HasError = case when @ErrorMessage is not null then 1 else HasError end
			where BatchID = @BatchID;
		end
		commit;
		select @BatchID BatchID, @BatchLogID BatchLogID;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
go
create or alter procedure z.usp_AcquireDeploymentLock
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	declare @Result int;
	exec @Result = sys.sp_getapplock @Resource = N'z.Deploy', @LockMode = 'Exclusive', @LockOwner = 'Session', @LockTimeout = 0;
	if @Result is null or @Result < 0 throw 51000, 'Another deployment is active or the deployment lock could not be acquired.', 1;
end
go
create or alter procedure z.usp_ReleaseDeploymentLock
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	declare @Result int;
	exec @Result = sys.sp_releaseapplock @Resource = N'z.Deploy', @LockOwner = 'Session';
	if @Result is null or @Result < 0 throw 51001, 'The deployment lock could not be released.', 1;
end
go
create or alter procedure z.usp_GetDeploymentSystems
(
	@CodeBase nvarchar(4000) = null
)
as
begin
	set nocount on;
	if @CodeBase is null
	begin
		select SystemID, CodeBase, Version from z.Systems;
	end
	else
	begin
		if nullif(trim(@CodeBase), N'') is null or datalength(@CodeBase) > 8000
			throw 51002, 'CodeBase must contain 1-4000 characters.', 1;
		declare @SystemID uniqueidentifier = convert(uniqueidentifier, hashbytes('MD5', trim(lower(@CodeBase))));
		if exists(select 1 from z.Systems where SystemID = @SystemID and trim(lower(CodeBase)) <> trim(lower(@CodeBase)))
			throw 51003, 'CodeBase identity collision.', 1;
		select SystemID, CodeBase, Version from z.Systems where SystemID = @SystemID;
	end
end
go
create or alter procedure z.usp_BeginDeployment
(
	@CodeBase nvarchar(4000),
	@Version varchar(100)
)
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	declare @BatchID bigint, @SystemID uniqueidentifier;
	if nullif(trim(@CodeBase), N'') is null or datalength(@CodeBase) > 8000 or nullif(trim(@Version), '') is null
		throw 51004, 'CodeBase must contain 1-4000 characters and a deployment version is required.', 1;
	select @SystemID = convert(uniqueidentifier, hashbytes('MD5', trim(lower(@CodeBase))));
	begin try
		begin tran;
		if exists(select 1 from z.Systems with (updlock, holdlock) where SystemID = @SystemID and trim(lower(CodeBase)) <> trim(lower(@CodeBase)))
			throw 51003, 'CodeBase identity collision.', 1;
		if not exists(select 1 from z.Systems with (updlock, holdlock) where SystemID = @SystemID)
			insert into z.Systems(SystemID, CodeBase, Version, Date) values(@SystemID, @CodeBase, '0.0.0', getutcdate());
		insert into z.SystemUpdateBatch(SystemID, SystemVersion, StartDate)
			values(@SystemID, @Version, getutcdate());
		select @BatchID = scope_identity();
		commit;
		select @BatchID BatchID, @SystemID SystemID;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
go
create or alter procedure z.usp_GetDeploymentHashes
(
	@SystemID uniqueidentifier
)
as
begin
	set nocount on;
	if not exists(select 1 from z.Systems where SystemID = @SystemID)
		throw 51005, 'The deployment subsystem is not registered.', 1;
	select FileHash, HasSucceeded from z.SystemScriptHash where SystemID = @SystemID and IsCurrent = 1;
end
go
create or alter procedure z.usp_RemoveDeploymentHash
(
	@SystemID uniqueidentifier,
	@FileHash varbinary(32)
)
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	if not exists(select 1 from z.Systems where SystemID = @SystemID) or @FileHash is null or datalength(@FileHash) <> 32
		throw 51006, 'A registered subsystem and file hash are required.', 1;
	update z.SystemScriptHash set IsCurrent = 0
	where SystemID = @SystemID and FileHash = @FileHash
		and (HasSucceeded = 0 or (replace(FileName, N'\', N'/') not like N'%/versions/%'
			and replace(FileName, N'\', N'/') not like N'%/baseline/%'));
end
go
create or alter procedure z.usp_CompleteDeployment
(
	@SystemID uniqueidentifier,
	@Version varchar(100),
	@BatchID bigint
)
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	declare @Date datetime = getutcdate();
	if @SystemID is null or nullif(trim(@Version), '') is null
		throw 51007, 'A subsystem identity and deployment version are required.', 1;
	begin try
		begin tran;
		update z.SystemUpdateBatch set EndDate = @Date
		where BatchID = @BatchID and SystemID = @SystemID and SystemVersion = @Version and HasError = 0 and EndDate is null;
		if @@rowcount = 0
			throw 51008, 'The deployment batch is missing, belongs to another subsystem/version, or is failed or completed.', 1;
		if @Version <> 'Test'
		begin
			update z.Systems set Version = @Version, Date = @Date where SystemID = @SystemID;
			if @@rowcount = 0 throw 51009, 'The deployment subsystem is not registered.', 1;
		end
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
go
create or alter procedure z.usp_FailDeployment
(
	@BatchID bigint
)
as
begin
	set nocount, xact_abort on;
	set ansi_padding, ansi_warnings, arithabort, concat_null_yields_null on;
	set numeric_roundabort off;
	begin try
		begin tran;
		update z.SystemUpdateBatch set HasError = 1, EndDate = getutcdate() where BatchID = @BatchID;
		if @@rowcount = 0 throw 51010, 'The deployment batch does not exist.', 1;
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
go
