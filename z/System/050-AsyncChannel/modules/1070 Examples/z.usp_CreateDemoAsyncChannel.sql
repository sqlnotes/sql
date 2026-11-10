/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1070%20Examples/z.usp_CreateDemoAsyncChannel.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_CreateDemoAsyncChannel.md

Opt-in construction example with usage comments before the definition; creates a manual Demo channel and its authored objects.
*/
/*
Creates the Demo channel as a worked example of building an AsyncChannel.
Install the framework first; enable Service Broker in the database separately before sending data.
Run the following statements in the same database, outside an explicit or implicit transaction:

	exec z.usp_CreateDemoAsyncChannel @AsyncChannelID = 0, @ActivatorPoolID = 0;
	go

	insert into z.AsyncChannel_Demo_Interface (RecordID, Description, Date)
		values (1, N'First asynchronous row', '2026-01-01T12:00:00'),
			   (2, N'Second asynchronous row', '2026-01-01T12:01:00');

	-- Manual activation makes the receive/processing step visible. Run it after the insert commits; it waits briefly for delivery.
	-- Broker delivery can be asynchronous: if no rows have arrived yet, invoke it again.
	exec z.usp_AsyncChannel_Demo_Activator;
	select RecordID, Description, Date from z.AsyncChannel_Demo order by RecordID;

The creator performs these steps atomically:
1. Create a destination table and author its empty <TableName>_Interface view; do not add v_.
2. Register a processing pool and a Manual channel, then generate its codecs, enqueue trigger,
   enqueue procedure, queue/service, activator and initial processing scaffold.
3. Replace that new scaffold with application processing after its deserializer exists.
   The processor decodes only payload messages and upserts by RecordID, so replay is idempotent.

To build your own channel, copy the steps and replace the Demo object names, interface columns,
registry IDs and processing body. The interface columns define the generated codec signatures.
For automatic activation, use ActivationType = 'Auto' after supplying the actual processing body.

This procedure sends no data itself and is never invoked by installation. It fails on an existing
Demo registration, pool or object rather than resetting or overwriting application work. Choose
unused IDs if 0 is already registered. The fixed Demo names permit only one demo per database.

When finished, z.usp_AsyncChannelRemove @AsyncChannelID = 0 removes the channel registration and
generated objects, with forced cleanup of pending conversations. It preserves the authored
z.AsyncChannel_Demo_Interface view, z.usp_AsyncChannel_Demo_Process procedure, destination table
and pool registration. Remove those separately only after reviewing retained data and pool use.
Substitute your chosen ID in cleanup if you did not use 0.
*/
create or alter procedure z.usp_CreateDemoAsyncChannel
(
	@AsyncChannelID int = 0,
	@ActivatorPoolID int = 0
)
as
begin
	set nocount, xact_abort on;
	declare @LockResult int;
	if @@trancount > 0 or (2 & @@options) = 2
		throw 50000, 'Create the demo outside explicit and implicit transactions.', 1;
	if @AsyncChannelID is null or @ActivatorPoolID is null
		throw 50000, 'The demo channel and activator pool IDs must not be NULL.', 1;

	begin try
		begin tran;
		exec @LockResult = z.usp_AcquireSemaphore @SemaphoreName = N'z.usp_CreateDemoAsyncChannel', @TotalCount = 1,
										 @LockOwner = 'Transaction', @LockTimeout = 10000;
		if @LockResult <= 0
			throw 50000, 'Could not acquire the demo creation lock.', 1;
		if exists (select 1 from z.AsyncChannel where AsyncChannelID = @AsyncChannelID or Name = N'Demo')
			throw 50000, 'The Demo channel name or requested channel ID is already registered.', 1;
		if exists (select 1 from z.AsyncChannelActivatorPool where ActivatorPoolID = @ActivatorPoolID or Name = N'Demo')
			throw 50000, 'The Demo pool name or requested pool ID is already registered.', 1;
		if exists
		(
			select 1 from sys.objects
			where schema_id = schema_id(N'z') and name in
			(
				N'AsyncChannel_Demo', N'AsyncChannel_Demo_Interface', N'TRI_AsyncChannel_Demo_Interface',
				N'fn_AsyncChannelSerializer_Demo', N'fn_AsyncChannelDeserializer_Demo', N'AsyncChannelQueue_Demo',
				N'usp_AsyncChannel_Demo_Process', N'usp_AsyncChannel_Demo_Enqueue', N'usp_AsyncChannel_Demo_Activator',
				N'PK_z_AsyncChannel_Demo'
			)
		)
			throw 50000, 'A Demo object already exists; review and remove it separately before creating the example.', 1;
		if exists (select 1 from sys.services where name = N'/SchemaZ/AsyncChannel/z/Demo/Service')
			throw 50000, 'The Demo Broker service already exists.', 1;

		-- 1. The authored table and interface define the application payload contract.
		create table z.AsyncChannel_Demo
		(
			RecordID int not null,
			Description nvarchar(200),
			Date datetime2(3),
			constraint PK_z_AsyncChannel_Demo primary key clustered (RecordID)
		);
		exec(N'create view z.AsyncChannel_Demo_Interface
as
	select top (0) RecordID = cast(null as int), Description = cast(null as nvarchar(200)), Date = cast(null as datetime2(3));');

		-- 2. A dedicated pool limits this example to one processing call at a time.
		insert into z.AsyncChannelActivatorPool (ActivatorPoolID, Name, Description, MaxConcurrency, TimeoutSeconds, IsActive)
			values (@ActivatorPoolID, N'Demo', N'Demo processing pool', 1, 5, 1);
		insert into z.AsyncChannel (AsyncChannelID, Name, Description, ProcessingProcedure, ActivationType, Readers,
								  MaxRowsPerMessage, MaxMessagesPerReceive, MaxIdleDurationSeconds, MaxExecutionSeconds, IsActive, DebugMode, ActivatorPoolID)
			values (@AsyncChannelID, N'Demo', N'Demo channel with an authored interface and idempotent processing', N'z.usp_AsyncChannel_Demo_Process', N'Manual', 1,
					10, 100, 2, 5, 1, 0, @ActivatorPoolID);
		-- The interface must exist before the generator snapshots its column metadata.
		exec z.usp_AsyncChannelDeploy @AsyncChannelID = @AsyncChannelID;

		-- 3. Replace only the scaffold created above; no pre-existing Demo object can reach this step.
		exec(N'create or alter procedure z.usp_AsyncChannel_Demo_Process
(
	@Messages z.AsyncChannelMessage readonly
)
as
begin
	set nocount, xact_abort on;
	;with x as
	(
		select d.RecordID, d.Description, d.Date,
			Ordinal = row_number() over (partition by d.RecordID order by m.SequenceNumber desc, d.Date desc, d.Description collate Latin1_General_100_BIN2 desc)
		from @Messages m
			cross apply z.fn_AsyncChannelDeserializer_Demo(m.Payload) d
		where m.IsPayload = 1
	), s as
	(
		select RecordID, Description, Date from x where Ordinal = 1
	)
	merge z.AsyncChannel_Demo as t using s on t.RecordID = s.RecordID
	when matched then update set t.Description = s.Description, t.Date = s.Date
	when not matched then insert (RecordID, Description, Date) values (s.RecordID, s.Description, s.Date);
end');
		commit;
	end try
	begin catch
		if @@trancount > 0 rollback;
		throw;
	end catch
end
