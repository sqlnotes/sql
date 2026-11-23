/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1070%20Procedures/z.usp_ExecuteProcedures.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/procedures.md#zusp_executeprocedures

Executes matching procedures once per scan, skipping procedures held by another worker.
*/
create or alter procedure z.usp_ExecuteProcedures
(
	@SchemaName nvarchar(128),
	@NamePattern nvarchar(1024),
	@ExcludedProcedureNames nvarchar(max) = null
)
as
begin
	set nocount, xact_abort on;
	set cursor_close_on_commit off;
	declare	@ProcedureName nvarchar(517), @ObjectID int, @SemaphoreName nvarchar(200),
			@Result int, @Messages nvarchar(max) = N'', @Message nvarchar(2048);
	declare @ExcludedProcedures table (ProcedureName nvarchar(max));
	insert @ExcludedProcedures(ProcedureName)
		select trim(value)
		from string_split(@ExcludedProcedureNames, N',');

	declare cProcedures cursor local forward_only static read_only for
		select	quotename(schema_name(p.schema_id)) + N'.' + quotename(p.name), p.object_id
		from sys.procedures p
		where (@SchemaName is null or p.schema_id = schema_id(@SchemaName))
			and p.name like @NamePattern escape N'!'
			and p.object_id <> @@procid
			and not exists (select 1 from @ExcludedProcedures e where e.ProcedureName = p.name)
		order by schema_name(p.schema_id), p.name;
	open cProcedures;
	fetch next from cProcedures into @ProcedureName, @ObjectID;
	while @@fetch_status = 0
	begin
		select	@SemaphoreName = N'z.ExecuteProcedures:' + convert(nvarchar(11), @ObjectID);
		begin try
			exec @Result = z.usp_AcquireSemaphore @SemaphoreName = @SemaphoreName, @TotalCount = 1, @LockOwner = 'Session', @LockTimeout = 0;
			if @Result > 0
			begin
				exec @ProcedureName;
				exec @Result = z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1;
			end
		end try
		begin catch
			select	@Messages =		@Messages + nchar(13) + nchar(10) 
								+ N'Exception while executing ' + @ProcedureName + N':' + nchar(13) + nchar(10) 
								+ z.fn_GetFullErrorMessage() + nchar(13) + nchar(10);
			if @@trancount > 0
				rollback;
			exec z.usp_ReleaseSemaphore @SemaphoreName = @SemaphoreName, @SuppressException = 1;
		end catch;
		fetch next from cProcedures into @ProcedureName, @ObjectID;
	end;
	close cProcedures;
	deallocate cProcedures;
	if @Messages <> N''
	begin
		select	@Message = left(@Messages, 2048);
		throw 50000, @Message, 1;
	end;
end;
