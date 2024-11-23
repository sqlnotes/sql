declare @msg nvarchar(128)

begin try
raiserror('This is my exception', 16, 2)
end try
begin catch
select @msg = z.fn_GetFullErrorMessage()
end catch

if @msg <> 'Msg 50000, Level 16, State 2, Line 4
This is my exception'
begin
	raiserror('Test1 z.fn_GetFullErrorMessage failed.', 16, 1)
end