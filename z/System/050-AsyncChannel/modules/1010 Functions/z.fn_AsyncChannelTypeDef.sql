/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1010%20Functions/z.fn_AsyncChannelTypeDef.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.fn_AsyncChannelTypeDef.md

Type declarations used in signature comparison.
*/
create or alter function z.fn_AsyncChannelTypeDef
(
	@UserTypeID int,
	@MaxLength smallint,
	@Precision tinyint,
	@Scale tinyint
)
returns nvarchar(200)
as
begin
	declare @Name sysname = (select name from sys.types where user_type_id = @UserTypeID)
	return case
			when @Name in ('char','varchar','binary','varbinary')
				then @Name + '(' + iif(@MaxLength = -1, 'max', cast(@MaxLength as varchar(10))) + ')'
			when @Name in ('nchar','nvarchar')
				then @Name + '(' + iif(@MaxLength = -1, 'max', cast(@MaxLength / 2 as varchar(10))) + ')'
			when @Name in ('decimal','numeric')
				then @Name + '(' + cast(@Precision as varchar(10)) + ',' + cast(@Scale as varchar(10)) + ')'
			when @Name in ('datetime2','time','datetimeoffset')
				then @Name + '(' + cast(@Scale as varchar(10)) + ')'
			else @Name
		end
end
