# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

The three ActiveSessions table baselines include managed-code, transaction-version
metrics and blocker details, using BlockerSessionID consistently with the views.
Snapshot procedures populate these columns. Baselines only create missing tables;
existing table schemas are not migrated by this change. Install the updated
tables and snapshot procedures together on a fresh schema.

## z.ActiveSessions

[Source](../../baseline/2020%20Tables/z.ActiveSessions.sql)

Persistent copy of the active-request view plus SnapshotDate (local collection time), SessionID, and sequence-backed ActiveSessionID. Key (SnapshotDate, SessionID, ActiveSessionID); page-compressed on PS_SchemaZPartitionGeneric(ActiveSessionID). Measures retain DMV units: CPU/WaitTime/TotalElapsedTime milliseconds, logical/physical reads counters, GrantedMemory pages. No foreign keys.

Column definitions (including source defaults):

```text
SnapshotDate datetime not null constraint DF_z_ActiveSessions_SnapshotDate default(getdate()),
SessionID smallint not null,
ActiveSessionID bigint not null constraint DF_z_ActiveSessions_ActiveSessionID default (datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
StartDate datetime not null,
BlockerSessionID smallint,
DurationInSecond int,
Status nvarchar(30) not null,
Command nvarchar(32) not null,
WaitType nvarchar(60),
WaitTime int not null,
WaitResource nvarchar(256) not null,
LastWaitType nvarchar(60) not null,
CPU int not null,
Reads bigint not null,
Writes bigint not null,
LogicalReads bigint not null,
TotalElapsedTime int not null,
DatabaseName nvarchar(128),
SQLText nvarchar(max),
QueryPlan xml,
GrantedMemory int not null,
NestedLevel int not null,
[RowCount] bigint not null,
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
ExecutingManagedCode bit not null,
MaxVersionTraversed int,
AverageVersionChainTraversed float,
TranDurationInSecond bigint,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
BlockerLoginName nvarchar(128),
BlockerHostName nvarchar(128),
BlockerAddress nvarchar(48),
BlockerApplicationName nvarchar(128),
BlockerQuery nvarchar(max),
BlockerLastExecutedCommand nvarchar(max),
```



## z.SystemHealthEvent

[Source](../../baseline/2020%20Tables/z.SystemHealthEvent.sql)

Key (EventDateUTC datetime, EventName nvarchar(128), EventHash uniqueidentifier); EventBody xml not null. EventDateUTC comes from the UTC XE timestamp, using SQL datetime precision; EventHash is MD5 of XML binary serialization. Page-compressed on PS_SchemaZPartitionGenericDateTime(EventDateUTC). Original XML retains the source timestamp. No foreign keys. Baseline changes do not migrate existing tables.

Column definitions (including source defaults):

```text
EventDateUTC datetime not null,
EventName nvarchar(128) not null,
EventHash uniqueidentifier not null,
EventBody xml not null,
```



## z.v_ActiveSessions

[Source](../../modules/1020%20Views/z.v_ActiveSessions.sql)

Current sys.dm_exec_requests joined to sessions/connections and SQL-text/query-plan functions, excluding @@SPID. All six left outer joins explicitly use LOOP join hints. Outputs SessionID, StartDate, BlockerSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, RowCount, OpenTranCount, TransactionIsolationLevel, ExecutingManagedCode, MaxVersionTraversed, AverageVersionChainTraversed, TranDurationInSecond, LoginName, HostName, HostAddress, ApplicationName, BlockerLoginName, BlockerHostName, BlockerAddress, BlockerApplicationName, BlockerQuery, BlockerLastExecutedCommand. ExecutingManagedCode exposes sys.dm_exec_requests.executing_managed_code (bit). A left join to sys.dm_tran_active_snapshot_database_transactions on session_id supplies MaxVersionTraversed (max_version_chain_traversed), AverageVersionChainTraversed (average_version_chain_traversed), and TranDurationInSecond (elapsed_time_seconds); these are null when no transaction matches. Multiple matching transactions can produce multiple rows per request. Blocker columns use blocking_session_id to look up session, connection and request details. BlockerQuery contains the active blocker batch text, falling back to its connection most_recent_sql_handle when no active SQL handle is available (including sleeping blockers); it does not identify the exact statement that acquired a lock. BlockerLastExecutedCommand exposes sys.dm_exec_input_buffer.event_info for the blocker session through OUTER APPLY, including sleeping sessions; it is the last submitted command, not proof of completion or the lock-acquiring statement. The function requires VIEW SERVER STATE on SQL Server 2019 or VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later. Missing or special negative blocker IDs yield null blocker details. Multiple blocker requests or connections can also multiply rows. Not idle-session inventory; outer joins can yield null details.



