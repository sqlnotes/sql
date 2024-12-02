if object_id('z.TestSourceTable_usp_CopyTableSchema') is not null
	drop table z.TestSourceTable_usp_CopyTableSchema
go
if object_id('z.TestTargetTable_usp_CopyTableSchema') is not null
	drop table z.TestTargetTable_usp_CopyTableSchema
go

create table z.TestSourceTable_usp_CopyTableSchema
(
ID int identity(1,1) not null, F01 bigint, F02 binary(10), f03 bit not null, f04 char(20), f05 date, 
F06 datetime constraint DF_z_TestSourceTable_usp_CopyTableSchema_F06 default(getdate()), 
F07 datetime2(0), F08 datetime2(7), F09 datetime2, F10 datetimeoffset,
F11 datetimeoffset(0), F12 datetimeoffset(6), F13 datetimeoffset(7), F14 decimal, F15 decimal(12), F16 decimal(38, 8), F17 float, F18 geography, F19 geometry, F20 hierarchyid,
F21 image, F22 int, 
F23 money constraint DF_z_TestSourceTable_usp_CopyTableSchema_F23 default(0), 
F24 nchar(30), F25 ntext, F26 numeric, F27 numeric(12), F28 numeric(38, 8), F29 nvarchar(60), F30 nvarchar(max),
F31 real, F32 smalldatetime, F33 smallint, F34 smallmoney, F35 sql_variant, F36 sysname, F37 text, F38 time, F39 time(3), F40 time(7),
F41 timestamp, F42 tinyint, F43 uniqueidentifier, F44 varbinary(20), F45 varbinary(max), F46 varchar(20), F47 varchar(max), F48 xml,
)
alter table z.TestSourceTable_usp_CopyTableSchema add constraint PK_z_TestSourceTable_usp_CopyTableSchema primary key(ID)
alter table z.TestSourceTable_usp_CopyTableSchema add constraint UQ_z_TestSourceTable_usp_CopyTableSchema_f04 unique(f04)
create index IX_z_TestSourceTable_usp_CopyTableSchema_F36 on z.TestSourceTable_usp_CopyTableSchema(F36)
create index IX_z_TestSourceTable_usp_CopyTableSchema_F43_F44 on z.TestSourceTable_usp_CopyTableSchema(F43, F44)
create columnstore index IX_CS_z_TestSourceTable_usp_CopyTableSchema on z.TestSourceTable_usp_CopyTableSchema(F01,F31,F42)
create index IX_z_TestSourceTable_usp_CopyTableSchema_F14 on z.TestSourceTable_usp_CopyTableSchema(F14) where (F28 =1)
create index IX_z_TestSourceTable_usp_CopyTableSchema_F15 on z.TestSourceTable_usp_CopyTableSchema(F15) include(F16, F17) where (F28 =1)
create unique index IX_z_TestSourceTable_usp_CopyTableSchema_F33 on z.TestSourceTable_usp_CopyTableSchema(F33) with (ignore_dup_key=on)

create primary xml index IX_XML_PR_z_TestSourceTable_usp_CopyTableSchema_F48 on z.TestSourceTable_usp_CopyTableSchema(F48)
create xml index IX_XML_P_z_TestSourceTable_usp_CopyTableSchema_F48_PATH on z.TestSourceTable_usp_CopyTableSchema(F48) using xml index IX_XML_PR_z_TestSourceTable_usp_CopyTableSchema_F48 for path;
create xml index IX_XML_V_z_TestSourceTable_usp_CopyTableSchema_F48_VALUE on z.TestSourceTable_usp_CopyTableSchema(F48) using xml index IX_XML_PR_z_TestSourceTable_usp_CopyTableSchema_F48 for value;
create xml index IX_XML_R_z_TestSourceTable_usp_CopyTableSchema_F48_PROPERTY on z.TestSourceTable_usp_CopyTableSchema(F48) using xml index IX_XML_PR_z_TestSourceTable_usp_CopyTableSchema_F48 for property;

--select * from z.v_Objects where ObjectID = object_id('z.TestSourceTable_usp_CopyTableSchema')
--select * from z.v_Indexes where ObjectID = object_id('z.TestSourceTable_usp_CopyTableSchema')
--select * from z.v_Objects where ObjectID = object_id('z.TestTargetTable_usp_CopyTableSchema')
--select * from z.v_Indexes where ObjectID = object_id('z.TestTargetTable_usp_CopyTableSchema')

go
exec z.usp_ForceNamingConvention 'z.TestSourceTable_usp_CopyTableSchema'
go
exec z.usp_CopyTableSchema	@FullSourceTableName = 'z.TestSourceTable_usp_CopyTableSchema',
							@FullTargetTableName = 'z.TestTargetTable_usp_CopyTableSchema',
							@FileGroupOrPartitionScheme = null,
							@DropTargetTableIfExists = 1,
							@CopyIdentity = 1,
							@CopyTableSchema = 1,
							@CopyIndexes = 1,
							@CopyXMLIndexes = 1,
							@CopyDefault = 1,
							@ScriptAfterTableCreation = null,
							@PrintCode = 1,
							@DataCompression = null

