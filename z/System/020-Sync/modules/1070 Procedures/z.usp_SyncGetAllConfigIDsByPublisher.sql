create or alter procedure z.usp_SyncGetAllConfigIDsByPublisher
(
	@PublisherNames nvarchar(max) = null
) as
begin
	set nocount on
	declare @Names table(Name nvarchar(128) primary key with(ignore_dup_key = on))

	select @PublisherNames = nullif(rtrim(@PublisherNames), '')

	if @PublisherNames is not null
	begin
		insert into @Names(Name)
			select nullif(trim(value), '')
			from string_split(@PublisherNames, ',')
			where nullif(trim(value), '') is not null
	end

	select p.PublisherID, p.MaxInitializationTasks, p.MaxIncrementalTasks, p.SyncIntervalMS
	from z.SyncPublisher p
	where p.IsActive = 1
		and (@PublisherNames is null or p.Name in (select Name from @Names))

	select	c.ConfigID,
			case
				when g.ToValue is null and c.FilterProcedure not like '%SyncFilterRealTime%' then 1
				else 0
			end ShouldInitialize,
			p.PublisherID
	from z.SyncConfig c
		inner join z.SyncPublisherTable t on t.ConfigID = c.ConfigID
		inner join z.SyncPublisher p on p.PublisherID = t.PublisherID
		left join z.SyncProgress g on g.ConfigID = c.ConfigID
	where c.IsActive = 1
		and p.IsActive = 1
		and c.SourceType = 'DATABASE'
		and (@PublisherNames is null or p.Name in (select Name from @Names))
		and applock_test('public', cast(c.ConfigID as nvarchar(20)) + '-z.usp_SyncGetLock', 'Exclusive', 'Session') = 1
		and applock_mode('public', cast(c.ConfigID as nvarchar(20)) + '-z.usp_SyncGetLock', 'Session') = 'NoLock'
end


go
