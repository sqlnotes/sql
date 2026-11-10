/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1010%20Functions/z.fn_AsyncChannelColumns.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.fn_AsyncChannelColumns.md

Interface metadata and codec generation expressions.
*/
create or alter function z.fn_AsyncChannelColumns
(
	@ObjectID int
)
returns table
as return
	select
		c.column_id,
		ColumnName    = c.name,
		Category      = cat.Category,
		TypeName      = tn.TypeName,
		ParamDecl     = N'@' + c.name + N' ' + tn.TypeName,
		QuotedName    = quotename(c.name),
		CrossApplyArg = N'i.' + quotename(c.name),
		SerializeExpr =
			case cat.Category
				when 'variant' then N'[' + c.name + N'.t] = cast(sql_variant_property(@' + c.name + N',''BaseType'') as sysname), [' + c.name + N'.v] = @' + c.name
				when 'clr'     then quotename(c.name) + N' = cast(@' + c.name + N' as varbinary(max))'
				when 'xml'     then quotename(c.name) + N' = cast(@' + c.name + N' as nvarchar(max))'
				else                quotename(c.name) + N' = @' + c.name
			end,
		OpenJsonWith =
			case cat.Category
				when 'variant' then N'[' + c.name + N'_t] sysname ''$.' + c.name + N'.t'', [' + c.name + N'_v] nvarchar(max) ''$.' + c.name + N'.v'''
				when 'clr'     then quotename(c.name) + N' varbinary(max) ''$.' + c.name + N''''
				when 'xml'     then quotename(c.name) + N' nvarchar(max) ''$.' + c.name + N''''
				else                quotename(c.name) + N' ' + tn.TypeName + N' ''$.' + c.name + N''''
			end,
		OuterSelect =
			case cat.Category
				when 'variant' then quotename(c.name) + N' = case o.[' + c.name + N'_t] ' + vcase.Sql + N' else cast(cast(o.[' + c.name + N'_v] as nvarchar(4000)) as sql_variant) end'
				when 'clr'     then quotename(c.name) + N' = cast(o.' + quotename(c.name) + N' as ' + t.name + N')'
				when 'xml'     then quotename(c.name) + N' = cast(o.' + quotename(c.name) + N' as xml)'
				else                quotename(c.name)
			end
	from sys.columns c
		join sys.types t on t.user_type_id = c.user_type_id
		cross apply (
			select Category =
				case	when t.name in ('geometry','geography','hierarchyid') then 'clr'
						when t.name = 'xml' then 'xml'
						when t.name = 'sql_variant' then 'variant'
						else 'native' end
			) cat
		cross apply (
			select TypeName =
				case	when t.name in ('char','varchar','binary','varbinary')
							then t.name + '(' + iif(c.max_length = -1, 'max', cast(c.max_length as varchar(10))) + ')'
						when t.name in ('nchar','nvarchar')
							then t.name + '(' + iif(c.max_length = -1, 'max', cast(c.max_length / 2 as varchar(10))) + ')'
						when t.name in ('decimal','numeric')
							then t.name + '(' + cast(c.precision as varchar(10)) + ',' + cast(c.scale as varchar(10)) + ')'
						when t.name in ('datetime2','time','datetimeoffset')
							then t.name + '(' + cast(c.scale as varchar(10)) + ')'
						else t.name end
			) tn
		outer apply (
			select Sql = replace((
				select string_agg(cast(N'when ''' + bt + N''' then cast(cast(o.[~_v] as ' + ct + N') as sql_variant)' as nvarchar(max)), N' ')
				from (values
						('bit','bit'),('tinyint','tinyint'),('smallint','smallint'),('int','int'),('bigint','bigint'),
						('decimal','decimal(38,10)'),('numeric','decimal(38,10)'),('money','money'),('smallmoney','smallmoney'),
						('float','float'),('real','real'),
						('date','date'),('time','time'),('datetime','datetime'),('datetime2','datetime2'),('smalldatetime','smalldatetime'),('datetimeoffset','datetimeoffset'),
						('uniqueidentifier','uniqueidentifier'),
						('char','varchar(8000)'),('varchar','varchar(8000)'),('nchar','nvarchar(4000)'),('nvarchar','nvarchar(4000)')
					) v(bt, ct)
				), N'~', c.name)
			) vcase
	where c.object_id = @ObjectID
