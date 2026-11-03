/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_ReleaseSemaphore.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_releasesemaphore

Releases an acquired semaphore slot using the session context and application locks.
*/
create or alter procedure z.usp_ReleaseSemaphore
(
	@SemaphoreName nvarchar(200), --name of the semaphore
	@LockOwner varchar(32) = 'Transaction'
)
as
begin
	declare @ResourceInternal nvarchar(255) = cast(session_context('Semaphore-' + @SemaphoreName) as nvarchar(300))
	exec sp_releaseapplock @ResourceInternal, @LockOwner
	exec sp_releaseapplock @SemaphoreName, @LockOwner
end