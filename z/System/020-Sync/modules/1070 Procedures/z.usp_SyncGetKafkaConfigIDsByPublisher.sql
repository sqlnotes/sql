create or alter procedure z.usp_SyncGetKafkaConfigIDsByPublisher(
    @Pub nvarchar(200)=null) as
begin
    set nocount on
    select c.ConfigID
    from z.SyncConfig c
             inner join z.SyncPublisherTable t on t.ConfigID = c.ConfigID
             inner join z.SyncPublisher p on p.PublisherID = t.PublisherID
    where c.IsActive = 1
      and p.IsActive = 1
      and c.SourceType = 'KAFKA'
      and (@Pub is null or p.Name in (select value from string_split(@Pub, ',')))
end


go
