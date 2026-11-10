# z.fn_AsyncChannelTypeDef

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1010%20Functions/z.fn_AsyncChannelTypeDef.sql)

## Purpose and parameters

Formats catalog type metadata for the signature comparisons in [z.v_AsyncChannel](z.v_AsyncChannel.md).

```text
@UserTypeID int
@MaxLength smallint
@Precision tinyint
@Scale tinyint
```

All parameters are required; no defaults are declared. MaxLength follows catalog byte-length semantics, including `-1` for MAX types.

## Result

Returns `nvarchar(200)`. Looks up the name in `sys.types` by user_type_id, then appends:

- Length or `max` for char/varchar/binary/varbinary.
- Half the byte length, or `max`, for nchar/nvarchar.
- Precision and scale for decimal/numeric.
- Scale for datetime2/time/datetimeoffset.

Other types return the catalog name alone. Unknown type IDs return NULL. NULL numeric metadata can propagate NULL through decorated declarations.

## Dependencies and limits

Reads `sys.types` with no writes. The returned name is not schema-qualified or delimited and is not a complete general-purpose CREATE TYPE declaration. Matching formatted signatures is one structural check, not proof that a generated channel is valid or that all custom types round-trip correctly.
