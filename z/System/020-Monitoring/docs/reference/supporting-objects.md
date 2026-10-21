# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.ActiveSessions

[Source](../../baseline/2020%20Tables/z.ActiveSessions.sql)

Persistent copy of the active-request view plus SnapshotDate (local collection time), SessionID, and sequence-backed ActiveSessionID. Key (SnapshotDate, SessionID, ActiveSessionID); page-compressed on PS_SchemaZPartitionGeneric(ActiveSessionID). Measures retain DMV units: CPU/WaitTime/TotalElapsedTime milliseconds, logical/physical reads counters, GrantedMemory pages. No foreign keys.

Column definitions (including source defaults):

```text
SnapshotDate datetime not null constraint DF_z_ActiveSessions_SnapshotDate default(getdate()),
SessionID smallint not null,
ActiveSessionID bigint not null constraint DF_z_ActiveSessions_ActiveSessionID default (datediff_big(second,'1900-01-01',getutcdate())*(268435456)|next value for z.SeqGeneralID),
StartDate datetime not null,
BlockingSessionID smallint,
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
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
```



## z.SystemHealthEvent

[Source](../../baseline/2020%20Tables/z.SystemHealthEvent.sql)

Key (CollectSystemTime bigint, EventName nvarchar(128), EventHash uniqueidentifier); EventBody xml not null. CollectSystemTime encodes local event seconds plus milliseconds; EventHash is MD5 of XML binary serialization. Page-compressed partitioned by CollectSystemTime. No foreign keys.

Column definitions (including source defaults):

```text
CollectSystemTime bigint not null,
EventName nvarchar(128) not null,
EventHash uniqueidentifier not null,
EventBody xml not null,
```



## z.v_ActiveSessions

[Source](../../modules/1020%20Views/z.v_ActiveSessions.sql)

Current sys.dm_exec_requests joined to sessions/connections and SQL-text/query-plan functions, excluding @@SPID. Outputs SessionID, StartDate, BlockingSessionID, DurationInSecond, Status, Command, WaitType, WaitTime, WaitResource, LastWaitType, CPU, Reads, Writes, LogicalReads, TotalElapsedTime, DatabaseName, SQLText, QueryPlan, GrantedMemory, NestedLevel, RowCount, OpenTranCount, TransactionIsolationLevel, LoginName, HostName, HostAddress, ApplicationName. Not idle-session inventory; outer joins can yield null details.



## z.v_CPUMemoryStats

[Source](../../modules/1020%20Views/z.v_CPUMemoryStats.sql)

Scheduler-monitor ring-buffer XML -> RecordID, Date, SystemIdle, SQLProcessUtilization, Other, UserModeTime, KernelModeTime, PageFaults, WorkingSetDelta, MemoryUtilizationPercentage. Other=100-idle-SQL percentage; mode times are 100ns units. Retention is ring-buffer lifetime, not a persisted series.



## z.v_IndexSpaceUsage

[Source](../../modules/1020%20Views/z.v_IndexSpaceUsage.sql)

One DMV partition/index row: PartitionID, ObjectID, SchemaName, ObjectName, IndexID, IndexName, PartitionNumber, Rows, SpaceUsedMB, SpaceReservedMB, FreeSpaceMB plus in-row/LOB/overflow/total page counts. Rows is DMV row_count; space conversion uses 8.192/1024 per page, so labelled MB is not the usual binary conversion.



## z.v_ObjectSpaceUsed

[Source](../../modules/1020%20Views/z.v_ObjectSpaceUsed.sql)

Aggregate DMV allocation by object; exclude memory-optimized tables and include internal XML/spatial allocation types 202/204. Outputs SchemaName, TableName, RowCount, ReservedKB, DataKB, IndexSize, Unused. All size expressions multiply pages by 8 (KB); only base index rows contribute RowCount.

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
BlockingSessionID smallint,
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
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
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
BlockingSessionID smallint,
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
OpenTranCount int not null,
TransactionIsolationLevel smallint not null,
LoginName nvarchar(128),
HostName nvarchar(128),
HostAddress nvarchar(48),
ApplicationName nvarchar(128),
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
