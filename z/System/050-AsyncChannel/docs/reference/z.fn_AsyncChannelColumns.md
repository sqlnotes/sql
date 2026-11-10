# z.fn_AsyncChannelColumns

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1010%20Functions/z.fn_AsyncChannelColumns.sql)

## Purpose and parameters

An inline table-valued function that reads interface column metadata and returns SQL fragments for codec and interface generation.

```text
@ObjectID int
```

No default is declared. A NULL, unknown or invisible object ID returns no column rows.

## Returned columns

| Column | Meaning |
| --- | --- |
| column_id | Catalog column ordinal |
| ColumnName | Catalog column name |
| Category | `native`, `variant`, `clr` or `xml` |
| TypeName | Type name with supported length, precision or scale decoration |
| ParamDecl | Generated parameter name and type |
| QuotedName | Column name passed through QUOTENAME |
| CrossApplyArg | Delimited interface-column reference using alias `i` |
| SerializeExpr | Projection fragment for JSON serialization |
| OpenJsonWith | OPENJSON WITH declaration fragment |
| OuterSelect | Deserializer projection fragment |

Generation distinguishes SQL variant, XML and the built-in geometry/geography/hierarchyid types. XML is serialized as text, spatial/hierarchy values as binary, and variant values include base-type and value fields.

## Dependencies and limits

Reads `sys.columns` and `sys.types`; it has no writes or dynamic execution. Metadata visibility affects results. Consumers must explicitly order by column_id when combining expressions.

The function produces SQL text, not a validation result. Some fragments interpolate identifiers and JSON paths without complete escaping. Alias types and unusual names are not guaranteed; variant decoding uses fixed target types such as decimal(38,10), so exact original variant precision is not preserved. Review generated scripts before deployment.
