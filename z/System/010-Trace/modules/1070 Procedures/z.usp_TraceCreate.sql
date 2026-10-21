create or alter procedure z.usp_TraceCreate
(
	@TraceName nvarchar(128) = null,
	@Description nvarchar(max) = null,
	@ReceivingTable nvarchar(128) = null,
	@TraceID int = null output
)
as
begin
	set nocount, xact_abort on;
	if @@trancount > 0
	begin
		set xact_abort off;
		throw 50000, N'Trace creation requires no existing transaction.', 1;
	end;
	declare @CollectorUUID uniqueidentifier, @SchemaName sysname, @TableName sysname, @QualifiedTable nvarchar(517);
	select @TraceID = null;
	if @TraceName is null return;
	if trim(@TraceName) = N'' throw 50000, N'@TraceName must not be empty.', 1;
	if @ReceivingTable is not null
	begin
		select @SchemaName = parsename(@ReceivingTable, 2), @TableName = parsename(@ReceivingTable, 1);
		if @SchemaName is null or @TableName is null or parsename(@ReceivingTable, 3) is not null
			or parsename(@ReceivingTable, 4) is not null or schema_id(@SchemaName) is null
			throw 50000, N'@ReceivingTable must identify a table in an existing schema in the current database.', 1;
		select @QualifiedTable = quotename(@SchemaName) + N'.' + quotename(@TableName);
		if len(@QualifiedTable) > 128 throw 50000, N'The quoted receiving table name exceeds the registry limit.', 1;
		select @ReceivingTable = @QualifiedTable;
	end;
	exec z.usp_TraceRegisterCollector @CollectorUUID output;
	exec z.usp_TraceAssertOwner;
	if exists(select 1 from z.TraceCollector where CollectorUUID = @CollectorUUID and State <> 'Building')
		throw 50000, N'Logical trace configuration is frozen during collection.', 1;
	select @TraceID = TraceID from z.Trace where CollectorUUID = @CollectorUUID and Name = @TraceName;
	if @TraceID is not null
	begin
		if exists(select 1 from z.Trace where TraceID = @TraceID and IsEnabled = 1)
			throw 50000, N'Stop the logical trace before changing its metadata.', 1;
		update z.Trace set Description = isnull(@Description, Description), ReceivingTable = isnull(@ReceivingTable, ReceivingTable), ModificationDate = getdate()
		where TraceID = @TraceID and CollectorUUID = @CollectorUUID;
		return;
	end;
	if @ReceivingTable is null
	begin
		select @QualifiedTable = N'[z].' + quotename(N'Trace_' + @TraceName);
		if @QualifiedTable is null or len(@QualifiedTable) > 128
			throw 50000, N'The default receiving table name exceeds the registry limit; provide a shorter @ReceivingTable.', 1;
		select @ReceivingTable = @QualifiedTable;
	end;
	insert z.Trace (CollectorUUID, Name, Description, ReceivingTable) values (@CollectorUUID, @TraceName, @Description, @ReceivingTable);
	select @TraceID = convert(int, scope_identity());
end;
go
