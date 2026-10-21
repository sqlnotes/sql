# z.usp_TraceAddFilter

[Trace](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_TraceAddFilter.sql)

## Purpose and behavior

Append a typed predicate with a per-definition FilterOrdinal. NULL Value adds nothing. ColumnName/ColumnID must identify the same filterable catalog column. Accept and/or and =, !=, <>, >, <, >=, <=, like, not like; normalize != to <>. LIKE requires character data. Convert the value to its catalog type before storing sql_variant; reject character truncation and Unicode values over 4000 characters.

Evaluate filters locally: AND across column groups; ordered left-fold AND/OR within each column group, ignoring its first operator. SQL NULL/missing fields yield UNKNOWN and do not match. Separate logical definitions retain independent predicates. Filter inputs join the physical capture union without forcing them into the output selection. Only a universally safe common SPID predicate can be pushed down.

## Parameters and defaults

```text
@TraceName nvarchar(128) = null,
@TraceID int = null,
@ColumnName nvarchar(128) = null,
@ColumnID int = null,
@LogicOperator varchar(3) = 'and',
@ComparisonOperator varchar(8) = '=',
@Value sql_variant
```

TraceName/TraceID select one current-session logical definition. When both are supplied they must identify the same owned definition. TraceID is not a native SQL Trace ID.

## Ownership, results and limits

Requires the registered UUID/session/login owner and a Building run; Collecting configuration is frozen. Logical Start does not end Building, so these APIs can still run after enabling a definition. No defined result set. Requires configuration metadata access and catalog visibility; collection separately requires native trace and destination/callback privileges. Use framework procedures instead of direct table DML.

## Dependencies

z.TraceFilter and z.v_TraceColumn; z.v_TraceOwned and z.usp_TraceAssertOwner. See [architecture](../architecture.md) for ownership, execution and transport limits.

Local character comparisons use the database collation. Values that exceed the selected text-column length are rejected before filter metadata is written.
