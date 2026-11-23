# z.fn_AsyncChannelTypeDef

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1010%20Functions/z.fn_AsyncChannelTypeDef.sql)

## Purpose and parameters

Turns catalog type information into readable SQL type text, such as `nvarchar(100)` or `decimal(18,2)`. [z.v_AsyncChannel](z.v_AsyncChannel.md) uses this helper to compare the interface, serializer and processing signatures. It is a metadata formatter, not a channel deployment operation.

```text
@UserTypeID int
@MaxLength smallint
@Precision tinyint
@Scale tinyint
```

All parameters are required; no defaults are declared. `@UserTypeID` identifies the type in `sys.types`. `@MaxLength` is its catalog length in bytes, including `-1` for MAX types. `@Precision` and `@Scale` supply the type's numeric precision and scale or fractional-time scale where applicable.

## Result

Returns `nvarchar(200)`. Looks up the name in `sys.types` by user_type_id, then appends:

- Length or `max` for char/varchar/binary/varbinary.
- Half the byte length, or `max`, for nchar/nvarchar.
- Precision and scale for decimal/numeric.
- Scale for datetime2/time/datetimeoffset.

Other types return the catalog name alone. Unknown type IDs return NULL. NULL numeric metadata can propagate NULL through decorated declarations.

## Dependencies and limits

Reads `sys.types` with no writes. The returned name is not schema-qualified or delimited and is not a complete general-purpose CREATE TYPE declaration. Matching formatted signatures is one structural check, not proof that a generated channel is valid or that all custom types round-trip correctly.
