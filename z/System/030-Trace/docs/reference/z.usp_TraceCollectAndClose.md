# z.usp_TraceCollectAndClose

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceCollectAndClose.sql)

## Purpose and behavior

Select Running traces owned by current SPID. Create missing receiving tables and add missing trace-catalog columns; force naming convention. Build SQL that reads sp_trace_getdata, decodes values, assigns TraceSequence and inserts event rows. Invoke configured callbacks after each insert. Execute short transactions for TransactionDurationInSec until maximum duration or selected trace state/table changes, then close selected traces. Catch rolls back any open transaction and rethrows; it does not guarantee native trace cleanup after a failure.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,@TraceID int = null,@MaxDurationInSec int = 2147483647,@TransactionDurationInSec int = 3
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER TRACE, receiving-table DDL/DML, and callback privileges. Default MaxDurationInSec is about 68 years; bound it for development. Duration check occurs after a transaction chunk, so runtime can exceed the requested maximum. ReceivingTable/ProcedureName metadata is concatenated as trusted SQL.

## Dependencies

Direct SQL object dependencies: `z.SeqGeneralID`, `z.TraceTrigger`, `z.usp_ForceNamingConvention`, `z.usp_TraceClose`, `z.v_Trace`, `z.v_TraceColumn`, `z.v_TraceEvent`.

Native dependencies: `sys.columns`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
