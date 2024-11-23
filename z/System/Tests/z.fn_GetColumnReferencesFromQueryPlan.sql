declare @x xml = '<ShowPlanXML xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" Version="1.564" Build="16.0.4155.4" xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan">
  <BatchSequence>
    <Batch>
      <Statements>
        <StmtSimple StatementCompId="1" StatementEstRows="10000" StatementId="1" StatementOptmLevel="FULL" CardinalityEstimationModelVersion="160" StatementSubTreeCost="3.34333" StatementText="select * from [MyServer].msdb.dbo.sysjobs_view" StatementType="SELECT" QueryHash="0xD840BF5C3DF3B6BD" QueryPlanHash="0x772168D9E77F2859" RetrievedFromCache="true" StatementSqlHandle="0x0900F12FF542195DFD7905C9D5B0F1A02B170000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="0" StatementParameterizationType="0" SecurityPolicyApplied="false">
          <StatementSetOptions ANSI_NULLS="true" ANSI_PADDING="true" ANSI_WARNINGS="true" ARITHABORT="true" CONCAT_NULL_YIELDS_NULL="true" NUMERIC_ROUNDABORT="false" QUOTED_IDENTIFIER="true" />
          <QueryPlan DegreeOfParallelism="1" NonParallelPlanReason="CouldNotGenerateValidParallelPlan" CachedPlanSize="48" CompileTime="222" CompileCPU="222" CompileMemory="216">
            <MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" />
            <OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="28597" EstimatedPagesCached="39321" EstimatedAvailableDegreeOfParallelism="4" MaxCompileMemory="4154152" />
            <WaitStats>
              <Wait WaitType="OLEDB" WaitTimeMs="21" WaitCount="4" />
              <Wait WaitType="ASYNC_NETWORK_IO" WaitTimeMs="4" WaitCount="1" />
            </WaitStats>
            <QueryTimeStats CpuTime="22" ElapsedTime="26" />
            <RelOp AvgRowSize="914" EstimateCPU="3.34333" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="10000" LogicalOp="Compute Scalar" NodeId="0" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="3.34333">
              <OutputList>
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="job_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="name" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="enabled" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="description" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="start_step_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="category_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="owner_sid" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_eventlog" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_email" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_netsend" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_page" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_email_operator_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_netsend_operator_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_page_operator_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="delete_level" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_created" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_modified" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="version_number" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server_id" />
                <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="master_server" />
              </OutputList>
              <ComputeScalar>
                <DefinedValues>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="job_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[job_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="job_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[originating_server]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="name" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[name]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="name" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="enabled" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[enabled]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="enabled" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="description" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[description]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="description" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="start_step_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[start_step_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="start_step_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="category_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[category_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="category_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="owner_sid" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[owner_sid]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="owner_sid" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_eventlog" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_level_eventlog]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_eventlog" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_email" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_level_email]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_email" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_netsend" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_level_netsend]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_netsend" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_page" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_level_page]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_page" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_email_operator_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_email_operator_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_email_operator_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_netsend_operator_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_netsend_operator_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_netsend_operator_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_page_operator_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[notify_page_operator_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_page_operator_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="delete_level" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[delete_level]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="delete_level" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_created" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[date_created]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_created" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_modified" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[date_modified]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_modified" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="version_number" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[version_number]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="version_number" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server_id" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[originating_server_id]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server_id" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                  <DefinedValue>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="master_server" />
                    <ScalarOperator ScalarString="[MyServer].[msdb].[dbo].[sysjobs_view].[master_server]">
                      <Identifier>
                        <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="master_server" />
                      </Identifier>
                    </ScalarOperator>
                  </DefinedValue>
                </DefinedValues>
                <RelOp AvgRowSize="914" EstimateCPU="3.34333" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="10000" LogicalOp="Remote Query" NodeId="1" Parallel="false" PhysicalOp="Remote Query" EstimatedTotalSubtreeCost="3.34333">
                  <OutputList>
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="job_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="name" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="enabled" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="description" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="start_step_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="category_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="owner_sid" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_eventlog" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_email" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_netsend" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_level_page" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_email_operator_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_netsend_operator_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="notify_page_operator_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="delete_level" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_created" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="date_modified" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="version_number" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="originating_server_id" />
                    <ColumnReference Server="[MyServer]" Database="[msdb]" Schema="[dbo]" Table="[sysjobs_view]" Column="master_server" />
                  </OutputList>
                  <RunTimeInformation>
                    <RunTimeCountersPerThread Thread="0" ActualRebinds="1" ActualRewinds="0" ActualRows="27" Batches="0" ActualEndOfScans="1" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="22" ActualCPUms="22" ActualScans="0" ActualLogicalReads="0" ActualPhysicalReads="0" ActualReadAheads="0" ActualLobLogicalReads="0" ActualLobPhysicalReads="0" ActualLobReadAheads="0" />
                  </RunTimeInformation>
                  <RemoteQuery RemoteSource="MyServer" RemoteQuery="SELECT &quot;Tbl1002&quot;.&quot;job_id&quot; &quot;Col1005&quot;,&quot;Tbl1002&quot;.&quot;originating_server&quot; &quot;Col1006&quot;,&quot;Tbl1002&quot;.&quot;name&quot; &quot;Col1007&quot;,&quot;Tbl1002&quot;.&quot;enabled&quot; &quot;Col1008&quot;,&quot;Tbl1002&quot;.&quot;description&quot; &quot;Col1009&quot;,&quot;Tbl1002&quot;.&quot;start_step_id&quot; &quot;Col1010&quot;,&quot;Tbl1002&quot;.&quot;category_id&quot; &quot;Col1011&quot;,&quot;Tbl1002&quot;.&quot;owner_sid&quot; &quot;Col1012&quot;,&quot;Tbl1002&quot;.&quot;notify_level_eventlog&quot; &quot;Col1013&quot;,&quot;Tbl1002&quot;.&quot;notify_level_email&quot; &quot;Col1014&quot;,&quot;Tbl1002&quot;.&quot;notify_level_netsend&quot; &quot;Col1015&quot;,&quot;Tbl1002&quot;.&quot;notify_level_page&quot; &quot;Col1016&quot;,&quot;Tbl1002&quot;.&quot;notify_email_operator_id&quot; &quot;Col1017&quot;,&quot;Tbl1002&quot;.&quot;notify_netsend_operator_id&quot; &quot;Col1018&quot;,&quot;Tbl1002&quot;.&quot;notify_page_operator_id&quot; &quot;Col1019&quot;,&quot;Tbl1002&quot;.&quot;delete_level&quot; &quot;Col1020&quot;,&quot;Tbl1002&quot;.&quot;date_created&quot; &quot;Col1021&quot;,&quot;Tbl1002&quot;.&quot;date_modified&quot; &quot;Col1022&quot;,&quot;Tbl1002&quot;.&quot;version_number&quot; &quot;Col1023&quot;,&quot;Tbl1002&quot;.&quot;originating_server_id&quot; &quot;Col1024&quot;,&quot;Tbl1002&quot;.&quot;master_server&quot; &quot;Col1003&quot; FROM &quot;msdb&quot;.&quot;dbo&quot;.&quot;sysjobs_view&quot; &quot;Tbl1002&quot;" />
                </RelOp>
              </ComputeScalar>
            </RelOp>
          </QueryPlan>
        </StmtSimple>
      </Statements>
    </Batch>
  </BatchSequence>
</ShowPlanXML>'
if not exists(
				select *
				from z.fn_GetColumnReferencesFromQueryPlan(@x)
				where ServerName = 'MyServer'
					and DatabaseName = 'msdb'
					and SchemaName = 'dbo'
					and ObjectName = 'sysjobs_view'
					and ColumnName = 'delete_level'
			)
begin
	raiserror('Test1 z.fn_GetColumnReferencesFromQueryPlan failed.', 16, 1)
end
select @x = '<ShowPlanXML xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" Version="1.564" Build="16.0.4155.4" xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan">
  <BatchSequence>
    <Batch>
      <Statements>
        <StmtSimple StatementCompId="2" StatementEstRows="1" StatementId="1" StatementOptmLevel="FULL" CardinalityEstimationModelVersion="160" StatementSubTreeCost="202.882" StatementText="if not exists(&#xD;&#xA;				select *&#xD;&#xA;				from z.fn_GetColumnReferencesFromQueryPlan(@x)&#xD;&#xA;				where ServerName = ''MyServer''&#xD;&#xA;					and DatabaseName = ''msdb''&#xD;&#xA;					and SchemaName = ''dbo''&#xD;&#xA;					and ObjectName = ''sysjobs_view''&#xD;&#xA;					and ColumnName = ''delete_level''&#xD;&#xA;			)" StatementType="COND WITH QUERY" QueryHash="0x5C07E1A8DD9AF159" QueryPlanHash="0x3D6972F58BB09FA0" RetrievedFromCache="true" StatementSqlHandle="0x09004FE21DBDD2FED685BD7501775BCF5ECE0000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="0" StatementParameterizationType="0" SecurityPolicyApplied="false">
          <StatementSetOptions ANSI_NULLS="true" ANSI_PADDING="true" ANSI_WARNINGS="true" ARITHABORT="true" CONCAT_NULL_YIELDS_NULL="true" NUMERIC_ROUNDABORT="false" QUOTED_IDENTIFIER="true" />
          <QueryPlan DegreeOfParallelism="1" CachedPlanSize="160" CompileTime="15" CompileCPU="15" CompileMemory="1816">
            <Warnings>
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(64),[Expr1004],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0)" />
              <PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0)" />
            </Warnings>
            <MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" />
            <OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="28597" EstimatedPagesCached="39321" EstimatedAvailableDegreeOfParallelism="4" MaxCompileMemory="4216760" />
            <QueryTimeStats CpuTime="1" ElapsedTime="1" />
            <RelOp AvgRowSize="11" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="0" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="202.882">
              <OutputList>
                <ColumnReference Column="Expr1045" />
              </OutputList>
              <ComputeScalar>
                <DefinedValues>
                  <DefinedValue>
                    <ColumnReference Column="Expr1045" />
                    <ScalarOperator ScalarString="CASE WHEN [Expr1046] IS NULL THEN (1) ELSE (0) END">
                      <IF>
                        <Condition>
                          <ScalarOperator>
                            <Compare CompareOp="IS">
                              <ScalarOperator>
                                <Identifier>
                                  <ColumnReference Column="Expr1046" />
                                </Identifier>
                              </ScalarOperator>
                              <ScalarOperator>
                                <Const ConstValue="NULL" />
                              </ScalarOperator>
                            </Compare>
                          </ScalarOperator>
                        </Condition>
                        <Then>
                          <ScalarOperator>
                            <Const ConstValue="(1)" />
                          </ScalarOperator>
                        </Then>
                        <Else>
                          <ScalarOperator>
                            <Const ConstValue="(0)" />
                          </ScalarOperator>
                        </Else>
                      </IF>
                    </ScalarOperator>
                  </DefinedValue>
                </DefinedValues>
                <RelOp AvgRowSize="9" EstimateCPU="4.18E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Left Semi Join" NodeId="1" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="202.882">
                  <OutputList>
                    <ColumnReference Column="Expr1046" />
                  </OutputList>
                  <RunTimeInformation>
                    <RunTimeCountersPerThread Thread="0" ActualRows="1" Batches="0" ActualEndOfScans="1" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="1" ActualCPUms="1" />
                  </RunTimeInformation>
                  <NestedLoops Optimized="false">
                    <DefinedValues>
                      <DefinedValue>
                        <ColumnReference Column="Expr1046" />
                      </DefinedValue>
                    </DefinedValues>
                    <ProbeColumn>
                      <ColumnReference Column="Expr1046" />
                    </ProbeColumn>
                    <RelOp AvgRowSize="9" EstimateCPU="1.157E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Constant Scan" NodeId="2" Parallel="false" PhysicalOp="Constant Scan" EstimatedTotalSubtreeCost="1.157E-06">
                      <OutputList />
                      <RunTimeInformation>
                        <RunTimeCountersPerThread Thread="0" ActualRows="1" Batches="0" ActualEndOfScans="1" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                      </RunTimeInformation>
                      <ConstantScan />
                    </RelOp>
                    <RelOp AvgRowSize="9" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="3" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="202.882">
                      <OutputList />
                      <RunTimeInformation>
                        <RunTimeCountersPerThread Thread="0" ActualRows="1" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="1" ActualCPUms="1" />
                      </RunTimeInformation>
                      <Top RowCount="false" IsPercent="false" WithTies="false">
                        <TopExpression>
                          <ScalarOperator ScalarString="(1)">
                            <Const ConstValue="(1)" />
                          </ScalarOperator>
                        </TopExpression>
                        <RelOp AvgRowSize="9" EstimateCPU="1.08E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="4" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="202.882">
                          <OutputList />
                          <RunTimeInformation>
                            <RunTimeCountersPerThread Thread="0" ActualRows="1" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="1" ActualCPUms="1" />
                          </RunTimeInformation>
                          <Filter StartupExpression="false">
                            <RelOp AvgRowSize="211" EstimateCPU="4.18E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Inner Join" NodeId="5" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="202.882">
                              <OutputList>
                                <ColumnReference Column="Expr1042" />
                              </OutputList>
                              <RunTimeInformation>
                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                              </RunTimeInformation>
                              <NestedLoops Optimized="false">
                                <OuterReferences>
                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                </OuterReferences>
                                <RelOp AvgRowSize="461" EstimateCPU="1.08E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="6" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="201.881">
                                  <OutputList>
                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                  </OutputList>
                                  <RunTimeInformation>
                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                  </RunTimeInformation>
                                  <Filter StartupExpression="false">
                                    <RelOp AvgRowSize="663" EstimateCPU="4.18E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Inner Join" NodeId="7" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="201.881">
                                      <OutputList>
                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                        <ColumnReference Column="Expr1035" />
                                      </OutputList>
                                      <RunTimeInformation>
                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                      </RunTimeInformation>
                                      <NestedLoops Optimized="false">
                                        <OuterReferences>
                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                        </OuterReferences>
                                        <RelOp AvgRowSize="461" EstimateCPU="1.944E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="8" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="200.881">
                                          <OutputList>
                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                          </OutputList>
                                          <RunTimeInformation>
                                            <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                          </RunTimeInformation>
                                          <Filter StartupExpression="false">
                                            <RelOp AvgRowSize="663" EstimateCPU="7.524E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1.8" LogicalOp="Inner Join" NodeId="9" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="200.881">
                                              <OutputList>
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                <ColumnReference Column="Expr1028" />
                                              </OutputList>
                                              <RunTimeInformation>
                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                              </RunTimeInformation>
                                              <NestedLoops Optimized="false">
                                                <OuterReferences>
                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                </OuterReferences>
                                                <RelOp AvgRowSize="461" EstimateCPU="1.944E-05" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1.8" LogicalOp="Filter" NodeId="10" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="199.08">
                                                  <OutputList>
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                  </OutputList>
                                                  <RunTimeInformation>
                                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                  </RunTimeInformation>
                                                  <Filter StartupExpression="false">
                                                    <RelOp AvgRowSize="663" EstimateCPU="7.524E-05" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Inner Join" NodeId="11" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="199.08">
                                                      <OutputList>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                        <ColumnReference Column="Expr1021" />
                                                      </OutputList>
                                                      <RunTimeInformation>
                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                      </RunTimeInformation>
                                                      <NestedLoops Optimized="false">
                                                        <OuterReferences>
                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                        </OuterReferences>
                                                        <RelOp AvgRowSize="461" EstimateCPU="0.0001944" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Filter" NodeId="12" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="181.073">
                                                          <OutputList>
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                          </OutputList>
                                                          <RunTimeInformation>
                                                            <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                          </RunTimeInformation>
                                                          <Filter StartupExpression="false">
                                                            <RelOp AvgRowSize="663" EstimateCPU="0.0007524" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="180" LogicalOp="Inner Join" NodeId="13" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="181.073">
                                                              <OutputList>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                <ColumnReference Column="Expr1014" />
                                                              </OutputList>
                                                              <RunTimeInformation>
                                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                              </RunTimeInformation>
                                                              <NestedLoops Optimized="false">
                                                                <OuterReferences>
                                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                </OuterReferences>
                                                                <RelOp AvgRowSize="461" EstimateCPU="0.0007524" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="180" LogicalOp="Left Semi Join" NodeId="14" Parallel="false" PhysicalOp="Nested Loops" EstimatedTotalSubtreeCost="1.00515">
                                                                  <OutputList>
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                  </OutputList>
                                                                  <RunTimeInformation>
                                                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                  </RunTimeInformation>
                                                                  <NestedLoops Optimized="false">
                                                                    <OuterReferences>
                                                                      <ColumnReference Table="[XML Reader with XPath filter]" Column="tagname" />
                                                                    </OuterReferences>
                                                                    <RelOp AvgRowSize="4463" EstimateCPU="9.6E-05" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="180" LogicalOp="Filter" NodeId="15" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="1.0041">
                                                                      <OutputList>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="tagname" />
                                                                      </OutputList>
                                                                      <RunTimeInformation>
                                                                        <RunTimeCountersPerThread Thread="0" ActualRebinds="1" ActualRewinds="0" ActualRows="31" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                      </RunTimeInformation>
                                                                      <Filter StartupExpression="true">
                                                                        <RelOp AvgRowSize="4463" EstimateCPU="1.004" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="200" LogicalOp="Table-valued function" NodeId="16" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="1.004">
                                                                          <OutputList>
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="tagname" />
                                                                          </OutputList>
                                                                          <MemoryFractions Input="0" Output="0" />
                                                                          <RunTimeInformation>
                                                                            <RunTimeCountersPerThread Thread="0" ActualRebinds="1" ActualRewinds="0" ActualRows="31" Batches="0" ActualEndOfScans="0" ActualExecutions="1" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                          </RunTimeInformation>
                                                                          <TableValuedFunction>
                                                                            <DefinedValues>
                                                                              <DefinedValue>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                              </DefinedValue>
                                                                              <DefinedValue>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="tagname" />
                                                                              </DefinedValue>
                                                                            </DefinedValues>
                                                                            <Object Table="[XML Reader with XPath filter]" />
                                                                            <ParameterList>
                                                                              <ScalarOperator ScalarString="[@x]">
                                                                                <Identifier>
                                                                                  <ColumnReference Column="@x" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="(0)">
                                                                                <Const ConstValue="(0)" />
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="NULL">
                                                                                <Const ConstValue="NULL" />
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="NULL">
                                                                                <Const ConstValue="NULL" />
                                                                              </ScalarOperator>
                                                                            </ParameterList>
                                                                          </TableValuedFunction>
                                                                        </RelOp>
                                                                        <Predicate>
                                                                          <ScalarOperator ScalarString="[@x] IS NOT NULL">
                                                                            <Compare CompareOp="IS NOT">
                                                                              <ScalarOperator>
                                                                                <Identifier>
                                                                                  <ColumnReference Column="@x" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator>
                                                                                <Const ConstValue="NULL" />
                                                                              </ScalarOperator>
                                                                            </Compare>
                                                                          </ScalarOperator>
                                                                        </Predicate>
                                                                      </Filter>
                                                                    </RelOp>
                                                                    <RelOp AvgRowSize="9" EstimateCPU="6.8E-07" EstimateIO="0" EstimateRebinds="90" EstimateRewinds="89" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="17" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="0.000302557">
                                                                      <OutputList />
                                                                      <RunTimeInformation>
                                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="15" ActualExecutions="31" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                      </RunTimeInformation>
                                                                      <Filter StartupExpression="false">
                                                                        <RelOp AvgRowSize="4035" EstimateCPU="1.157E-06" EstimateIO="0" EstimateRebinds="90" EstimateRewinds="89" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Constant Scan" NodeId="18" Parallel="false" PhysicalOp="Constant Scan" EstimatedTotalSubtreeCost="0.000180157">
                                                                          <OutputList>
                                                                            <ColumnReference Column="Expr1004" />
                                                                          </OutputList>
                                                                          <RunTimeInformation>
                                                                            <RunTimeCountersPerThread Thread="0" ActualRows="31" Batches="0" ActualEndOfScans="15" ActualExecutions="31" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                          </RunTimeInformation>
                                                                          <ConstantScan>
                                                                            <Values>
                                                                              <Row>
                                                                                <ScalarOperator ScalarString="CONVERT_IMPLICIT(nvarchar(max),isnull(CONVERT_IMPLICIT(nvarchar(4000),XML Reader with XPath filter.[tagname],0),N''''),0)">
                                                                                  <Convert DataType="nvarchar(max)" Length="2147483647" Style="0" Implicit="true">
                                                                                    <ScalarOperator>
                                                                                      <Intrinsic FunctionName="isnull">
                                                                                        <ScalarOperator>
                                                                                          <Convert DataType="nvarchar" Length="8000" Style="0" Implicit="true">
                                                                                            <ScalarOperator>
                                                                                              <Identifier>
                                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="tagname" />
                                                                                              </Identifier>
                                                                                            </ScalarOperator>
                                                                                          </Convert>
                                                                                        </ScalarOperator>
                                                                                        <ScalarOperator>
                                                                                          <Const ConstValue="N''''" />
                                                                                        </ScalarOperator>
                                                                                      </Intrinsic>
                                                                                    </ScalarOperator>
                                                                                  </Convert>
                                                                                </ScalarOperator>
                                                                              </Row>
                                                                            </Values>
                                                                          </ConstantScan>
                                                                        </RelOp>
                                                                        <Predicate>
                                                                          <ScalarOperator ScalarString="CONVERT_IMPLICIT(sql_variant,CONVERT_IMPLICIT(nvarchar(64),[Expr1004],0),0)=ColumnReference">
                                                                            <Compare CompareOp="EQ">
                                                                              <ScalarOperator>
                                                                                <Convert DataType="sql_variant" Style="0" Implicit="true">
                                                                                  <ScalarOperator>
                                                                                    <Convert DataType="nvarchar" Length="128" Style="0" Implicit="true">
                                                                                      <ScalarOperator>
                                                                                        <Identifier>
                                                                                          <ColumnReference Column="Expr1004" />
                                                                                        </Identifier>
                                                                                      </ScalarOperator>
                                                                                    </Convert>
                                                                                  </ScalarOperator>
                                                                                </Convert>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator>
                                                                                <Const ConstValue="ColumnReference" />
                                                                              </ScalarOperator>
                                                                            </Compare>
                                                                          </ScalarOperator>
                                                                        </Predicate>
                                                                      </Filter>
                                                                    </RelOp>
                                                                  </NestedLoops>
                                                                </RelOp>
                                                                <RelOp AvgRowSize="211" EstimateCPU="1.1E-06" EstimateIO="0" EstimateRebinds="179" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Aggregate" NodeId="19" Parallel="false" PhysicalOp="Stream Aggregate" EstimatedTotalSubtreeCost="180.067">
                                                                  <OutputList>
                                                                    <ColumnReference Column="Expr1014" />
                                                                  </OutputList>
                                                                  <RunTimeInformation>
                                                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                  </RunTimeInformation>
                                                                  <StreamAggregate>
                                                                    <DefinedValues>
                                                                      <DefinedValue>
                                                                        <ColumnReference Column="Expr1014" />
                                                                        <ScalarOperator ScalarString="MIN(CASE WHEN [@x] IS NULL THEN NULL ELSE CASE WHEN datalength(XML Reader with XPath filter.[value])&gt;=(128) THEN CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0) ELSE CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0) END END)">
                                                                          <Aggregate AggType="MIN" Distinct="false">
                                                                            <ScalarOperator>
                                                                              <IF>
                                                                                <Condition>
                                                                                  <ScalarOperator>
                                                                                    <Compare CompareOp="IS">
                                                                                      <ScalarOperator>
                                                                                        <Identifier>
                                                                                          <ColumnReference Column="@x" />
                                                                                        </Identifier>
                                                                                      </ScalarOperator>
                                                                                      <ScalarOperator>
                                                                                        <Const ConstValue="NULL" />
                                                                                      </ScalarOperator>
                                                                                    </Compare>
                                                                                  </ScalarOperator>
                                                                                </Condition>
                                                                                <Then>
                                                                                  <ScalarOperator>
                                                                                    <Const ConstValue="NULL" />
                                                                                  </ScalarOperator>
                                                                                </Then>
                                                                                <Else>
                                                                                  <ScalarOperator>
                                                                                    <IF>
                                                                                      <Condition>
                                                                                        <ScalarOperator>
                                                                                          <Compare CompareOp="GE">
                                                                                            <ScalarOperator>
                                                                                              <Intrinsic FunctionName="datalength">
                                                                                                <ScalarOperator>
                                                                                                  <Identifier>
                                                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                                  </Identifier>
                                                                                                </ScalarOperator>
                                                                                              </Intrinsic>
                                                                                            </ScalarOperator>
                                                                                            <ScalarOperator>
                                                                                              <Const ConstValue="(128)" />
                                                                                            </ScalarOperator>
                                                                                          </Compare>
                                                                                        </ScalarOperator>
                                                                                      </Condition>
                                                                                      <Then>
                                                                                        <ScalarOperator>
                                                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                                            <ScalarOperator>
                                                                                              <Identifier>
                                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                                              </Identifier>
                                                                                            </ScalarOperator>
                                                                                          </Convert>
                                                                                        </ScalarOperator>
                                                                                      </Then>
                                                                                      <Else>
                                                                                        <ScalarOperator>
                                                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                                            <ScalarOperator>
                                                                                              <Identifier>
                                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                              </Identifier>
                                                                                            </ScalarOperator>
                                                                                          </Convert>
                                                                                        </ScalarOperator>
                                                                                      </Else>
                                                                                    </IF>
                                                                                  </ScalarOperator>
                                                                                </Else>
                                                                              </IF>
                                                                            </ScalarOperator>
                                                                          </Aggregate>
                                                                        </ScalarOperator>
                                                                      </DefinedValue>
                                                                    </DefinedValues>
                                                                    <RelOp AvgRowSize="8045" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="179" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="20" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="180.067">
                                                                      <OutputList>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                      </OutputList>
                                                                      <RunTimeInformation>
                                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="16" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                      </RunTimeInformation>
                                                                      <Top RowCount="false" IsPercent="false" WithTies="false">
                                                                        <TopExpression>
                                                                          <ScalarOperator ScalarString="(1)">
                                                                            <Const ConstValue="(1)" />
                                                                          </ScalarOperator>
                                                                        </TopExpression>
                                                                        <RelOp AvgRowSize="8949" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="179" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="21" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="180.067">
                                                                          <OutputList>
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                            <ColumnReference Column="Expr1013" />
                                                                          </OutputList>
                                                                          <ComputeScalar>
                                                                            <DefinedValues>
                                                                              <DefinedValue>
                                                                                <ColumnReference Column="Expr1013" />
                                                                                <ScalarOperator ScalarString="0x58">
                                                                                  <Const ConstValue="0x58" />
                                                                                </ScalarOperator>
                                                                              </DefinedValue>
                                                                            </DefinedValues>
                                                                            <RelOp AvgRowSize="8497" EstimateCPU="1.224E-05" EstimateIO="0" EstimateRebinds="179" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="22" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="180.067">
                                                                              <OutputList>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                              </OutputList>
                                                                              <RunTimeInformation>
                                                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                              </RunTimeInformation>
                                                                              <Filter StartupExpression="false">
                                                                                <RelOp AvgRowSize="8497" EstimateCPU="1.00036" EstimateIO="0" EstimateRebinds="179" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Table-valued function" NodeId="23" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="180.065">
                                                                                  <OutputList>
                                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                                  </OutputList>
                                                                                  <MemoryFractions Input="0" Output="0" />
                                                                                  <RunTimeInformation>
                                                                                    <RunTimeCountersPerThread Thread="0" ActualRebinds="16" ActualRewinds="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                                  </RunTimeInformation>
                                                                                  <TableValuedFunction>
                                                                                    <DefinedValues>
                                                                                      <DefinedValue>
                                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                      </DefinedValue>
                                                                                      <DefinedValue>
                                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                      </DefinedValue>
                                                                                      <DefinedValue>
                                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                                      </DefinedValue>
                                                                                    </DefinedValues>
                                                                                    <Object Table="[XML Reader with XPath filter]" />
                                                                                    <ParameterList>
                                                                                      <ScalarOperator ScalarString="[@x]">
                                                                                        <Identifier>
                                                                                          <ColumnReference Column="@x" />
                                                                                        </Identifier>
                                                                                      </ScalarOperator>
                                                                                      <ScalarOperator ScalarString="(7)">
                                                                                        <Const ConstValue="(7)" />
                                                                                      </ScalarOperator>
                                                                                      <ScalarOperator ScalarString="XML Reader with XPath filter.[id]">
                                                                                        <Identifier>
                                                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                        </Identifier>
                                                                                      </ScalarOperator>
                                                                                      <ScalarOperator ScalarString="getdescendantlimit(XML Reader with XPath filter.[id])">
                                                                                        <Intrinsic FunctionName="getdescendantlimit">
                                                                                          <ScalarOperator>
                                                                                            <Identifier>
                                                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                            </Identifier>
                                                                                          </ScalarOperator>
                                                                                        </Intrinsic>
                                                                                      </ScalarOperator>
                                                                                    </ParameterList>
                                                                                  </TableValuedFunction>
                                                                                </RelOp>
                                                                                <Predicate>
                                                                                  <ScalarOperator ScalarString="XML Reader with XPath filter.[id]=getancestor(XML Reader with XPath filter.[id],(1))">
                                                                                    <Compare CompareOp="EQ">
                                                                                      <ScalarOperator>
                                                                                        <Identifier>
                                                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                        </Identifier>
                                                                                      </ScalarOperator>
                                                                                      <ScalarOperator>
                                                                                        <Intrinsic FunctionName="getancestor">
                                                                                          <ScalarOperator>
                                                                                            <Identifier>
                                                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                            </Identifier>
                                                                                          </ScalarOperator>
                                                                                          <ScalarOperator>
                                                                                            <Const ConstValue="(1)" />
                                                                                          </ScalarOperator>
                                                                                        </Intrinsic>
                                                                                      </ScalarOperator>
                                                                                    </Compare>
                                                                                  </ScalarOperator>
                                                                                </Predicate>
                                                                              </Filter>
                                                                            </RelOp>
                                                                          </ComputeScalar>
                                                                        </RelOp>
                                                                      </Top>
                                                                    </RelOp>
                                                                  </StreamAggregate>
                                                                </RelOp>
                                                              </NestedLoops>
                                                            </RelOp>
                                                            <Predicate>
                                                              <ScalarOperator ScalarString="replace(replace([Expr1014],N''['',N''''),N'']'',N'''')=N''MyServer''">
                                                                <Compare CompareOp="EQ">
                                                                  <ScalarOperator>
                                                                    <Intrinsic FunctionName="replace">
                                                                      <ScalarOperator>
                                                                        <Intrinsic FunctionName="replace">
                                                                          <ScalarOperator>
                                                                            <Identifier>
                                                                              <ColumnReference Column="Expr1014" />
                                                                            </Identifier>
                                                                          </ScalarOperator>
                                                                          <ScalarOperator>
                                                                            <Const ConstValue="N''[''" />
                                                                          </ScalarOperator>
                                                                          <ScalarOperator>
                                                                            <Const ConstValue="N''''" />
                                                                          </ScalarOperator>
                                                                        </Intrinsic>
                                                                      </ScalarOperator>
                                                                      <ScalarOperator>
                                                                        <Const ConstValue="N'']''" />
                                                                      </ScalarOperator>
                                                                      <ScalarOperator>
                                                                        <Const ConstValue="N''''" />
                                                                      </ScalarOperator>
                                                                    </Intrinsic>
                                                                  </ScalarOperator>
                                                                  <ScalarOperator>
                                                                    <Const ConstValue="N''MyServer''" />
                                                                  </ScalarOperator>
                                                                </Compare>
                                                              </ScalarOperator>
                                                            </Predicate>
                                                          </Filter>
                                                        </RelOp>
                                                        <RelOp AvgRowSize="211" EstimateCPU="1.1E-06" EstimateIO="0" EstimateRebinds="17" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Aggregate" NodeId="24" Parallel="false" PhysicalOp="Stream Aggregate" EstimatedTotalSubtreeCost="18.0067">
                                                          <OutputList>
                                                            <ColumnReference Column="Expr1021" />
                                                          </OutputList>
                                                          <RunTimeInformation>
                                                            <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                          </RunTimeInformation>
                                                          <StreamAggregate>
                                                            <DefinedValues>
                                                              <DefinedValue>
                                                                <ColumnReference Column="Expr1021" />
                                                                <ScalarOperator ScalarString="MIN(CASE WHEN [@x] IS NULL THEN NULL ELSE CASE WHEN datalength(XML Reader with XPath filter.[value])&gt;=(128) THEN CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0) ELSE CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0) END END)">
                                                                  <Aggregate AggType="MIN" Distinct="false">
                                                                    <ScalarOperator>
                                                                      <IF>
                                                                        <Condition>
                                                                          <ScalarOperator>
                                                                            <Compare CompareOp="IS">
                                                                              <ScalarOperator>
                                                                                <Identifier>
                                                                                  <ColumnReference Column="@x" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator>
                                                                                <Const ConstValue="NULL" />
                                                                              </ScalarOperator>
                                                                            </Compare>
                                                                          </ScalarOperator>
                                                                        </Condition>
                                                                        <Then>
                                                                          <ScalarOperator>
                                                                            <Const ConstValue="NULL" />
                                                                          </ScalarOperator>
                                                                        </Then>
                                                                        <Else>
                                                                          <ScalarOperator>
                                                                            <IF>
                                                                              <Condition>
                                                                                <ScalarOperator>
                                                                                  <Compare CompareOp="GE">
                                                                                    <ScalarOperator>
                                                                                      <Intrinsic FunctionName="datalength">
                                                                                        <ScalarOperator>
                                                                                          <Identifier>
                                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                          </Identifier>
                                                                                        </ScalarOperator>
                                                                                      </Intrinsic>
                                                                                    </ScalarOperator>
                                                                                    <ScalarOperator>
                                                                                      <Const ConstValue="(128)" />
                                                                                    </ScalarOperator>
                                                                                  </Compare>
                                                                                </ScalarOperator>
                                                                              </Condition>
                                                                              <Then>
                                                                                <ScalarOperator>
                                                                                  <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                                    <ScalarOperator>
                                                                                      <Identifier>
                                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                                      </Identifier>
                                                                                    </ScalarOperator>
                                                                                  </Convert>
                                                                                </ScalarOperator>
                                                                              </Then>
                                                                              <Else>
                                                                                <ScalarOperator>
                                                                                  <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                                    <ScalarOperator>
                                                                                      <Identifier>
                                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                      </Identifier>
                                                                                    </ScalarOperator>
                                                                                  </Convert>
                                                                                </ScalarOperator>
                                                                              </Else>
                                                                            </IF>
                                                                          </ScalarOperator>
                                                                        </Else>
                                                                      </IF>
                                                                    </ScalarOperator>
                                                                  </Aggregate>
                                                                </ScalarOperator>
                                                              </DefinedValue>
                                                            </DefinedValues>
                                                            <RelOp AvgRowSize="8045" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="17" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="25" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="18.0067">
                                                              <OutputList>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                              </OutputList>
                                                              <RunTimeInformation>
                                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="16" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                              </RunTimeInformation>
                                                              <Top RowCount="false" IsPercent="false" WithTies="false">
                                                                <TopExpression>
                                                                  <ScalarOperator ScalarString="(1)">
                                                                    <Const ConstValue="(1)" />
                                                                  </ScalarOperator>
                                                                </TopExpression>
                                                                <RelOp AvgRowSize="8949" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="17" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="26" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="18.0067">
                                                                  <OutputList>
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                    <ColumnReference Column="Expr1020" />
                                                                  </OutputList>
                                                                  <ComputeScalar>
                                                                    <DefinedValues>
                                                                      <DefinedValue>
                                                                        <ColumnReference Column="Expr1020" />
                                                                        <ScalarOperator ScalarString="0x58">
                                                                          <Const ConstValue="0x58" />
                                                                        </ScalarOperator>
                                                                      </DefinedValue>
                                                                    </DefinedValues>
                                                                    <RelOp AvgRowSize="8497" EstimateCPU="1.224E-05" EstimateIO="0" EstimateRebinds="17" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="27" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="18.0067">
                                                                      <OutputList>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                      </OutputList>
                                                                      <RunTimeInformation>
                                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                      </RunTimeInformation>
                                                                      <Filter StartupExpression="false">
                                                                        <RelOp AvgRowSize="8497" EstimateCPU="1.00036" EstimateIO="0" EstimateRebinds="17" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Table-valued function" NodeId="28" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="18.0065">
                                                                          <OutputList>
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                          </OutputList>
                                                                          <MemoryFractions Input="0" Output="0" />
                                                                          <RunTimeInformation>
                                                                            <RunTimeCountersPerThread Thread="0" ActualRebinds="16" ActualRewinds="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                          </RunTimeInformation>
                                                                          <TableValuedFunction>
                                                                            <DefinedValues>
                                                                              <DefinedValue>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                              </DefinedValue>
                                                                              <DefinedValue>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                              </DefinedValue>
                                                                              <DefinedValue>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                              </DefinedValue>
                                                                            </DefinedValues>
                                                                            <Object Table="[XML Reader with XPath filter]" />
                                                                            <ParameterList>
                                                                              <ScalarOperator ScalarString="[@x]">
                                                                                <Identifier>
                                                                                  <ColumnReference Column="@x" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="(7)">
                                                                                <Const ConstValue="(7)" />
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="XML Reader with XPath filter.[id]">
                                                                                <Identifier>
                                                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator ScalarString="getdescendantlimit(XML Reader with XPath filter.[id])">
                                                                                <Intrinsic FunctionName="getdescendantlimit">
                                                                                  <ScalarOperator>
                                                                                    <Identifier>
                                                                                      <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                    </Identifier>
                                                                                  </ScalarOperator>
                                                                                </Intrinsic>
                                                                              </ScalarOperator>
                                                                            </ParameterList>
                                                                          </TableValuedFunction>
                                                                        </RelOp>
                                                                        <Predicate>
                                                                          <ScalarOperator ScalarString="XML Reader with XPath filter.[id]=getancestor(XML Reader with XPath filter.[id],(1))">
                                                                            <Compare CompareOp="EQ">
                                                                              <ScalarOperator>
                                                                                <Identifier>
                                                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                </Identifier>
                                                                              </ScalarOperator>
                                                                              <ScalarOperator>
                                                                                <Intrinsic FunctionName="getancestor">
                                                                                  <ScalarOperator>
                                                                                    <Identifier>
                                                                                      <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                                    </Identifier>
                                                                                  </ScalarOperator>
                                                                                  <ScalarOperator>
                                                                                    <Const ConstValue="(1)" />
                                                                                  </ScalarOperator>
                                                                                </Intrinsic>
                                                                              </ScalarOperator>
                                                                            </Compare>
                                                                          </ScalarOperator>
                                                                        </Predicate>
                                                                      </Filter>
                                                                    </RelOp>
                                                                  </ComputeScalar>
                                                                </RelOp>
                                                              </Top>
                                                            </RelOp>
                                                          </StreamAggregate>
                                                        </RelOp>
                                                      </NestedLoops>
                                                    </RelOp>
                                                    <Predicate>
                                                      <ScalarOperator ScalarString="replace(replace([Expr1021],N''['',N''''),N'']'',N'''')=N''msdb''">
                                                        <Compare CompareOp="EQ">
                                                          <ScalarOperator>
                                                            <Intrinsic FunctionName="replace">
                                                              <ScalarOperator>
                                                                <Intrinsic FunctionName="replace">
                                                                  <ScalarOperator>
                                                                    <Identifier>
                                                                      <ColumnReference Column="Expr1021" />
                                                                    </Identifier>
                                                                  </ScalarOperator>
                                                                  <ScalarOperator>
                                                                    <Const ConstValue="N''[''" />
                                                                  </ScalarOperator>
                                                                  <ScalarOperator>
                                                                    <Const ConstValue="N''''" />
                                                                  </ScalarOperator>
                                                                </Intrinsic>
                                                              </ScalarOperator>
                                                              <ScalarOperator>
                                                                <Const ConstValue="N'']''" />
                                                              </ScalarOperator>
                                                              <ScalarOperator>
                                                                <Const ConstValue="N''''" />
                                                              </ScalarOperator>
                                                            </Intrinsic>
                                                          </ScalarOperator>
                                                          <ScalarOperator>
                                                            <Const ConstValue="N''msdb''" />
                                                          </ScalarOperator>
                                                        </Compare>
                                                      </ScalarOperator>
                                                    </Predicate>
                                                  </Filter>
                                                </RelOp>
                                                <RelOp AvgRowSize="211" EstimateCPU="1.1E-06" EstimateIO="0" EstimateRebinds="0.8" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Aggregate" NodeId="29" Parallel="false" PhysicalOp="Stream Aggregate" EstimatedTotalSubtreeCost="1.80067">
                                                  <OutputList>
                                                    <ColumnReference Column="Expr1028" />
                                                  </OutputList>
                                                  <RunTimeInformation>
                                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                  </RunTimeInformation>
                                                  <StreamAggregate>
                                                    <DefinedValues>
                                                      <DefinedValue>
                                                        <ColumnReference Column="Expr1028" />
                                                        <ScalarOperator ScalarString="MIN(CASE WHEN [@x] IS NULL THEN NULL ELSE CASE WHEN datalength(XML Reader with XPath filter.[value])&gt;=(128) THEN CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0) ELSE CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0) END END)">
                                                          <Aggregate AggType="MIN" Distinct="false">
                                                            <ScalarOperator>
                                                              <IF>
                                                                <Condition>
                                                                  <ScalarOperator>
                                                                    <Compare CompareOp="IS">
                                                                      <ScalarOperator>
                                                                        <Identifier>
                                                                          <ColumnReference Column="@x" />
                                                                        </Identifier>
                                                                      </ScalarOperator>
                                                                      <ScalarOperator>
                                                                        <Const ConstValue="NULL" />
                                                                      </ScalarOperator>
                                                                    </Compare>
                                                                  </ScalarOperator>
                                                                </Condition>
                                                                <Then>
                                                                  <ScalarOperator>
                                                                    <Const ConstValue="NULL" />
                                                                  </ScalarOperator>
                                                                </Then>
                                                                <Else>
                                                                  <ScalarOperator>
                                                                    <IF>
                                                                      <Condition>
                                                                        <ScalarOperator>
                                                                          <Compare CompareOp="GE">
                                                                            <ScalarOperator>
                                                                              <Intrinsic FunctionName="datalength">
                                                                                <ScalarOperator>
                                                                                  <Identifier>
                                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                                  </Identifier>
                                                                                </ScalarOperator>
                                                                              </Intrinsic>
                                                                            </ScalarOperator>
                                                                            <ScalarOperator>
                                                                              <Const ConstValue="(128)" />
                                                                            </ScalarOperator>
                                                                          </Compare>
                                                                        </ScalarOperator>
                                                                      </Condition>
                                                                      <Then>
                                                                        <ScalarOperator>
                                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                            <ScalarOperator>
                                                                              <Identifier>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                              </Identifier>
                                                                            </ScalarOperator>
                                                                          </Convert>
                                                                        </ScalarOperator>
                                                                      </Then>
                                                                      <Else>
                                                                        <ScalarOperator>
                                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                            <ScalarOperator>
                                                                              <Identifier>
                                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                              </Identifier>
                                                                            </ScalarOperator>
                                                                          </Convert>
                                                                        </ScalarOperator>
                                                                      </Else>
                                                                    </IF>
                                                                  </ScalarOperator>
                                                                </Else>
                                                              </IF>
                                                            </ScalarOperator>
                                                          </Aggregate>
                                                        </ScalarOperator>
                                                      </DefinedValue>
                                                    </DefinedValues>
                                                    <RelOp AvgRowSize="8045" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0.8" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="30" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="1.80067">
                                                      <OutputList>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                      </OutputList>
                                                      <RunTimeInformation>
                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="16" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                      </RunTimeInformation>
                                                      <Top RowCount="false" IsPercent="false" WithTies="false">
                                                        <TopExpression>
                                                          <ScalarOperator ScalarString="(1)">
                                                            <Const ConstValue="(1)" />
                                                          </ScalarOperator>
                                                        </TopExpression>
                                                        <RelOp AvgRowSize="8949" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0.8" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="31" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="1.80067">
                                                          <OutputList>
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                            <ColumnReference Column="Expr1027" />
                                                          </OutputList>
                                                          <ComputeScalar>
                                                            <DefinedValues>
                                                              <DefinedValue>
                                                                <ColumnReference Column="Expr1027" />
                                                                <ScalarOperator ScalarString="0x58">
                                                                  <Const ConstValue="0x58" />
                                                                </ScalarOperator>
                                                              </DefinedValue>
                                                            </DefinedValues>
                                                            <RelOp AvgRowSize="8497" EstimateCPU="1.224E-05" EstimateIO="0" EstimateRebinds="0.8" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="32" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="1.80067">
                                                              <OutputList>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                              </OutputList>
                                                              <RunTimeInformation>
                                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                              </RunTimeInformation>
                                                              <Filter StartupExpression="false">
                                                                <RelOp AvgRowSize="8497" EstimateCPU="1.00036" EstimateIO="0" EstimateRebinds="0.8" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Table-valued function" NodeId="33" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="1.80065">
                                                                  <OutputList>
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                  </OutputList>
                                                                  <MemoryFractions Input="0" Output="0" />
                                                                  <RunTimeInformation>
                                                                    <RunTimeCountersPerThread Thread="0" ActualRebinds="16" ActualRewinds="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                                  </RunTimeInformation>
                                                                  <TableValuedFunction>
                                                                    <DefinedValues>
                                                                      <DefinedValue>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                      </DefinedValue>
                                                                      <DefinedValue>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                      </DefinedValue>
                                                                      <DefinedValue>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                      </DefinedValue>
                                                                    </DefinedValues>
                                                                    <Object Table="[XML Reader with XPath filter]" />
                                                                    <ParameterList>
                                                                      <ScalarOperator ScalarString="[@x]">
                                                                        <Identifier>
                                                                          <ColumnReference Column="@x" />
                                                                        </Identifier>
                                                                      </ScalarOperator>
                                                                      <ScalarOperator ScalarString="(7)">
                                                                        <Const ConstValue="(7)" />
                                                                      </ScalarOperator>
                                                                      <ScalarOperator ScalarString="XML Reader with XPath filter.[id]">
                                                                        <Identifier>
                                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                        </Identifier>
                                                                      </ScalarOperator>
                                                                      <ScalarOperator ScalarString="getdescendantlimit(XML Reader with XPath filter.[id])">
                                                                        <Intrinsic FunctionName="getdescendantlimit">
                                                                          <ScalarOperator>
                                                                            <Identifier>
                                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                            </Identifier>
                                                                          </ScalarOperator>
                                                                        </Intrinsic>
                                                                      </ScalarOperator>
                                                                    </ParameterList>
                                                                  </TableValuedFunction>
                                                                </RelOp>
                                                                <Predicate>
                                                                  <ScalarOperator ScalarString="XML Reader with XPath filter.[id]=getancestor(XML Reader with XPath filter.[id],(1))">
                                                                    <Compare CompareOp="EQ">
                                                                      <ScalarOperator>
                                                                        <Identifier>
                                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                        </Identifier>
                                                                      </ScalarOperator>
                                                                      <ScalarOperator>
                                                                        <Intrinsic FunctionName="getancestor">
                                                                          <ScalarOperator>
                                                                            <Identifier>
                                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                            </Identifier>
                                                                          </ScalarOperator>
                                                                          <ScalarOperator>
                                                                            <Const ConstValue="(1)" />
                                                                          </ScalarOperator>
                                                                        </Intrinsic>
                                                                      </ScalarOperator>
                                                                    </Compare>
                                                                  </ScalarOperator>
                                                                </Predicate>
                                                              </Filter>
                                                            </RelOp>
                                                          </ComputeScalar>
                                                        </RelOp>
                                                      </Top>
                                                    </RelOp>
                                                  </StreamAggregate>
                                                </RelOp>
                                              </NestedLoops>
                                            </RelOp>
                                            <Predicate>
                                              <ScalarOperator ScalarString="replace(replace([Expr1028],N''['',N''''),N'']'',N'''')=N''dbo''">
                                                <Compare CompareOp="EQ">
                                                  <ScalarOperator>
                                                    <Intrinsic FunctionName="replace">
                                                      <ScalarOperator>
                                                        <Intrinsic FunctionName="replace">
                                                          <ScalarOperator>
                                                            <Identifier>
                                                              <ColumnReference Column="Expr1028" />
                                                            </Identifier>
                                                          </ScalarOperator>
                                                          <ScalarOperator>
                                                            <Const ConstValue="N''[''" />
                                                          </ScalarOperator>
                                                          <ScalarOperator>
                                                            <Const ConstValue="N''''" />
                                                          </ScalarOperator>
                                                        </Intrinsic>
                                                      </ScalarOperator>
                                                      <ScalarOperator>
                                                        <Const ConstValue="N'']''" />
                                                      </ScalarOperator>
                                                      <ScalarOperator>
                                                        <Const ConstValue="N''''" />
                                                      </ScalarOperator>
                                                    </Intrinsic>
                                                  </ScalarOperator>
                                                  <ScalarOperator>
                                                    <Const ConstValue="N''dbo''" />
                                                  </ScalarOperator>
                                                </Compare>
                                              </ScalarOperator>
                                            </Predicate>
                                          </Filter>
                                        </RelOp>
                                        <RelOp AvgRowSize="211" EstimateCPU="1.1E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Aggregate" NodeId="34" Parallel="false" PhysicalOp="Stream Aggregate" EstimatedTotalSubtreeCost="1.00037">
                                          <OutputList>
                                            <ColumnReference Column="Expr1035" />
                                          </OutputList>
                                          <RunTimeInformation>
                                            <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                          </RunTimeInformation>
                                          <StreamAggregate>
                                            <DefinedValues>
                                              <DefinedValue>
                                                <ColumnReference Column="Expr1035" />
                                                <ScalarOperator ScalarString="MIN(CASE WHEN [@x] IS NULL THEN NULL ELSE CASE WHEN datalength(XML Reader with XPath filter.[value])&gt;=(128) THEN CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0) ELSE CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0) END END)">
                                                  <Aggregate AggType="MIN" Distinct="false">
                                                    <ScalarOperator>
                                                      <IF>
                                                        <Condition>
                                                          <ScalarOperator>
                                                            <Compare CompareOp="IS">
                                                              <ScalarOperator>
                                                                <Identifier>
                                                                  <ColumnReference Column="@x" />
                                                                </Identifier>
                                                              </ScalarOperator>
                                                              <ScalarOperator>
                                                                <Const ConstValue="NULL" />
                                                              </ScalarOperator>
                                                            </Compare>
                                                          </ScalarOperator>
                                                        </Condition>
                                                        <Then>
                                                          <ScalarOperator>
                                                            <Const ConstValue="NULL" />
                                                          </ScalarOperator>
                                                        </Then>
                                                        <Else>
                                                          <ScalarOperator>
                                                            <IF>
                                                              <Condition>
                                                                <ScalarOperator>
                                                                  <Compare CompareOp="GE">
                                                                    <ScalarOperator>
                                                                      <Intrinsic FunctionName="datalength">
                                                                        <ScalarOperator>
                                                                          <Identifier>
                                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                          </Identifier>
                                                                        </ScalarOperator>
                                                                      </Intrinsic>
                                                                    </ScalarOperator>
                                                                    <ScalarOperator>
                                                                      <Const ConstValue="(128)" />
                                                                    </ScalarOperator>
                                                                  </Compare>
                                                                </ScalarOperator>
                                                              </Condition>
                                                              <Then>
                                                                <ScalarOperator>
                                                                  <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                    <ScalarOperator>
                                                                      <Identifier>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                                      </Identifier>
                                                                    </ScalarOperator>
                                                                  </Convert>
                                                                </ScalarOperator>
                                                              </Then>
                                                              <Else>
                                                                <ScalarOperator>
                                                                  <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                                    <ScalarOperator>
                                                                      <Identifier>
                                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                      </Identifier>
                                                                    </ScalarOperator>
                                                                  </Convert>
                                                                </ScalarOperator>
                                                              </Else>
                                                            </IF>
                                                          </ScalarOperator>
                                                        </Else>
                                                      </IF>
                                                    </ScalarOperator>
                                                  </Aggregate>
                                                </ScalarOperator>
                                              </DefinedValue>
                                            </DefinedValues>
                                            <RelOp AvgRowSize="8045" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="35" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="1.00037">
                                              <OutputList>
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                              </OutputList>
                                              <RunTimeInformation>
                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="16" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                              </RunTimeInformation>
                                              <Top RowCount="false" IsPercent="false" WithTies="false">
                                                <TopExpression>
                                                  <ScalarOperator ScalarString="(1)">
                                                    <Const ConstValue="(1)" />
                                                  </ScalarOperator>
                                                </TopExpression>
                                                <RelOp AvgRowSize="8949" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="36" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="1.00037">
                                                  <OutputList>
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                    <ColumnReference Column="Expr1034" />
                                                  </OutputList>
                                                  <ComputeScalar>
                                                    <DefinedValues>
                                                      <DefinedValue>
                                                        <ColumnReference Column="Expr1034" />
                                                        <ScalarOperator ScalarString="0x58">
                                                          <Const ConstValue="0x58" />
                                                        </ScalarOperator>
                                                      </DefinedValue>
                                                    </DefinedValues>
                                                    <RelOp AvgRowSize="8497" EstimateCPU="1.224E-05" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="37" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="1.00037">
                                                      <OutputList>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                      </OutputList>
                                                      <RunTimeInformation>
                                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                      </RunTimeInformation>
                                                      <Filter StartupExpression="false">
                                                        <RelOp AvgRowSize="8497" EstimateCPU="1.00036" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Table-valued function" NodeId="38" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="1.00036">
                                                          <OutputList>
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                          </OutputList>
                                                          <MemoryFractions Input="0" Output="0" />
                                                          <RunTimeInformation>
                                                            <RunTimeCountersPerThread Thread="0" ActualRebinds="16" ActualRewinds="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                          </RunTimeInformation>
                                                          <TableValuedFunction>
                                                            <DefinedValues>
                                                              <DefinedValue>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                              </DefinedValue>
                                                              <DefinedValue>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                              </DefinedValue>
                                                              <DefinedValue>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                              </DefinedValue>
                                                            </DefinedValues>
                                                            <Object Table="[XML Reader with XPath filter]" />
                                                            <ParameterList>
                                                              <ScalarOperator ScalarString="[@x]">
                                                                <Identifier>
                                                                  <ColumnReference Column="@x" />
                                                                </Identifier>
                                                              </ScalarOperator>
                                                              <ScalarOperator ScalarString="(7)">
                                                                <Const ConstValue="(7)" />
                                                              </ScalarOperator>
                                                              <ScalarOperator ScalarString="XML Reader with XPath filter.[id]">
                                                                <Identifier>
                                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                </Identifier>
                                                              </ScalarOperator>
                                                              <ScalarOperator ScalarString="getdescendantlimit(XML Reader with XPath filter.[id])">
                                                                <Intrinsic FunctionName="getdescendantlimit">
                                                                  <ScalarOperator>
                                                                    <Identifier>
                                                                      <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                    </Identifier>
                                                                  </ScalarOperator>
                                                                </Intrinsic>
                                                              </ScalarOperator>
                                                            </ParameterList>
                                                          </TableValuedFunction>
                                                        </RelOp>
                                                        <Predicate>
                                                          <ScalarOperator ScalarString="XML Reader with XPath filter.[id]=getancestor(XML Reader with XPath filter.[id],(1))">
                                                            <Compare CompareOp="EQ">
                                                              <ScalarOperator>
                                                                <Identifier>
                                                                  <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                </Identifier>
                                                              </ScalarOperator>
                                                              <ScalarOperator>
                                                                <Intrinsic FunctionName="getancestor">
                                                                  <ScalarOperator>
                                                                    <Identifier>
                                                                      <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                                    </Identifier>
                                                                  </ScalarOperator>
                                                                  <ScalarOperator>
                                                                    <Const ConstValue="(1)" />
                                                                  </ScalarOperator>
                                                                </Intrinsic>
                                                              </ScalarOperator>
                                                            </Compare>
                                                          </ScalarOperator>
                                                        </Predicate>
                                                      </Filter>
                                                    </RelOp>
                                                  </ComputeScalar>
                                                </RelOp>
                                              </Top>
                                            </RelOp>
                                          </StreamAggregate>
                                        </RelOp>
                                      </NestedLoops>
                                    </RelOp>
                                    <Predicate>
                                      <ScalarOperator ScalarString="replace(replace([Expr1035],N''['',N''''),N'']'',N'''')=N''sysjobs_view''">
                                        <Compare CompareOp="EQ">
                                          <ScalarOperator>
                                            <Intrinsic FunctionName="replace">
                                              <ScalarOperator>
                                                <Intrinsic FunctionName="replace">
                                                  <ScalarOperator>
                                                    <Identifier>
                                                      <ColumnReference Column="Expr1035" />
                                                    </Identifier>
                                                  </ScalarOperator>
                                                  <ScalarOperator>
                                                    <Const ConstValue="N''[''" />
                                                  </ScalarOperator>
                                                  <ScalarOperator>
                                                    <Const ConstValue="N''''" />
                                                  </ScalarOperator>
                                                </Intrinsic>
                                              </ScalarOperator>
                                              <ScalarOperator>
                                                <Const ConstValue="N'']''" />
                                              </ScalarOperator>
                                              <ScalarOperator>
                                                <Const ConstValue="N''''" />
                                              </ScalarOperator>
                                            </Intrinsic>
                                          </ScalarOperator>
                                          <ScalarOperator>
                                            <Const ConstValue="N''sysjobs_view''" />
                                          </ScalarOperator>
                                        </Compare>
                                      </ScalarOperator>
                                    </Predicate>
                                  </Filter>
                                </RelOp>
                                <RelOp AvgRowSize="211" EstimateCPU="1.1E-06" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Aggregate" NodeId="39" Parallel="false" PhysicalOp="Stream Aggregate" EstimatedTotalSubtreeCost="1.00037">
                                  <OutputList>
                                    <ColumnReference Column="Expr1042" />
                                  </OutputList>
                                  <RunTimeInformation>
                                    <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                  </RunTimeInformation>
                                  <StreamAggregate>
                                    <DefinedValues>
                                      <DefinedValue>
                                        <ColumnReference Column="Expr1042" />
                                        <ScalarOperator ScalarString="MIN(CASE WHEN [@x] IS NULL THEN NULL ELSE CASE WHEN datalength(XML Reader with XPath filter.[value])&gt;=(128) THEN CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[lvalue],0) ELSE CONVERT_IMPLICIT(nvarchar(200),XML Reader with XPath filter.[value],0) END END)">
                                          <Aggregate AggType="MIN" Distinct="false">
                                            <ScalarOperator>
                                              <IF>
                                                <Condition>
                                                  <ScalarOperator>
                                                    <Compare CompareOp="IS">
                                                      <ScalarOperator>
                                                        <Identifier>
                                                          <ColumnReference Column="@x" />
                                                        </Identifier>
                                                      </ScalarOperator>
                                                      <ScalarOperator>
                                                        <Const ConstValue="NULL" />
                                                      </ScalarOperator>
                                                    </Compare>
                                                  </ScalarOperator>
                                                </Condition>
                                                <Then>
                                                  <ScalarOperator>
                                                    <Const ConstValue="NULL" />
                                                  </ScalarOperator>
                                                </Then>
                                                <Else>
                                                  <ScalarOperator>
                                                    <IF>
                                                      <Condition>
                                                        <ScalarOperator>
                                                          <Compare CompareOp="GE">
                                                            <ScalarOperator>
                                                              <Intrinsic FunctionName="datalength">
                                                                <ScalarOperator>
                                                                  <Identifier>
                                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                                  </Identifier>
                                                                </ScalarOperator>
                                                              </Intrinsic>
                                                            </ScalarOperator>
                                                            <ScalarOperator>
                                                              <Const ConstValue="(128)" />
                                                            </ScalarOperator>
                                                          </Compare>
                                                        </ScalarOperator>
                                                      </Condition>
                                                      <Then>
                                                        <ScalarOperator>
                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                            <ScalarOperator>
                                                              <Identifier>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                              </Identifier>
                                                            </ScalarOperator>
                                                          </Convert>
                                                        </ScalarOperator>
                                                      </Then>
                                                      <Else>
                                                        <ScalarOperator>
                                                          <Convert DataType="nvarchar" Length="400" Style="0" Implicit="true">
                                                            <ScalarOperator>
                                                              <Identifier>
                                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                              </Identifier>
                                                            </ScalarOperator>
                                                          </Convert>
                                                        </ScalarOperator>
                                                      </Else>
                                                    </IF>
                                                  </ScalarOperator>
                                                </Else>
                                              </IF>
                                            </ScalarOperator>
                                          </Aggregate>
                                        </ScalarOperator>
                                      </DefinedValue>
                                    </DefinedValues>
                                    <RelOp AvgRowSize="8045" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Top" NodeId="40" Parallel="false" PhysicalOp="Top" EstimatedTotalSubtreeCost="1.00037">
                                      <OutputList>
                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                      </OutputList>
                                      <RunTimeInformation>
                                        <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="16" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                      </RunTimeInformation>
                                      <Top RowCount="false" IsPercent="false" WithTies="false">
                                        <TopExpression>
                                          <ScalarOperator ScalarString="(1)">
                                            <Const ConstValue="(1)" />
                                          </ScalarOperator>
                                        </TopExpression>
                                        <RelOp AvgRowSize="8949" EstimateCPU="1E-07" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Compute Scalar" NodeId="41" Parallel="false" PhysicalOp="Compute Scalar" EstimatedTotalSubtreeCost="1.00037">
                                          <OutputList>
                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                            <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                            <ColumnReference Column="Expr1041" />
                                          </OutputList>
                                          <ComputeScalar>
                                            <DefinedValues>
                                              <DefinedValue>
                                                <ColumnReference Column="Expr1041" />
                                                <ScalarOperator ScalarString="0x58">
                                                  <Const ConstValue="0x58" />
                                                </ScalarOperator>
                                              </DefinedValue>
                                            </DefinedValues>
                                            <RelOp AvgRowSize="8497" EstimateCPU="1.224E-05" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="1" LogicalOp="Filter" NodeId="42" Parallel="false" PhysicalOp="Filter" EstimatedTotalSubtreeCost="1.00037">
                                              <OutputList>
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                              </OutputList>
                                              <RunTimeInformation>
                                                <RunTimeCountersPerThread Thread="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                              </RunTimeInformation>
                                              <Filter StartupExpression="false">
                                                <RelOp AvgRowSize="8497" EstimateCPU="1.00036" EstimateIO="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row" EstimateRows="18" LogicalOp="Table-valued function" NodeId="43" Parallel="false" PhysicalOp="Table-valued function" EstimatedTotalSubtreeCost="1.00036">
                                                  <OutputList>
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                    <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                  </OutputList>
                                                  <MemoryFractions Input="1" Output="1" />
                                                  <RunTimeInformation>
                                                    <RunTimeCountersPerThread Thread="0" ActualRebinds="16" ActualRewinds="0" ActualRows="16" Batches="0" ActualEndOfScans="0" ActualExecutions="16" ActualExecutionMode="Row" ActualElapsedms="0" ActualCPUms="0" />
                                                  </RunTimeInformation>
                                                  <TableValuedFunction>
                                                    <DefinedValues>
                                                      <DefinedValue>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                      </DefinedValue>
                                                      <DefinedValue>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="value" />
                                                      </DefinedValue>
                                                      <DefinedValue>
                                                        <ColumnReference Table="[XML Reader with XPath filter]" Column="lvalue" />
                                                      </DefinedValue>
                                                    </DefinedValues>
                                                    <Object Table="[XML Reader with XPath filter]" />
                                                    <ParameterList>
                                                      <ScalarOperator ScalarString="[@x]">
                                                        <Identifier>
                                                          <ColumnReference Column="@x" />
                                                        </Identifier>
                                                      </ScalarOperator>
                                                      <ScalarOperator ScalarString="(7)">
                                                        <Const ConstValue="(7)" />
                                                      </ScalarOperator>
                                                      <ScalarOperator ScalarString="XML Reader with XPath filter.[id]">
                                                        <Identifier>
                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                        </Identifier>
                                                      </ScalarOperator>
                                                      <ScalarOperator ScalarString="getdescendantlimit(XML Reader with XPath filter.[id])">
                                                        <Intrinsic FunctionName="getdescendantlimit">
                                                          <ScalarOperator>
                                                            <Identifier>
                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                            </Identifier>
                                                          </ScalarOperator>
                                                        </Intrinsic>
                                                      </ScalarOperator>
                                                    </ParameterList>
                                                  </TableValuedFunction>
                                                </RelOp>
                                                <Predicate>
                                                  <ScalarOperator ScalarString="XML Reader with XPath filter.[id]=getancestor(XML Reader with XPath filter.[id],(1))">
                                                    <Compare CompareOp="EQ">
                                                      <ScalarOperator>
                                                        <Identifier>
                                                          <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                        </Identifier>
                                                      </ScalarOperator>
                                                      <ScalarOperator>
                                                        <Intrinsic FunctionName="getancestor">
                                                          <ScalarOperator>
                                                            <Identifier>
                                                              <ColumnReference Table="[XML Reader with XPath filter]" Column="id" />
                                                            </Identifier>
                                                          </ScalarOperator>
                                                          <ScalarOperator>
                                                            <Const ConstValue="(1)" />
                                                          </ScalarOperator>
                                                        </Intrinsic>
                                                      </ScalarOperator>
                                                    </Compare>
                                                  </ScalarOperator>
                                                </Predicate>
                                              </Filter>
                                            </RelOp>
                                          </ComputeScalar>
                                        </RelOp>
                                      </Top>
                                    </RelOp>
                                  </StreamAggregate>
                                </RelOp>
                              </NestedLoops>
                            </RelOp>
                            <Predicate>
                              <ScalarOperator ScalarString="replace(replace([Expr1042],N''['',N''''),N'']'',N'''')=N''delete_level''">
                                <Compare CompareOp="EQ">
                                  <ScalarOperator>
                                    <Intrinsic FunctionName="replace">
                                      <ScalarOperator>
                                        <Intrinsic FunctionName="replace">
                                          <ScalarOperator>
                                            <Identifier>
                                              <ColumnReference Column="Expr1042" />
                                            </Identifier>
                                          </ScalarOperator>
                                          <ScalarOperator>
                                            <Const ConstValue="N''[''" />
                                          </ScalarOperator>
                                          <ScalarOperator>
                                            <Const ConstValue="N''''" />
                                          </ScalarOperator>
                                        </Intrinsic>
                                      </ScalarOperator>
                                      <ScalarOperator>
                                        <Const ConstValue="N'']''" />
                                      </ScalarOperator>
                                      <ScalarOperator>
                                        <Const ConstValue="N''''" />
                                      </ScalarOperator>
                                    </Intrinsic>
                                  </ScalarOperator>
                                  <ScalarOperator>
                                    <Const ConstValue="N''delete_level''" />
                                  </ScalarOperator>
                                </Compare>
                              </ScalarOperator>
                            </Predicate>
                          </Filter>
                        </RelOp>
                      </Top>
                    </RelOp>
                  </NestedLoops>
                </RelOp>
              </ComputeScalar>
            </RelOp>
            <ParameterList>
              <ColumnReference Column="@x" ParameterDataType="xml" ParameterRuntimeValue="N''&lt;ShowPlanXML xmlns:xsi=&quot;http://www.w3.org/2001/XMLSchema-instance&quot; xmlns:xsd=&quot;http://www.w3.org/2001/XMLSchema&quot; xmlns=&quot;http://schemas.microsoft.com/sqlserver/2004/07/showplan&quot; Version=&quot;1.564&quot; Build=&quot;16.0.4155.4&quot;&gt;&lt;BatchSequence&gt;&lt;Batch&gt;&lt;Statements&gt;&lt;StmtSimpl''" />
            </ParameterList>
          </QueryPlan>
        </StmtSimple>
      </Statements>
    </Batch>
  </BatchSequence>
