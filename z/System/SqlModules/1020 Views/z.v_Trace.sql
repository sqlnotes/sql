create or alter view z.v_Trace
as
	select	t.TraceID, t.Name, t.Description, t.CreationDate, ModificationDate, t.CreatorSessionID, t.ReceivingTable,
			isnull(
					(select 
							cast(
								case
									when st.status = 0 then 'Stopped'
									when st.status = 1 then 'Running'
								end as varchar(16)
							) Status
						from sys.traces st
						where t.TraceID = st.id
					),
					'Not Available'
				) Status
	from z.Trace t