## z.v_ActiveSessionsNoPlan

[Source](../../modules/1020%20Views/z.v_ActiveSessionsNoPlan.sql)

Returns the same columns, types and order as z.v_ActiveSessions, with QueryPlan
always a typed XML NULL. The view does not call sys.dm_exec_query_plan. All other
request, transaction, blocker and input-buffer behavior and permissions are the
same as [z.v_ActiveSessions](#zv_activesessions).

## z.CPUMemoryStats

[Source](../../baseline/2020%20Tables/z.CPUMemoryStats.sql)

CPU/memory history with one stored row per local second. Columns are Date
datetime, SystemIdle int, SQLProcessUtilization int, Other int, UserModeTime
bigint, KernelModeTime bigint, PageFaults int, WorkingSetDelta int and
MemoryUtilizationPercentage int. Date is required; measurements are nullable.
No RecordID or SQLServerStartTime is stored.

The page-compressed primary key is Date on
PS_SchemaZPartitionGenericDateTime(Date). CK_z_CPUMemoryStats_DateSecond requires
zero milliseconds. The collector truncates Date to seconds, chooses the latest
source reading within each second, updates matching rows and inserts missing
seconds. It does not generate missing observations or perform metric averaging.
See [the collector](z.usp_CollectCPUMemoryStats.md) for permissions and behavior.

## z.v_CPUMemoryStats

[Source](../../modules/1020%20Views/z.v_CPUMemoryStats.sql)

Scheduler-monitor ring-buffer XML -> RecordID, Date, SystemIdle, SQLProcessUtilization, Other, UserModeTime, KernelModeTime, PageFaults, WorkingSetDelta, MemoryUtilizationPercentage. Other=100-idle-SQL percentage; mode times are 100ns units. The view exposes the current ring buffer; use z.usp_CollectCPUMemoryStats to persist observations in z.CPUMemoryStats.



## z.v_IndexSpaceUsed

[Source](../../modules/1020%20Views/z.v_IndexSpaceUsed.sql)

One DMV row per index partition, joined to sys.indexes for IndexName. Returns
PartitionID, ObjectID, SchemaName, ObjectName, IndexID, IndexName,
PartitionNumber and RowCount, followed by used, reserved, free, in-row, LOB and
row-overflow page counts and corresponding sizes in KB. KB size expressions
use 8 KB per page. FreePageCount is ReservedPageCount minus UsedPageCount;
FreeSpaceKB is that difference multiplied by 8. Appended compatibility columns
Rows, SpaceUsedMB, SpaceReservedMB and FreeSpaceMB preserve the retired index-space interface.
Rows duplicates RowCount. These three MB columns retain the source expression
using 8.192 / 1024 per page; the KB columns use 8 per page. Native DMV permissions and
metadata visibility apply.

## z.v_PerformanceCounters

[Source](../../modules/1030%20Views/z.v_PerformanceCounters.sql)

Live sys.dm_os_performance_counters rows enriched through a left join to
z.v_PerformanceCounterTypes. Returns ObjectName, CounterName, InstanceName,
CounterValue (raw bigint), CounterType (int), CounterTypeName and
CounterTypeDescription. Native fixed-width names are preserved. Unknown counter
types remain visible with null lookup fields. The lookup has one row per type.

This view does not sample, persist or calculate rates/averages. Read the type
description to determine how to interpret CounterValue. DMV permissions and
visibility still apply: VIEW SERVER STATE on SQL Server 2019, or
VIEW SERVER PERFORMANCE STATE on SQL Server 2022 and later. The view installs
after its lookup dependency.

## z.v_PerformanceCountersDefault

[Source](../../modules/1030%20Views/z.v_PerformanceCountersDefault.sql)

Default capture selection over z.v_PerformanceCounters, with the same seven
columns and raw counter values. Selects configured counters from Access Methods,
Availability Replica/Group, Buffer Manager/Node, Databases, General Statistics,
Latches, Locks, Memory Manager, Plan Cache, SQL Errors, SQL Statistics and
Transactions. Total-instance restrictions apply only to the categories specified
in the source; Buffer Node retains individual nodes and SQL Errors includes the
selected error categories. The literal XTP exclusions are retained. Ratio
selections include Worktables From Cache Base and Cache Hit Ratio Base for their
matching numerator counters; unrestricted availability categories retain their
base counters as well.

Object and counter names match exactly as written in the definition. A category
or instance absent on the current server contributes no rows. This view does not
collect, persist, calculate rates or guarantee row order. Apply ORDER BY in the
consuming query. Native DMV permissions and the base view's behavior apply.

## z.v_PerformanceCounterTypes

[Source](../../modules/1020%20Views/z.v_PerformanceCounterTypes.sql)

Static lookup for the six counter types documented for
sys.dm_os_performance_counters. Returns CounterType int, CounterTypeName
nvarchar(64) and Description nvarchar(512). It has no DMV dependencies and
requires only access to the view. The names follow the Windows performance
counter constants used by SQL Server; the descriptions summarize raw values,
per-second rates, fractions, interval averages and base denominators.

Join CounterType to cntr_type. This view describes the type; it does not calculate
rates, choose a matching base counter or collect samples. Units remain specific
to each performance counter. For a fraction/average, match the base using the
counter's object/instance and documented base name; avoid dividing by zero.
Counter resets or server restarts require a fresh sampling interval. Use a left
join when enriching DMV rows so an unrecognized type remains visible with null
lookup fields. The catalog covers SQL Server's documented six types, rather
than all Windows performance-counter constants.

References: [SQL Server DMV counter semantics](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql),
[counter algorithms](https://learn.microsoft.com/en-us/windows/win32/wmisdk/counter-algorithm-counter-types),
[base counter types](https://learn.microsoft.com/en-us/windows/win32/wmisdk/base-counter-types),
and [64-bit fractions and raw/base types](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.performancedata.countertype).

## z.v_ObjectSpaceUsed

[Source](../../modules/1020%20Views/z.v_ObjectSpaceUsed.sql)

Aggregate DMV allocation by object; exclude memory-optimized tables and include internal XML/spatial allocation types 202/204. Outputs ObjectID, SchemaName, TableName, RowCount, ReservedKB, DataKB, IndexSize, Unused. All size expressions multiply pages by 8 (KB); only base index rows contribute RowCount.

## z.TraceBlockedProcessReport

[Source](../../baseline/2020%20Tables/z.TraceBlockedProcessReport.sql)

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes. See source column inventory below for exact types.

Column definitions (including source defaults):

```text
TraceSequence bigint not null constraint DF_z_TraceBlockedProcessReport_TraceSequence  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
EventID int not null,
EventName nvarchar(128) not null,
TextData nvarchar(max),
BinaryData varbinary(max),
DatabaseID int,
TransactionID bigint,
LineNumber int,
NTUserName nvarchar(512),
NTDomainName nvarchar(512),
HostName nvarchar(512),
ClientProcessID int,
ApplicationName nvarchar(512),
LoginName nvarchar(512),
SPID int,
Duration bigint,
StartTime datetime,
EndTime datetime,
Reads bigint,
Writes bigint,
CPU int,
Permissions bigint,
Severity int,
EventSubClass int,
ObjectID int,
Success int,
IndexID int,
IntegerData int,
ServerName nvarchar(512),
EventClass int,
ObjectType int,
NestLevel int,
State int,
Error int,
Mode int,
Handle int,
ObjectName nvarchar(512),
DatabaseName nvarchar(512),
FileName nvarchar(512),
OwnerName nvarchar(512),
RoleName nvarchar(512),
TargetUserName nvarchar(512),
DBUserName nvarchar(512),
LoginSid varbinary(max),
TargetLoginName nvarchar(512),
TargetLoginSid varbinary(max),
ColumnPermissions int,
LinkedServerName nvarchar(512),
ProviderName nvarchar(512),
MethodName nvarchar(512),
RowCounts bigint,
RequestID int,
XactSequence bigint,
EventSequence bigint,
BigintData1 bigint,
BigintData2 bigint,
GUID uniqueidentifier,
IntegerData2 int,
ObjectID2 bigint,
Type int,
OwnerID int,
ParentName nvarchar(512),
IsSystem int,
Offset int,
SourceDatabaseID int,
SqlHandle varbinary(max),
SessionLoginName nvarchar(512),
PlanHandle varbinary(max),
GroupID int,
```

## z.TraceBlockedProcessReportActiveSessions

[Source](../../baseline/2020%20Tables/z.TraceBlockedProcessReportActiveSessions.sql)

Active-request snapshot correlated by TraceSequence; key (TraceSequence, SnapshotDate, SessionID, ActiveSessionID). SnapshotDate defaults local getdate; ActiveSessionID defaults UTC/sequence encoding. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). Columns match Monitoring request snapshots; callbacks leave QueryPlan null. No FK to event table.

Column definitions (including source defaults):

```text
TraceSequence bigint not null,
SnapshotDate datetime not null constraint DF_z_TraceBlockedProcessReportActiveSessions_SnapshotDate  default(getdate()),
SessionID smallint not null,
ActiveSessionID bigint not null constraint DF_z_TraceBlockedProcessReportActiveSessions_ActiveSessionID  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
StartDate datetime not null,
BlockerSessionID smallint,
DurationInSecond int,
Status nvarchar(30) not null,
Command nvarchar(32) not null,
WaitType nvarchar(60),
WaitTime int not null,
WaitResource nvarchar(256) not null,
LastWaitType nvarchar(60) not null,
CPU int not null,
Reads bigint not null,
Writes bigint not null,
LogicalReads bigint not null,
TotalElapsedTime int not null,
DatabaseName nvarchar(128),
SQLText nvarchar(max),
QueryPlan xml,
GrantedMemory int not null,
NestedLevel int not null,
[RowCount] bigint not null,
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
ExecutingManagedCode bit not null,
MaxVersionTraversed int,
AverageVersionChainTraversed float,
TranDurationInSecond bigint,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
BlockerLoginName nvarchar(128),
BlockerHostName nvarchar(128),
BlockerAddress nvarchar(48),
BlockerApplicationName nvarchar(128),
BlockerQuery nvarchar(max),
BlockerLastExecutedCommand nvarchar(max),
```

## z.TraceError

[Source](../../baseline/2020%20Tables/z.TraceError.sql)

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes. See source column inventory below for exact types.

Column definitions (including source defaults):

```text
TraceSequence bigint not null constraint DF_z_TraceError_TraceSequence default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
EventID int not null,
EventName nvarchar(128) not null,
TextData nvarchar(max),
BinaryData varbinary(max),
DatabaseID int,
TransactionID bigint,
LineNumber int,
NTUserName nvarchar(512),
NTDomainName nvarchar(512),
HostName nvarchar(512),
ClientProcessID int,
ApplicationName nvarchar(512),
LoginName nvarchar(512),
SPID int,
Duration bigint,
StartTime datetime,
EndTime datetime,
Reads bigint,
Writes bigint,
CPU int,
Permissions bigint,
Severity int,
EventSubClass int,
ObjectID int,
Success int,
IndexID int,
IntegerData int,
ServerName nvarchar(512),
EventClass int,
ObjectType int,
NestLevel int,
State int,
Error int,
Mode int,
Handle int,
ObjectName nvarchar(512),
DatabaseName nvarchar(512),
FileName nvarchar(512),
OwnerName nvarchar(512),
RoleName nvarchar(512),
TargetUserName nvarchar(512),
DBUserName nvarchar(512),
LoginSid varbinary(max),
TargetLoginName nvarchar(512),
TargetLoginSid varbinary(max),
ColumnPermissions int,
LinkedServerName nvarchar(512),
ProviderName nvarchar(512),
MethodName nvarchar(512),
RowCounts bigint,
RequestID int,
XactSequence bigint,
EventSequence bigint,
BigintData1 bigint,
BigintData2 bigint,
GUID uniqueidentifier,
IntegerData2 int,
ObjectID2 bigint,
Type int,
OwnerID int,
ParentName nvarchar(512),
IsSystem int,
Offset int,
SourceDatabaseID int,
SqlHandle varbinary(max),
SessionLoginName nvarchar(512),
PlanHandle varbinary(max),
GroupID int,
```

## z.TraceFileAutoGrow

[Source](../../baseline/2020%20Tables/z.TraceFileAutoGrow.sql)

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes. See source column inventory below for exact types.

Column definitions (including source defaults):

```text
TraceSequence bigint not null constraint DF_z_TraceFileAutoGrow_TraceSequence  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
EventID int not null,
EventName nvarchar(128) not null,
TextData nvarchar(max),
BinaryData varbinary(max),
DatabaseID int,
TransactionID bigint,
LineNumber int,
NTUserName nvarchar(512),
NTDomainName nvarchar(512),
HostName nvarchar(512),
ClientProcessID int,
ApplicationName nvarchar(512),
LoginName nvarchar(512),
SPID int,
Duration bigint,
StartTime datetime,
EndTime datetime,
Reads bigint,
Writes bigint,
CPU int,
Permissions bigint,
Severity int,
EventSubClass int,
ObjectID int,
Success int,
IndexID int,
IntegerData int,
ServerName nvarchar(512),
EventClass int,
ObjectType int,
NestLevel int,
State int,
Error int,
Mode int,
Handle int,
ObjectName nvarchar(512),
DatabaseName nvarchar(512),
FileName nvarchar(512),
OwnerName nvarchar(512),
RoleName nvarchar(512),
TargetUserName nvarchar(512),
DBUserName nvarchar(512),
LoginSid varbinary(max),
TargetLoginName nvarchar(512),
TargetLoginSid varbinary(max),
ColumnPermissions int,
LinkedServerName nvarchar(512),
ProviderName nvarchar(512),
MethodName nvarchar(512),
RowCounts bigint,
RequestID int,
XactSequence bigint,
EventSequence bigint,
BigintData1 bigint,
BigintData2 bigint,
GUID uniqueidentifier,
IntegerData2 int,
ObjectID2 bigint,
Type int,
OwnerID int,
ParentName nvarchar(512),
IsSystem int,
Offset int,
SourceDatabaseID int,
SqlHandle varbinary(max),
SessionLoginName nvarchar(512),
PlanHandle varbinary(max),
GroupID int,
```

## z.TraceFileAutoGrowActiveSessions

[Source](../../baseline/2020%20Tables/z.TraceFileAutoGrowActiveSessions.sql)

Active-request snapshot correlated by TraceSequence; key (TraceSequence, SnapshotDate, SessionID, ActiveSessionID). SnapshotDate defaults local getdate; ActiveSessionID defaults UTC/sequence encoding. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). Columns match Monitoring request snapshots; callbacks leave QueryPlan null. No FK to event table.

Column definitions (including source defaults):

```text
TraceSequence bigint not null,
SnapshotDate datetime not null constraint DF_z_TraceFileAutoGrowActiveSessions_SnapshotDate  default(getdate()),
SessionID smallint not null,
ActiveSessionID bigint not null constraint DF_z_TraceFileAutoGrowActiveSessions_ActiveSessionID  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
StartDate datetime not null,
BlockerSessionID smallint,
DurationInSecond int,
Status nvarchar(30) not null,
Command nvarchar(32) not null,
WaitType nvarchar(60),
WaitTime int not null,
WaitResource nvarchar(256) not null,
LastWaitType nvarchar(60) not null,
CPU int not null,
Reads bigint not null,
Writes bigint not null,
LogicalReads bigint not null,
TotalElapsedTime int not null,
DatabaseName nvarchar(128),
SQLText nvarchar(max),
QueryPlan xml,
GrantedMemory int not null,
NestedLevel int not null,
[RowCount] bigint not null,
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
ExecutingManagedCode bit not null,
MaxVersionTraversed int,
AverageVersionChainTraversed float,
TranDurationInSecond bigint,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
BlockerLoginName nvarchar(128),
BlockerHostName nvarchar(128),
BlockerAddress nvarchar(48),
BlockerApplicationName nvarchar(128),
BlockerQuery nvarchar(max),
BlockerLastExecutedCommand nvarchar(max),
```

## z.TraceLongRunningQuery

[Source](../../baseline/2020%20Tables/z.TraceLongRunningQuery.sql)

Event storage: TraceSequence bigint primary key (UTC seconds plus z.SeqGeneralID), EventID int, EventName nvarchar(128), plus nullable SQL Trace column payloads. Duration is microseconds for collected duration events; other metrics retain SQL Trace units. Page compression and PS_SchemaZPartitionGeneric(TraceSequence). No FK to trace metadata: records can remain after trace closes. See source column inventory below for exact types.

Column definitions (including source defaults):

```text
TraceSequence bigint not null constraint DF_z_TraceLongRunningQuery_TraceSequence  default(datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
EventID int not null,
EventName nvarchar(128) not null,
TextData nvarchar(max),
BinaryData varbinary(max),
DatabaseID int,
TransactionID bigint,
LineNumber int,
NTUserName nvarchar(512),
NTDomainName nvarchar(512),
HostName nvarchar(512),
ClientProcessID int,
ApplicationName nvarchar(512),
LoginName nvarchar(512),
SPID int,
Duration bigint,
StartTime datetime,
EndTime datetime,
Reads bigint,
Writes bigint,
CPU int,
Permissions bigint,
Severity int,
EventSubClass int,
ObjectID int,
Success int,
IndexID int,
IntegerData int,
ServerName nvarchar(512),
EventClass int,
ObjectType int,
NestLevel int,
State int,
Error int,
Mode int,
Handle int,
ObjectName nvarchar(512),
DatabaseName nvarchar(512),
FileName nvarchar(512),
OwnerName nvarchar(512),
RoleName nvarchar(512),
TargetUserName nvarchar(512),
DBUserName nvarchar(512),
LoginSid varbinary(max),
TargetLoginName nvarchar(512),
TargetLoginSid varbinary(max),
ColumnPermissions int,
LinkedServerName nvarchar(512),
ProviderName nvarchar(512),
MethodName nvarchar(512),
RowCounts bigint,
RequestID int,
XactSequence bigint,
EventSequence bigint,
BigintData1 bigint,
BigintData2 bigint,
GUID uniqueidentifier,
IntegerData2 int,
ObjectID2 bigint,
Type int,
OwnerID int,
ParentName nvarchar(512),
IsSystem int,
Offset int,
SourceDatabaseID int,
SqlHandle varbinary(max),
SessionLoginName nvarchar(512),
PlanHandle varbinary(max),
GroupID int,
```
