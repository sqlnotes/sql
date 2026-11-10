/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1020%20Tables/z.AsyncChannel.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannel.md

Channel configuration and processing settings.
*/
if object_id('z.AsyncChannel', 'U') is null
begin
	create table z.AsyncChannel
	(
		AsyncChannelID int not null,
		Name nvarchar(128) not null,
		Description nvarchar(256),
		ProcessingProcedure nvarchar(128) not null,
		ActivationType varchar(20) not null constraint DF_z_AsyncChannel_ActivationType default ('Auto'),
		Readers tinyint not null constraint DF_z_AsyncChannel_Readers default ((1)),
		MaxRowsPerMessage int,
		MaxMessagesPerReceive int not null constraint DF_z_AsyncChannel_MaxMessagesPerReceive default ((1500)),
		MaxIdleDurationSeconds int not null constraint DF_z_AsyncChannel_MaxIdleDurationSeconds default ((60)),
		MaxExecutionSeconds int not null constraint DF_z_AsyncChannel_MaxExecutionSeconds default ((0)),
		IsActive bit not null constraint DF_z_AsyncChannel_IsActive default ((1)),
		DebugMode bit not null constraint DF_z_AsyncChannel_DebugMode default ((0)),
		ActivatorPoolID int not null,
		RowVersion rowversion not null,
		constraint PK_z_AsyncChannel primary key clustered (AsyncChannelID),
		constraint UQ_z_AsyncChannel_Name unique nonclustered (Name),
		constraint CK_z_AsyncChannel_Name check ([Name] like '[A-Za-z]%' and not [Name] like '%[^A-Za-z0-9_]%'),
		constraint CK_z_AsyncChannel_ActivationType check ([ActivationType]='Manual' or [ActivationType]='Auto'),
		constraint CK_z_AsyncChannel_Readers check ([Readers]>=(1)),
		constraint CK_z_AsyncChannel_MaxRowsPerMessage check ([MaxRowsPerMessage] is null or [MaxRowsPerMessage]>(0)),
		constraint CK_z_AsyncChannel_MaxMessagesPerReceive check ([MaxMessagesPerReceive]>=(1)),
		constraint CK_z_AsyncChannel_MaxIdleDurationSeconds check ([MaxIdleDurationSeconds]>=(0)),
		constraint CK_z_AsyncChannel_MaxExecutionSeconds check ([MaxExecutionSeconds]>=(0))
	);
end
