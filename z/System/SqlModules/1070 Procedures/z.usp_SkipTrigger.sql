create or alter procedure z.usp_SkipTrigger
(
	@ParentObjectNames nvarchar(max) = null,
	@TriggerNames nvarchar(max) = null
)
as
begin
	set nocount on
	declare @TriggerIDs sql_variant
	if @ParentObjectNames = 'all' or @TriggerNames = 'all'
	begin
		select @TriggerIDs = 'all'
	end
	else
	begin
		select @TriggerIDs = cast(cast(string_agg(x0.object_id, ',') as varchar(8000)) as sql_variant)
		from (
				select t.object_id
				from sys.triggers t
				where t.is_disabled = 0
					and exists(
								select *
								from string_split(@ParentObjectNames, ',') s
								where object_id(rtrim(ltrim(s.value))) = t.parent_id
							)
				union
				select t.object_id
				from (
						select parsename(rtrim(ltrim(value)), 1) TriggerName, schema_name(schema_id(parsename(rtrim(ltrim(value)), 2))) SchemaName 
						from string_split(@TriggerNames, ',')
					) x0
					inner join sys.triggers t on t.name = x0.TriggerName and isnull(object_schema_name(t.object_id), '') = isnull(x0.SchemaName, '')
				where t.is_disabled = 0
			) x0
	end
	exec sp_set_session_context  @key= N'SkipTriggerFlag', @value = @TriggerIDs
end