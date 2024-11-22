create or alter function z.fn_GetTableDefinition
(
	@FullTableName nvarchar(256),
	@TargetTableName nvarchar(256) = null,
	@Inclusion nvarchar(256) = null, -- null/all,Index, Primary
	@Exclusion nvarchar(256) = null -- null/none,
)