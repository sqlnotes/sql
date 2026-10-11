# Supporting objects and utilities

[Subsystem](../readme.md) | [Object index](readme.md)

## Access and behavior

Views/functions here read data without modifying it. Table access requires the corresponding select or write permission. Server/database catalog and DMV visibility can hide rows or reject access; permission on a wrapper alone does not guarantee access through every underlying system object. Definitions do not grant caller privileges. Units and interpretation below follow the expressions in source.

## z.Trace

[Source](../../baseline/2020%20Tables/z.Trace.sql)

TraceID primary key; Name unique; Description, CreationDate, ModificationDate, ReceivingTable, CreatorSessionID. Times default getdate; creator defaults @@spid. Metadata persists until unavailable/closed entries are deleted.

Column definitions (including source defaults):

```text
TraceID int,
Name nvarchar(128) not null,
Description nvarchar(max),
CreationDate datetime not null constraint DF_z_Trace_CreationDate default(getdate()),
ModificationDate datetime not null constraint DF_z_Trace_ModificationDate default(getdate()),
ReceivingTable nvarchar(128) not null,
CreatorSessionID int not null constraint DF_z_Trace_CreatorSessionID default(@@spid),
```



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



## z.TraceTrigger

[Source](../../baseline/2020%20Tables/z.TraceTrigger.sql)

Callback metadata, not a SQL DML trigger. Key (TraceID, EventName); ProcedureName names callback. FK to z.Trace with on delete cascade. EventName=all callback receives positional TraceSequence only; event-specific callbacks receive TraceSequence, TraceID, EventName. No callback existence/signature check at insert.

Column definitions (including source defaults):

```text
TraceID int,
EventName varchar(128) not null,
ProcedureName nvarchar(128) not null
```



## z.v_Trace

[Source](../../modules/1020%20Views/z.v_Trace.sql)

z.Trace plus derived Status from sys.traces: Stopped, Running, or Not Available. Metadata-only traces can outlive native traces.



## z.v_TraceColumn

[Source](../../modules/1020%20Views/z.v_TraceColumn.sql)

SQL Trace column catalog -> ColumnID, ColumnName, SystemDataType, DataType, MaxSize, Definition, IsFilterable, IsRepeatable, IsRepeatedBase. Converts image/text definitions to varbinary(max)/nvarchar(max).



## z.v_TraceEvent

[Source](../../modules/1020%20Views/z.v_TraceEvent.sql)

SQL Trace category/event catalog -> TraceEventID, CategoryName, EventName.



## z.v_TraceEventColumn

[Source](../../modules/1020%20Views/z.v_TraceEventColumn.sql)

Allowed event/column bindings -> TraceEventID, CategoryName, EventName, ColumnID, ColumnName, DataType, MaxSize and three capability flags.



## z.v_TraceMetaData

Generated by [z.usp_TraceRefreshMetaData](z.usp_TraceRefreshMetaData.md). Event/category/ID plus one capability flag per current SQL Trace column. No parameters or persistent storage.

## z.v_TraceDefinition

Generated by [z.usp_TraceRefreshMetaData](z.usp_TraceRefreshMetaData.md). TraceID, IsActive, CategoryName, EventName, TraceEventID, IsEventSelected plus one selection/filter string per trace column. Empty strings can mean a selected column without a filter; null can mean unselected. Server trace visibility controls rows.

## Generated receiving tables

[z.usp_TraceCollectAndClose](z.usp_TraceCollectAndClose.md) creates a missing receiving table from TraceSequence/EventID/EventName and then adds nullable columns from z.v_TraceColumn. Existing columns are not altered or type-validated. Tables survive trace closure; no per-trace DML trigger is generated. z.TraceTrigger configures procedural callbacks instead.
