create or alter view z.v_PerformanceCountersDefault
as
	select ObjectName, CounterName, InstanceName, CounterValue, CounterType, CounterTypeName, CounterTypeDescription
	from z.v_PerformanceCounters
where ObjectName not in ('SQL Server 2022 XTP Transactions')
	and ObjectName not like 'SQL Server 2022 XTP%'
	and (
					ObjectName = 'SQLServer:Access Methods'
				and CounterName in('Full Scans/sec', 'Index Searches/sec', 'Page Splits/sec', 'Pages Allocated/sec','Page Deallocations/sec', 'Pages compressed/sec', 'Range Scans/sec','Skipped Ghosted Records/sec', 'Table Lock Escalations/sec', 'Workfiles Created/sec', 'Worktables Created/sec', 'Worktables From Cache Base', 'Worktables From Cache Ratio')
			or
					ObjectName in('SQLServer:Availability Replica', 'SQLServer:Availability Group')
				and InstanceName = '_Total'
			or
					ObjectName = 'SQLServer:Buffer Manager'
				and CounterName in ('Checkpoint pages/sec', 'Page life expectancy', 'Page reads/sec', 'Page lookups/sec', 'Lazy writes/sec', 'Page writes/sec')
			or
					ObjectName = 'SQLServer:Buffer Node'
				and CounterName in ('Page life expectancy', 'Remote node page lookups/sec')
			or
					ObjectName = 'SQLServer:Databases'
				and InstanceName = '_Total'
				and CounterName in ('Active Transactions', 'Data File(s) Size (KB)', 'Transactions/sec', 'Write Transactions/sec')
			or
					ObjectName = 'SQLServer:General Statistics'
				and CounterName in('Active Temp Tables', 'Connection Reset/sec', 'Logins/sec', 'Logouts/sec','Mars Deadlocks', 'Processes blocked', 'Transactions', 'Connections')
			or
					ObjectName = 'SQLServer:Latches'
				and CounterName in ('Latch Waits/sec', 'Number of SuperLatches')
			or
					ObjectName = 'SQLServer:Locks'
				and InstanceName = '_Total'
				and CounterName in ('Lock Requests/sec', 'Lock Timeouts/sec', 'Lock Wait Time (ms)', 'Lock Waits/sec', 'Number of Deadlocks/sec')
			or
					ObjectName = 'SQLServer:Memory Manager'
				and CounterName in ('Free Memory (KB)', 'Granted Workspace Memory (KB)','Lock Blocks','Lock Blocks Allocated','Lock Memory (KB)', 'Memory Grants Outstanding','Memory Grants Pending', 'Optimizer Memory (KB)', 'SQL Cache Memory (KB)', 'SQL Cache Memory (KB)')
			or
					ObjectName = 'SQLServer:Plan Cache'
				and InstanceName = '_Total'
				and CounterName	in ('Cache Hit Ratio', 'Cache Hit Ratio Base', 'Cache Object Counts','Cache Objects in use', 'Cache Pages')
			or
					ObjectName = 'SQLServer:SQL Errors'
				and CounterName = 'Errors/sec'
				and InstanceName in('_Total', 'DB Offline Errors', 'Info Errors', 'Kill Connection Errors', 'User Errors')
			or
					ObjectName = 'SQLServer:SQL Statistics'
				and CounterName in ('Batch Requests/sec', 'SQL Compilations/sec', 'SQL Re-Compilations/sec')
			or
					ObjectName = 'SQLServer:Transactions'
				and CounterName in('Longest Transaction Running Time', 'Snapshot Transactions', 'Transactions','Version Store Size (KB)', 'Version Generation rate (KB/s)')
		)
