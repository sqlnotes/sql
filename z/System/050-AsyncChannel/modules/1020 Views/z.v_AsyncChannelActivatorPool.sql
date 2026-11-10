/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1020%20Views/z.v_AsyncChannelActivatorPool.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.v_AsyncChannelActivatorPool.md

Pool configuration, granted slots and inferred waiting sessions in the current database.
*/
create or alter view z.v_AsyncChannelActivatorPool
as
	select	p.ActivatorPoolID, p.Name, p.Description, p.MaxConcurrency, p.TimeoutSeconds, p.IsActive, p.RowVersion,
			ChannelCount = (select count(*) from z.AsyncChannel c where c.ActivatorPoolID = p.ActivatorPoolID),
			SlotsInUse = isnull(a.SlotsInUse, 0),
			SessionsWaiting = isnull(a.SessionsWaiting, 0)
	from z.AsyncChannelActivatorPool p
		outer apply
		(
			select SlotsInUse = sum(s.SlotCount), SessionsWaiting = sum(iif(s.MainHeld = 1 and s.SlotCount = 0, 1, 0))
			from
			(
				-- The shared semaphore grants IX on ADPool/<ID> and X on <slot>-ADPool/<ID>.
				-- Waiting is inferred from a held IX marker without a granted slot, not a native WAIT row.
				select l.request_session_id,
					SlotCount = count(distinct case when l.request_mode = 'X' and l.request_status = 'GRANT' then l.resource_description end),
					MainHeld = max(iif(l.request_mode = 'IX' and l.request_status = 'GRANT', 1, 0))
				from sys.dm_tran_locks l
				where l.resource_type = 'APPLICATION' and l.resource_database_id = db_id() and l.request_owner_type = 'SESSION'
					and l.resource_description like N'%ADPool/' + cast(p.ActivatorPoolID as nvarchar(11)) + N'[^0-9]%'
				group by l.request_session_id
			) s
		) a
