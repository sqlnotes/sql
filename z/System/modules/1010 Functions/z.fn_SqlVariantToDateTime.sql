/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_SqlVariantToDateTime.sql
*/
create or alter function z.fn_SqlVariantToDateTime
(
	@value sql_variant
)
returns table
as
return 
(
	select 
			cast(sql_variant_property(r.value,  'BaseType') as varchar(128)) BaseDataType, 
			try_cast(
					case 
						when sql_variant_property(r.value,  'BaseType') = 'bigint' then
							(
								select cast(dateadd(second, x0.seconds % 60, dateadd(minute, cast(x0.seconds / 60 as int), '1900-01-01')) as datetime) Date
								from (select cast(r.value as bigint)/268435456 as seconds) x0
							)
						when sql_variant_property(r.value,  'BaseType') in ('uniqueidentifier') then
							null
						else
							r.value
					end 
				as datetime) as Value
	from (select @value value) r
)

