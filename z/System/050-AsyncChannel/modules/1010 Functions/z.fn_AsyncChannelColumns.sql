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
	select	c.column_id,
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
		inner join sys.types t on t.user_type_id = c.user_type_id
		cross apply (
			select	Category =
					case	when t.name in ('geometry','geography','hierarchyid') then 'clr'
						 when t.name = 'xml' then 'xml'
						 when t.name = 'sql_variant' then 'variant'
						 else 'native' end
			) cat
		cross apply (
			select	TypeName =
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
			select	Sql = replace((
					select	string_agg(cast(N'when ''' + bt + N''' then cast(' + expr + N' as sql_variant)' as nvarchar(max)), N' ')
					from (values
						 ('bit',N'cast(o.[~_v] as bit)'),('tinyint',N'cast(o.[~_v] as tinyint)'),('smallint',N'cast(o.[~_v] as smallint)'),('int',N'cast(o.[~_v] as int)'),('bigint',N'cast(o.[~_v] as bigint)'),
						 ('decimal',N'cast(o.[~_v] as decimal(38,10))'),('numeric',N'cast(o.[~_v] as decimal(38,10))'),('money',N'cast(o.[~_v] as money)'),('smallmoney',N'cast(o.[~_v] as smallmoney)'),
						 ('float',N'cast(o.[~_v] as float)'),('real',N'cast(o.[~_v] as real)'),
						 ('date',N'cast(o.[~_v] as date)'),('time',N'cast(o.[~_v] as time)'),('datetime',N'cast(o.[~_v] as datetime)'),('datetime2',N'cast(o.[~_v] as datetime2)'),('smalldatetime',N'cast(o.[~_v] as smalldatetime)'),('datetimeoffset',N'cast(o.[~_v] as datetimeoffset)'),
						 ('uniqueidentifier',N'cast(o.[~_v] as uniqueidentifier)'),
						 ('binary',N'(select v from openjson(N''["'' + o.[~_v] + N''"]'') with (v varbinary(8000) ''$''))'),('varbinary',N'(select v from openjson(N''["'' + o.[~_v] + N''"]'') with (v varbinary(8000) ''$''))'),
						 ('char',N'cast(o.[~_v] as varchar(8000))'),('varchar',N'cast(o.[~_v] as varchar(8000))'),('nchar',N'cast(o.[~_v] as nvarchar(4000))'),('nvarchar',N'cast(o.[~_v] as nvarchar(4000))')
					 ) v(bt, expr)
					), N'~', c.name)
			) vcase
	where c.object_id = @ObjectID