</ShowPlanXML>'
if exists(
			select *
			from z.fn_GetColumnReferencesFromQueryPlan(@x)
		)
begin
	raiserror('Test1 z.fn_GetColumnReferencesFromQueryPlan failed.', 16, 1)
end

select @x = '<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.539" Build="15.0.4312.2"><BatchSequence><Batch><Statements><StmtCond StatementText="create   trigger MySchema.TRI_MyTable_ForChronos on MySchema.MyTable&#xA;for insert&#xA;as &#xA;begin&#xA;&#x9;if @@rowcount = 0" StatementId="1" StatementCompId="66" StatementType="COND" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText="&#xA;&#x9;&#x9;return" StatementId="2" StatementCompId="67" StatementType="RETURN NONE" RetrievedFromCache="true" /></Statements></Then></StmtCond><StmtCond StatementText=";&#xA;&#x9;if maint.fn_IsSkipTriggerFlagSet(@@procid) = 1" StatementId="3" StatementCompId="69" StatementType="COND WITH QUERY" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText=" &#xA;&#x9;&#x9;return" StatementId="4" StatementCompId="70" StatementType="RETURN NONE" RetrievedFromCache="true" /></Statements></Then></StmtCond><StmtCond StatementText="&#xA;&#x9;if chronos.fn_IsEnabled() = 0" StatementId="5" StatementCompId="72" StatementType="COND WITH QUERY" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText="&#xA;&#x9;&#x9;return" StatementId="6" StatementCompId="73" StatementType="RETURN NONE" RetrievedFromCache="true" /></Statements></Then></StmtCond><StmtSimple StatementText="&#xA;&#x9;set nocount on&#xA;&#x9;" StatementId="7" StatementCompId="75" StatementType="SET ON/OFF" RetrievedFromCache="true" /><StmtCursor StatementText="declare @EventID bigint, @Value nvarchar(4000), @Field7 int, @ActionType varchar(50), @Value1 nvarchar(4000), @OperationType varchar(50)&#xA;&#x9;declare c cursor local fast_forward for&#xA;&#x9;&#x9;select i.Field1, i.Field7, rtrim(isnull(i.Field2, i.Field4))&#xA;&#x9;&#x9;from inserted i &#xA;&#x9;&#x9;where Field1 in(''DEPOSIT_LIMIT_REACHED'', ''APPLY_FREESPIN'')&#xA;&#x9;&#x9;&#x9;and nullif(rtrim(isnull(i.Field2, i.Field4)), '''')  is not null" StatementId="8" StatementCompId="76" StatementType="DECLARE CURSOR" StatementSqlHandle="0x0900618BA42F5D73D5CD01B3FA600E5287230000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="1580701575" StatementParameterizationType="0" RetrievedFromCache="true"><CursorPlan CursorName="c" CursorActualType="FastForward" CursorRequestedType="FastForward" CursorConcurrency="Read Only" ForwardOnly="true"><Operation OperationType="PopulateQuery"><QueryPlan NonParallelPlanReason="NoParallelFastForwardCursor" CachedPlanSize="72" CompileTime="4" CompileCPU="4" CompileMemory="512"><Warnings><PlanAffectingConvert ConvertIssue="Cardinality Estimate" Expression="CONVERT_IMPLICIT(varchar(max),[i].[Field4],0)" /></Warnings><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Insert" LogicalOp="Insert" EstimateRows="1" EstimateIO="0.01" EstimateCPU="1e-06" AvgRowSize="4066" EstimatedTotalSubtreeCost="0.0132856" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Column="Expr1001" /></OutputList><Update DMLRequestSort="0"><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SetPredicate><ScalarOperator ScalarString="[STREAM].[COLUMN0] = [MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1],[STREAM].[COLUMN1] = [MyDatabase].[MySchema].[MyTable].[Field7] as [i].[Field7],[STREAM].[COLUMN2] = [Expr1001],[STREAM].[ROWID] = [I4Rank1003]"><ScalarExpressionList><ScalarOperator><MultipleAssign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN0" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN1" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN2" /><ScalarOperator><Identifier><ColumnReference Column="Expr1001" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="ROWID" /><ScalarOperator><Identifier><ColumnReference Column="I4Rank1003" /></Identifier></ScalarOperator></Assign></MultipleAssign></ScalarOperator></ScalarExpressionList></ScalarOperator></SetPredicate><RelOp NodeId="1" PhysicalOp="Sequence Project" LogicalOp="Compute Scalar" EstimateRows="1" EstimateIO="0" EstimateCPU="8e-08" AvgRowSize="4070" EstimatedTotalSubtreeCost="0.00328458" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Column="Expr1001" /><ColumnReference Column="I4Rank1003" /></OutputList><SequenceProject><DefinedValues><DefinedValue><ColumnReference Column="I4Rank1003" /><ScalarOperator ScalarString="i4_row_number"><Sequence FunctionName="i4_row_number" /></ScalarOperator></DefinedValue></DefinedValues><RelOp NodeId="2" PhysicalOp="Segment" LogicalOp="Segment" EstimateRows="1" EstimateIO="0" EstimateCPU="2e-08" AvgRowSize="4070" EstimatedTotalSubtreeCost="0.0032845" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Column="Expr1001" /><ColumnReference Column="Segment1008" /></OutputList><Segment><GroupBy /><SegmentColumn><ColumnReference Column="Segment1008" /></SegmentColumn><RelOp NodeId="3" PhysicalOp="Filter" LogicalOp="Filter" EstimateRows="1" EstimateIO="0" EstimateCPU="1.28e-06" AvgRowSize="4066" EstimatedTotalSubtreeCost="0.00328448" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Column="Expr1001" /></OutputList><Filter StartupExpression="0"><RelOp NodeId="4" PhysicalOp="Compute Scalar" LogicalOp="Compute Scalar" EstimateRows="1" EstimateIO="0" EstimateCPU="1e-07" AvgRowSize="8092" EstimatedTotalSubtreeCost="0.0032832" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Column="Expr1001" /><ColumnReference Column="Expr1002" /></OutputList><ComputeScalar><DefinedValues><DefinedValue><ColumnReference Column="Expr1001" /><ScalarOperator ScalarString="rtrim(isnull([MyDatabase].[MySchema].[MyTable].[Field2] as [i].[Field2],CONVERT_IMPLICIT(varchar(max),[MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],0)))"><Intrinsic FunctionName="rtrim"><ScalarOperator><Intrinsic FunctionName="isnull"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field2" /></Identifier></ScalarOperator><ScalarOperator><Convert DataType="varchar(max)" Length="2147483647" Style="0" Implicit="1"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator></Convert></ScalarOperator></Intrinsic></ScalarOperator></Intrinsic></ScalarOperator></DefinedValue><DefinedValue><ColumnReference Column="Expr1002" /><ScalarOperator ScalarString="CASE WHEN rtrim(isnull([MyDatabase].[MySchema].[MyTable].[Field2] as [i].[Field2],CONVERT_IMPLICIT(varchar(max),[MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],0)))='''' THEN NULL ELSE rtrim(isnull([MyDatabase].[MySchema].[MyTable].[Field2] as [i].[Field2],CONVERT_IMPLICIT(varchar(max),[MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],0))) END"><IF><Condition><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Intrinsic FunctionName="rtrim"><ScalarOperator><Intrinsic FunctionName="isnull"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field2" /></Identifier></ScalarOperator><ScalarOperator><Convert DataType="varchar(max)" Length="2147483647" Style="0" Implicit="1"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator></Convert></ScalarOperator></Intrinsic></ScalarOperator></Intrinsic></ScalarOperator><ScalarOperator><Const ConstValue="''''" /></ScalarOperator></Compare></ScalarOperator></Condition><Then><ScalarOperator><Const ConstValue="NULL" /></ScalarOperator></Then><Else><ScalarOperator><Intrinsic FunctionName="rtrim"><ScalarOperator><Intrinsic FunctionName="isnull"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field2" /></Identifier></ScalarOperator><ScalarOperator><Convert DataType="varchar(max)" Length="2147483647" Style="0" Implicit="1"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator></Convert></ScalarOperator></Intrinsic></ScalarOperator></Intrinsic></ScalarOperator></Else></IF></ScalarOperator></DefinedValue></DefinedValues><RelOp NodeId="5" PhysicalOp="Inserted Scan" LogicalOp="Inserted Scan" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.0032035" EstimateCPU="7.96e-05" AvgRowSize="8092" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field2" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></OutputList><InsertedScan><Object Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Index="[PK_MySchema_MyTable]" Alias="[i]" IndexKind="Clustered" Storage="RowStore" /></InsertedScan></RelOp></ComputeScalar></RelOp><Predicate><ScalarOperator ScalarString="[Expr1002] IS NOT NULL AND ([MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1]=''APPLY_FREESPIN'' OR [MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1]=''DEPOSIT_LIMIT_REACHED'')"><Logical Operation="AND"><ScalarOperator><Compare CompareOp="IS NOT"><ScalarOperator><Identifier><ColumnReference Column="Expr1002" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="NULL" /></ScalarOperator></Compare></ScalarOperator><ScalarOperator><Logical Operation="OR"><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''APPLY_FREESPIN''" /></ScalarOperator></Compare></ScalarOperator><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''DEPOSIT_LIMIT_REACHED''" /></ScalarOperator></Compare></ScalarOperator></Logical></ScalarOperator></Logical></ScalarOperator></Predicate></Filter></RelOp></Segment></RelOp></SequenceProject></RelOp></Update></RelOp></QueryPlan></Operation><Operation OperationType="FetchQuery"><QueryPlan NonParallelPlanReason="CouldNotGenerateValidParallelPlan" CachedPlanSize="72" CompileTime="0" CompileCPU="0" CompileMemory="376"><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Seek" LogicalOp="Clustered Index Seek" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.003125" EstimateCPU="0.0001581" AvgRowSize="4070" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Table="[CWT]" Column="COLUMN0" /><ColumnReference Table="[CWT]" Column="COLUMN1" /><ColumnReference Table="[CWT]" Column="COLUMN2" /><ColumnReference Table="[CWT]" Column="ROWID" /></OutputList><IndexScan Ordered="1" ScanDirection="FORWARD" ForcedIndex="0" ForceSeek="0" ForceScan="0" NoExpandHint="0" Storage="RowStore"><DefinedValues><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN0" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN1" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN2" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="ROWID" /></DefinedValue></DefinedValues><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SeekPredicates><SeekPredicateNew><SeekKeys><Prefix ScanType="EQ"><RangeColumns><ColumnReference Table="[CWT]" Column="ROWID" /></RangeColumns><RangeExpressions><ScalarOperator ScalarString="FETCH_RANGE((0))"><Intrinsic FunctionName="FETCH_RANGE"><ScalarOperator><Const ConstValue="(0)" /></ScalarOperator></Intrinsic></ScalarOperator></RangeExpressions></Prefix></SeekKeys></SeekPredicateNew></SeekPredicates></IndexScan></RelOp></QueryPlan></Operation></CursorPlan></StmtCursor><StmtCursor StatementText="&#xA;&#x9;open c&#xA;&#x9;" StatementId="9" StatementCompId="77" StatementType="OPEN CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="fetch next from c into @ActionType, @Field7, @Value&#xA;&#x9;" StatementId="10" StatementCompId="78" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCond StatementText="while @@fetch_status = 0" StatementId="11" StatementCompId="79" StatementType="COND" RetrievedFromCache="true"><Condition /><Then><Statements><StmtCond StatementText="&#xA;&#x9;begin&#xA;&#x9;&#x9;if @ActionType = ''DEPOSIT_LIMIT_REACHED''" StatementId="12" StatementCompId="80" StatementType="COND" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText=" &#xA;&#x9;&#x9;&#x9;exec chronos.usp_InsertEvent @Name = ''LimitReached'', @Field7 = @Field7, @EventID = @EventID output" StatementId="13" StatementCompId="81" StatementType="EXECUTE PROC" RetrievedFromCache="true" /></Statements></Then><Else><Statements><StmtSimple StatementText="&#xA;&#x9;&#x9;else&#xA;&#x9;&#x9;&#x9;exec chronos.usp_InsertEvent @Name = ''FreeSpinAward'', @Field7 = @Field7, @EventID = @EventID output" StatementId="14" StatementCompId="84" StatementType="EXECUTE PROC" RetrievedFromCache="true" /></Statements></Else></StmtCond><StmtSimple StatementText="&#xA;&#x9;&#x9;exec chronos.usp_InsertEventData @EventID = @EventID, @Name = ''Information'', @Value1 = @Value, @Value2 = null, @Info = null" StatementId="15" StatementCompId="86" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtCursor StatementText="&#xA;&#xA;        fetch next from c into @ActionType, @Field7, @Value&#xA;&#x9;" StatementId="16" StatementCompId="87" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor></Statements></Then></StmtCond><StmtCursor StatementText="end&#xA;&#x9;close c&#xA;&#x9;" StatementId="17" StatementCompId="90" StatementType="CLOSE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="deallocate c&#xA;&#xA;&#x9;" StatementId="18" StatementCompId="91" StatementType="DEALLOCATE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="declare c cursor local fast_forward for&#xA;&#x9;&#x9;select i.Field1, i.Field7, Field5, Field4&#xA;&#x9;&#x9;from inserted i &#xA;&#x9;&#x9;where (Field1 in(''KYC_STATUS_CHANGE'') or (Field1 in (''DATA_EDIT'') and Field3 like ''%KYC Status%''))&#xA;&#x9;&#x9;&#x9;and isnull(Field5, '''') &lt;&gt; isnull(Field4, '''')" StatementId="19" StatementCompId="92" StatementType="DECLARE CURSOR" StatementSqlHandle="0x0900F66879B242CBD4AE1104BC8202491CF10000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="1580701575" StatementParameterizationType="0" RetrievedFromCache="true"><CursorPlan CursorName="c" CursorActualType="FastForward" CursorRequestedType="FastForward" CursorConcurrency="Read Only" ForwardOnly="true"><Operation OperationType="PopulateQuery"><QueryPlan NonParallelPlanReason="NoParallelFastForwardCursor" CachedPlanSize="72" CompileTime="3" CompileCPU="3" CompileMemory="496"><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Insert" LogicalOp="Insert" EstimateRows="1" EstimateIO="0.01" EstimateCPU="1e-06" AvgRowSize="8092" EstimatedTotalSubtreeCost="0.0132867" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></OutputList><Update DMLRequestSort="0"><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SetPredicate><ScalarOperator ScalarString="[STREAM].[COLUMN0] = [MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1],[STREAM].[COLUMN1] = [MyDatabase].[MySchema].[MyTable].[Field7] as [i].[Field7],[STREAM].[COLUMN2] = [MyDatabase].[MySchema].[MyTable].[Field5] as [i].[Field5],[STREAM].[COLUMN3] = [MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],[STREAM].[ROWID] = [I4Rank1003]"><ScalarExpressionList><ScalarOperator><MultipleAssign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN0" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN1" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN2" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN3" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="ROWID" /><ScalarOperator><Identifier><ColumnReference Column="I4Rank1003" /></Identifier></ScalarOperator></Assign></MultipleAssign></ScalarOperator></ScalarExpressionList></ScalarOperator></SetPredicate><RelOp NodeId="1" PhysicalOp="Sequence Project" LogicalOp="Compute Scalar" EstimateRows="1" EstimateIO="0" EstimateCPU="8e-08" AvgRowSize="8096" EstimatedTotalSubtreeCost="0.00328568" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Column="I4Rank1003" /></OutputList><SequenceProject><DefinedValues><DefinedValue><ColumnReference Column="I4Rank1003" /><ScalarOperator ScalarString="i4_row_number"><Sequence FunctionName="i4_row_number" /></ScalarOperator></DefinedValue></DefinedValues><RelOp NodeId="2" PhysicalOp="Segment" LogicalOp="Segment" EstimateRows="1" EstimateIO="0" EstimateCPU="2e-08" AvgRowSize="8096" EstimatedTotalSubtreeCost="0.0032856" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Column="Segment1008" /></OutputList><Segment><GroupBy /><SegmentColumn><ColumnReference Column="Segment1008" /></SegmentColumn><RelOp NodeId="3" PhysicalOp="Filter" LogicalOp="Filter" EstimateRows="1" EstimateIO="0" EstimateCPU="2.48e-06" AvgRowSize="8092" EstimatedTotalSubtreeCost="0.00328558" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></OutputList><Filter StartupExpression="0"><RelOp NodeId="4" PhysicalOp="Inserted Scan" LogicalOp="Inserted Scan" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.0032035" EstimateCPU="7.96e-05" AvgRowSize="12118" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field3" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></OutputList><InsertedScan><Object Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Index="[PK_MySchema_MyTable]" Alias="[i]" IndexKind="Clustered" Storage="RowStore" /></InsertedScan></RelOp><Predicate><ScalarOperator ScalarString="([MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1]=''KYC_STATUS_CHANGE'' OR [MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1]=''DATA_EDIT'' AND [MyDatabase].[MySchema].[MyTable].[Field3] as [i].[Field3] like ''%KYC Status%'') AND isnull([MyDatabase].[MySchema].[MyTable].[Field5] as [i].[Field5],CONVERT_IMPLICIT(nvarchar(max),'''',0))&lt;&gt;isnull([MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],CONVERT_IMPLICIT(nvarchar(max),'''',0))"><Logical Operation="AND"><ScalarOperator><Logical Operation="OR"><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''KYC_STATUS_CHANGE''" /></ScalarOperator></Compare></ScalarOperator><ScalarOperator><Logical Operation="AND"><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''DATA_EDIT''" /></ScalarOperator></Compare></ScalarOperator><ScalarOperator><Intrinsic FunctionName="like"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field3" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''%KYC Status%''" /></ScalarOperator></Intrinsic></ScalarOperator></Logical></ScalarOperator></Logical></ScalarOperator><ScalarOperator><Compare CompareOp="NE"><ScalarOperator><Intrinsic FunctionName="isnull"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field5" /></Identifier></ScalarOperator><ScalarOperator><Identifier><ColumnReference Column="ConstExpr1001"><ScalarOperator><Convert DataType="nvarchar(max)" Length="2147483647" Style="0" Implicit="1"><ScalarOperator><Const ConstValue="''''" /></ScalarOperator></Convert></ScalarOperator></ColumnReference></Identifier></ScalarOperator></Intrinsic></ScalarOperator><ScalarOperator><Intrinsic FunctionName="isnull"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator><ScalarOperator><Identifier><ColumnReference Column="ConstExpr1002"><ScalarOperator><Convert DataType="nvarchar(max)" Length="2147483647" Style="0" Implicit="1"><ScalarOperator><Const ConstValue="''''" /></ScalarOperator></Convert></ScalarOperator></ColumnReference></Identifier></ScalarOperator></Intrinsic></ScalarOperator></Compare></ScalarOperator></Logical></ScalarOperator></Predicate></Filter></RelOp></Segment></RelOp></SequenceProject></RelOp></Update></RelOp></QueryPlan></Operation><Operation OperationType="FetchQuery"><QueryPlan NonParallelPlanReason="CouldNotGenerateValidParallelPlan" CachedPlanSize="72" CompileTime="0" CompileCPU="0" CompileMemory="384"><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Seek" LogicalOp="Clustered Index Seek" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.003125" EstimateCPU="0.0001581" AvgRowSize="8096" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Table="[CWT]" Column="COLUMN0" /><ColumnReference Table="[CWT]" Column="COLUMN1" /><ColumnReference Table="[CWT]" Column="COLUMN2" /><ColumnReference Table="[CWT]" Column="COLUMN3" /><ColumnReference Table="[CWT]" Column="ROWID" /></OutputList><IndexScan Ordered="1" ScanDirection="FORWARD" ForcedIndex="0" ForceSeek="0" ForceScan="0" NoExpandHint="0" Storage="RowStore"><DefinedValues><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN0" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN1" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN2" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN3" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="ROWID" /></DefinedValue></DefinedValues><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SeekPredicates><SeekPredicateNew><SeekKeys><Prefix ScanType="EQ"><RangeColumns><ColumnReference Table="[CWT]" Column="ROWID" /></RangeColumns><RangeExpressions><ScalarOperator ScalarString="FETCH_RANGE((0))"><Intrinsic FunctionName="FETCH_RANGE"><ScalarOperator><Const ConstValue="(0)" /></ScalarOperator></Intrinsic></ScalarOperator></RangeExpressions></Prefix></SeekKeys></SeekPredicateNew></SeekPredicates></IndexScan></RelOp></QueryPlan></Operation></CursorPlan></StmtCursor><StmtCursor StatementText="&#xA;&#x9;open c&#xA;&#x9;" StatementId="20" StatementCompId="93" StatementType="OPEN CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="fetch next from c into @ActionType, @Field7, @Value, @Value1&#xA;&#x9;" StatementId="21" StatementCompId="94" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCond StatementText="while @@fetch_status = 0" StatementId="22" StatementCompId="95" StatementType="COND" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText="&#xA;&#x9;begin&#xA;&#x9;&#x9;exec chronos.usp_InsertEvent @Name = ''KYCStatusChange'', @Field7 = @Field7, @EventID = @EventID output" StatementId="23" StatementCompId="96" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtSimple StatementText="&#xA;&#x9;&#x9;exec chronos.usp_InsertEventData @EventID = @EventID, @Name = ''preStatus'', @Value1 = @Value, @Value2 = null, @Info = null" StatementId="24" StatementCompId="97" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtSimple StatementText="&#xA;&#x9;&#x9;exec chronos.usp_InsertEventData @EventID = @EventID, @Name = ''status'', @Value1 = @Value1, @Value2 = null, @Info = null" StatementId="25" StatementCompId="98" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtCursor StatementText="&#xA;&#xA;        fetch next from c into @ActionType, @Field7, @Value, @Value1&#xA;&#x9;" StatementId="26" StatementCompId="99" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor></Statements></Then></StmtCond><StmtCursor StatementText="end&#xA;&#x9;close c&#xA;&#x9;" StatementId="27" StatementCompId="102" StatementType="CLOSE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="deallocate c&#xA;&#xA;    " StatementId="28" StatementCompId="103" StatementType="DEALLOCATE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="declare c cursor local fast_forward for&#xA;        select i.Field1, i.Field6, i.Field7, Field4&#xA;        from inserted i&#xA;        where (Field1 = ''CashbackRedemption'' and i.Field6 = ''REDEEMED'')" StatementId="29" StatementCompId="104" StatementType="DECLARE CURSOR" StatementSqlHandle="0x09003056FE3B5CBB98EB81E675B0733059CA0000000000000000000000000000000000000000000000000000" DatabaseContextSettingsId="1" ParentObjectId="1580701575" StatementParameterizationType="0" RetrievedFromCache="true"><CursorPlan CursorName="c" CursorActualType="FastForward" CursorRequestedType="FastForward" CursorConcurrency="Read Only" ForwardOnly="true"><Operation OperationType="PopulateQuery"><QueryPlan NonParallelPlanReason="NoParallelFastForwardCursor" CachedPlanSize="64" CompileTime="3" CompileCPU="2" CompileMemory="440"><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Insert" LogicalOp="Insert" EstimateRows="1" EstimateIO="0.01" EstimateCPU="1e-06" AvgRowSize="4093" EstimatedTotalSubtreeCost="0.0132851" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /></OutputList><Update DMLRequestSort="0"><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SetPredicate><ScalarOperator ScalarString="[STREAM].[COLUMN0] = [MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1],[STREAM].[COLUMN1] = [MyDatabase].[MySchema].[MyTable].[Field6] as [i].[Field6],[STREAM].[COLUMN2] = [MyDatabase].[MySchema].[MyTable].[Field7] as [i].[Field7],[STREAM].[COLUMN3] = [MyDatabase].[MySchema].[MyTable].[Field4] as [i].[Field4],[STREAM].[ROWID] = [I4Rank1001]"><ScalarExpressionList><ScalarOperator><MultipleAssign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN0" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN1" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN2" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="COLUMN3" /><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /></Identifier></ScalarOperator></Assign><Assign><ColumnReference Table="[STREAM]" Column="ROWID" /><ScalarOperator><Identifier><ColumnReference Column="I4Rank1001" /></Identifier></ScalarOperator></Assign></MultipleAssign></ScalarOperator></ScalarExpressionList></ScalarOperator></SetPredicate><RelOp NodeId="1" PhysicalOp="Sequence Project" LogicalOp="Compute Scalar" EstimateRows="1" EstimateIO="0" EstimateCPU="8e-08" AvgRowSize="4097" EstimatedTotalSubtreeCost="0.00328408" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /><ColumnReference Column="I4Rank1001" /></OutputList><SequenceProject><DefinedValues><DefinedValue><ColumnReference Column="I4Rank1001" /><ScalarOperator ScalarString="i4_row_number"><Sequence FunctionName="i4_row_number" /></ScalarOperator></DefinedValue></DefinedValues><RelOp NodeId="2" PhysicalOp="Segment" LogicalOp="Segment" EstimateRows="1" EstimateIO="0" EstimateCPU="2e-08" AvgRowSize="4097" EstimatedTotalSubtreeCost="0.003284" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /><ColumnReference Column="Segment1006" /></OutputList><Segment><GroupBy /><SegmentColumn><ColumnReference Column="Segment1006" /></SegmentColumn><RelOp NodeId="3" PhysicalOp="Filter" LogicalOp="Filter" EstimateRows="1" EstimateIO="0" EstimateCPU="8.8e-07" AvgRowSize="4093" EstimatedTotalSubtreeCost="0.00328398" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /></OutputList><Filter StartupExpression="0"><RelOp NodeId="4" PhysicalOp="Inserted Scan" LogicalOp="Inserted Scan" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.0032035" EstimateCPU="7.96e-05" AvgRowSize="4093" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field7" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field4" /><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /></OutputList><InsertedScan><Object Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Index="[PK_MySchema_MyTable]" Alias="[i]" IndexKind="Clustered" Storage="RowStore" /></InsertedScan></RelOp><Predicate><ScalarOperator ScalarString="[MyDatabase].[MySchema].[MyTable].[Field1] as [i].[Field1]=''CashbackRedemption'' AND [MyDatabase].[MySchema].[MyTable].[Field6] as [i].[Field6]=''REDEEMED''"><Logical Operation="AND"><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field1" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''CashbackRedemption''" /></ScalarOperator></Compare></ScalarOperator><ScalarOperator><Compare CompareOp="EQ"><ScalarOperator><Identifier><ColumnReference Database="[MyDatabase]" Schema="[MySchema]" Table="[MyTable]" Alias="[i]" Column="Field6" /></Identifier></ScalarOperator><ScalarOperator><Const ConstValue="''REDEEMED''" /></ScalarOperator></Compare></ScalarOperator></Logical></ScalarOperator></Predicate></Filter></RelOp></Segment></RelOp></SequenceProject></RelOp></Update></RelOp></QueryPlan></Operation><Operation OperationType="FetchQuery"><QueryPlan NonParallelPlanReason="CouldNotGenerateValidParallelPlan" CachedPlanSize="64" CompileTime="0" CompileCPU="0" CompileMemory="376"><MemoryGrantInfo SerialRequiredMemory="0" SerialDesiredMemory="0" GrantedMemory="0" MaxUsedMemory="0" /><OptimizerHardwareDependentProperties EstimatedAvailableMemoryGrant="730506" EstimatedPagesCached="2191520" EstimatedAvailableDegreeOfParallelism="8" MaxCompileMemory="165284592" /><TraceFlags IsCompileTime="1"><TraceFlag Value="3226" Scope="Global" /></TraceFlags><RelOp NodeId="0" PhysicalOp="Clustered Index Seek" LogicalOp="Clustered Index Seek" EstimateRows="1" EstimatedRowsRead="1" EstimateIO="0.003125" EstimateCPU="0.0001581" AvgRowSize="4097" EstimatedTotalSubtreeCost="0.0032831" TableCardinality="0" Parallel="0" EstimateRebinds="0" EstimateRewinds="0" EstimatedExecutionMode="Row"><OutputList><ColumnReference Table="[CWT]" Column="COLUMN0" /><ColumnReference Table="[CWT]" Column="COLUMN1" /><ColumnReference Table="[CWT]" Column="COLUMN2" /><ColumnReference Table="[CWT]" Column="COLUMN3" /><ColumnReference Table="[CWT]" Column="ROWID" /></OutputList><IndexScan Ordered="1" ScanDirection="FORWARD" ForcedIndex="0" ForceSeek="0" ForceScan="0" NoExpandHint="0" Storage="RowStore"><DefinedValues><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN0" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN1" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN2" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="COLUMN3" /></DefinedValue><DefinedValue><ColumnReference Table="[CWT]" Column="ROWID" /></DefinedValue></DefinedValues><Object Database="[tempdb]" Index="[CWT_PrimaryKey]" Storage="RowStore" /><SeekPredicates><SeekPredicateNew><SeekKeys><Prefix ScanType="EQ"><RangeColumns><ColumnReference Table="[CWT]" Column="ROWID" /></RangeColumns><RangeExpressions><ScalarOperator ScalarString="FETCH_RANGE((0))"><Intrinsic FunctionName="FETCH_RANGE"><ScalarOperator><Const ConstValue="(0)" /></ScalarOperator></Intrinsic></ScalarOperator></RangeExpressions></Prefix></SeekKeys></SeekPredicateNew></SeekPredicates></IndexScan></RelOp></QueryPlan></Operation></CursorPlan></StmtCursor><StmtCursor StatementText="&#xA;    open c&#xA;    " StatementId="30" StatementCompId="105" StatementType="OPEN CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="fetch next from c into @ActionType, @OperationType, @Field7, @Value&#xA;    " StatementId="31" StatementCompId="106" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCond StatementText="while @@fetch_status = 0" StatementId="32" StatementCompId="107" StatementType="COND" RetrievedFromCache="true"><Condition /><Then><Statements><StmtSimple StatementText="&#xA;        begin&#xA;            exec chronos.usp_InsertEvent @Name = ''CashbackRedeemed'', @Field7 = @Field7, @EventID = @EventID output" StatementId="33" StatementCompId="108" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtSimple StatementText="&#xA;            exec chronos.usp_InsertEventData @EventID = @EventID, @Name = ''cashbackBalance'', @Value1 = @Value, @Value2 = null, @Info = null" StatementId="34" StatementCompId="109" StatementType="EXECUTE PROC" RetrievedFromCache="true" /><StmtCursor StatementText="&#xA;&#xA;            fetch next from c into @ActionType, @OperationType, @Field7, @Value&#xA;        " StatementId="35" StatementCompId="110" StatementType="FETCH CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor></Statements></Then></StmtCond><StmtCursor StatementText="end&#xA;    close c&#xA;    " StatementId="36" StatementCompId="113" StatementType="CLOSE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor><StmtCursor StatementText="deallocate c&#xA;" StatementId="37" StatementCompId="114" StatementType="DEALLOCATE CURSOR" RetrievedFromCache="true"><CursorPlan CursorName="c" /></StmtCursor></Statements></Batch></BatchSequence></ShowPlanXML>'
if (
	select count(*)
	from z.fn_GetColumnReferencesFromQueryPlan(@x)
	where DatabaseName = 'MyDatabase'
		and SchemaName = 'MySchema'
		and ObjectName = 'MyTable'
		and ColumnName in ('Field1', 'Field2', 'Field3', 'Field4', 'Field5', 'Field6', 'Field7')
	) <> 7
begin
	raiserror('Test2 z.fn_GetColumnReferencesFromQueryPlan failed.', 16, 1)
end