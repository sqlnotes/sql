create or alter function z.fn_BuildQueryMergeTable
(
	@TargetTableName nvarchar(300),
	@ForceIdentityColumnInsert bit = 1,
	@PrimaryKeys nvarchar(max) = null,
	@ExcludedColumns varchar(max) = null
)
returns table
as
return
(
	with x0 as
	(
		select	object_id(@TargetTableName) ObjectID
	),
	x1 as
	(
		select	quotename(o.SchemaName) + '.' + quotename(o.ObjectName) as TargetTableName, 
				o.ColumnID, cast(o.ColumnName as nvarchar(max)) ColumnName,
				case 
					when @PrimaryKeys is null then o.PrimaryKeyOrder
					when @PrimaryKeys is not null and pk.ColumnName is not null then o.ColumnID 
					else 0
				end PrimaryKeyOrder, 
				o.DataType, o.IsNullable, o.ReadOnly, cast(o.IsIdentity as int) IsIdentity,
				case when o.IsIdentity = 0 then cast(o.ColumnName as nvarchar(max)) end ColumnNameExcludeIdentity,
				o.SystemType
		from x0
			inner join z.v_Objects o on o.ObjectID = x0.ObjectID
			left join (
							select distinct nullif(ltrim(rtrim(s.value)), '') ColumnName
							from string_split(@PrimaryKeys, ',') s
						) pk on pk.ColumnName = o.ColumnName
		where not exists(
							select *
							from string_split(@ExcludedColumns, ',') s
							where ltrim(rtrim(s.value)) = o.ColumnName
						)
			and not (o.IsTimestamp = 1 or o.IsComputed = 1)
	),
	x2 as
	(
		select	max(TargetTableName) TargetTableName, max(x1.IsIdentity) HasIdentity, 
				case when min(x1.PrimaryKeyOrder) = 0 then 1 else 0 end ContainNoneKeyColumn,
				string_agg(case when x1.PrimaryKeyOrder > 0 then 's.' + quotename(x1.ColumnName) + ' = t.' + quotename(x1.ColumnName)  end, ' and ') within group (order by x1.ColumnID) MergeKey,
				string_agg(case when x1.IsIdentity = 0 and @ForceIdentityColumnInsert = 0 or @ForceIdentityColumnInsert = 1 then quotename(x1.ColumnName) else '' end, ', ')  within group (order by x1.ColumnID) InsertColumnList,
				string_agg(case when x1.IsIdentity = 0 and @ForceIdentityColumnInsert = 0 or @ForceIdentityColumnInsert = 1 then 's.' + quotename(x1.ColumnName) else '' end, ', ')  within group (order by x1.ColumnID) InsertValueList,
				string_agg(
							case 
								when x1.PrimaryKeyOrder = 0 then 
											's.' + quotename(x1.ColumnNameExcludeIdentity) + ' is null and t.'+ quotename(x1.ColumnNameExcludeIdentity) + ' is not null'
										+	' or s.' + quotename(x1.ColumnNameExcludeIdentity) + ' is not null and t.' + quotename(x1.ColumnNameExcludeIdentity) + ' is null'
										+	' or '	+	case 
							when SystemType = 'image' then 'cast(s.' + quotename(x1.ColumnNameExcludeIdentity) + ' as varbinary(max)) <> t.cast(' + quotename(x1.ColumnNameExcludeIdentity) + ' as varbinary(max))'
							when SystemType = 'text' then 'cast(s.' + quotename(x1.ColumnNameExcludeIdentity) + ' as varchar(max)) <> t.cast(' + quotename(x1.ColumnNameExcludeIdentity) + ' as varchar(max))'
							when SystemType = 'ntext' then 'cast(s.' + quotename(x1.ColumnNameExcludeIdentity) + ' as nvarchar(max)) <> t.cast(' + quotename(x1.ColumnNameExcludeIdentity) + ' as nvarchar(max))'
							else 's.' + quotename(x1.ColumnNameExcludeIdentity) + ' <> t.' + quotename(x1.ColumnNameExcludeIdentity) 
						end
			end, ' or ')  within group (order by x1.ColumnID) UpdateWhereClause,
				string_agg(case when x1.PrimaryKeyOrder = 0 then 't.' + quotename(x1.ColumnNameExcludeIdentity) + ' = s.'+ quotename(x1.ColumnNameExcludeIdentity) end, ', ')  within group (order by x1.ColumnID) UpdateValueList
		from x1
	)
	--select * from x1
	select 
			cast(case when @ForceIdentityColumnInsert = 1 and x2.HasIdentity = 1 then 'set identity_insert ' + x2.TargetTableName + ' on;' else '' end as nvarchar(max)) + '
;with t as
(
	select * from ' + x2.TargetTableName + '
),
s as
(
	--<<YourQuery>>
)
merge t
using s on ' + x2.MergeKey + ' 
when not matched then
	insert(' + x2.InsertColumnList + ')
		values(' + x2.InsertValueList + ')'
		+	case 
				when ContainNoneKeyColumn = 1 then
					'
when matched and (' + x2.UpdateWhereClause + ') then 
	update set ' + x2.UpdateValueList
				else ''
			end + '
;
'
			+ case when @ForceIdentityColumnInsert = 1 and x2.HasIdentity = 1 then 'set identity_insert ' + x2.TargetTableName + ' off;' else '' end Query, *
	from x2
)
go
select * from z.fn_BuildQueryMergeTable('z.SystemUpdateBatch', default, default, default)

