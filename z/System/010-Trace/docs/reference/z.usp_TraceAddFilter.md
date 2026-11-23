# z.usp_TraceAddFilter

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddFilter.sql)

Limits which activity a trace captures. For example, filter `SPID <> @@spid` to exclude the connection running the trace, or filter a text column to focus on particular statements. Add filters before the trace's first Start attempt.

Select a column by `@ColumnName` or `@ColumnID`, choose `@ComparisonOperator`, and supply a value of the appropriate type in `@Value`. NULL adds no filter. Supported comparisons are `=`, `!=`, `<>`, `>`, `<`, `>=`, `<=`, `like` and `not like`; LIKE comparisons require character data. Invalid or truncated typed values are rejected.

`@LogicOperator` joins predicates on the same column with `and` or `or`. Different columns are combined with `AND` by SQL Trace. Filter order is therefore not a single boolean expression across columns; SQL Trace applies each column's predicates in their configured order.

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@ColumnName nvarchar(128) = null,
@ColumnID int = null,
@LogicOperator varchar(3) = 'and',
@ComparisonOperator varchar(8) = '=',
@Value sql_variant
```

TraceID is the native SQL Server trace ID. Configuration APIs require a stopped trace created by the current session/login; name and ID selectors, when both supplied, must match the same registration. Native SQL Trace permissions are not granted by these procedures. See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md).

Events, columns and filters must be configured before native event binding begins on the first Start attempt. After that, Close/Create is required to change them; Stop/Start resumes the same fixed configuration.
