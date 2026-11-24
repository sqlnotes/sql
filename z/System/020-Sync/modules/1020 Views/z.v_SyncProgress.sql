create or alter view z.v_SyncProgress
as

select c.ConfigID, c.Name, t.PublisherID, c.BatchSize, c.IsActive,
	case
		when p.ToValue is null and c.FilterProcedure not like '%SyncFilterRealTime' then 1
		else 0
	end  NeedInitialization,
	p.BatchCount,
	p.TotalRows, TotalRows*1.0/nullif(datediff(second, StartDate, isnull(EndDate, getdate())), 0) RowsPerSecond,  datediff(second, StartDate, isnull(EndDate, getdate()))*1.0/nullif(BatchCount,0) SecondPerBatch,
	p.RowsInBatch, p.StartDate, p.EndDate, datediff_big(second, StartDate, isnull(EndDate, getdate())) DurationInSecond, p.Error, p.FromValue, p.ToValue, p.FromValueAdjusted, p.ToValueAdjusted
from z.SyncConfig c
	left join z.SyncProgress p on c.ConfigID = p.ConfigID
	left join z.SyncPublisherTable t on t.ConfigID = c.ConfigID

go
