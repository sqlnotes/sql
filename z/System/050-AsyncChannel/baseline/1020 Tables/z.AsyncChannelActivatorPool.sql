/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/baseline/1020%20Tables/z.AsyncChannelActivatorPool.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelActivatorPool.md

Shared concurrency limits and pool wait settings.
*/
if object_id('z.AsyncChannelActivatorPool', 'U') is null
begin
	create table z.AsyncChannelActivatorPool
	(
		ActivatorPoolID int not null,
		Name nvarchar(128) not null,
		Description nvarchar(256),
		MaxConcurrency tinyint not null,
		TimeoutSeconds int not null constraint DF_z_AsyncChannelActivatorPool_TimeoutSeconds default ((300)),
		IsActive bit not null constraint DF_z_AsyncChannelActivatorPool_IsActive default ((1)),
		RowVersion rowversion not null,
		constraint PK_z_AsyncChannelActivatorPool primary key clustered (ActivatorPoolID),
		constraint UQ_z_AsyncChannelActivatorPool_Name unique nonclustered (Name),
		constraint CK_z_AsyncChannelActivatorPool_MaxConcurrency check ([MaxConcurrency]>=(0)),
		constraint CK_z_AsyncChannelActivatorPool_WaitTimeoutSeconds check ([TimeoutSeconds]=(-1) or [TimeoutSeconds]>=(1))
	);
end
