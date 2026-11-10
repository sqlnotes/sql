# z.usp_TraceAddFilter

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddFilter.sql)

Append a typed predicate with a FilterOrdinal. NULL Value adds nothing. Validate catalog column, operator and typed value; reject truncation. Accept and/or and =, !=, <>, >, <, >=, <=, like, not like; normalize != to <>. LIKE requires character data. TraceStart applies filters natively, grouped by column in ordinal order. Native filters combine different columns with AND; native text comparison semantics apply.

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
