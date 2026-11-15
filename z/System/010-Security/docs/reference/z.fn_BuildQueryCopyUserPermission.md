# z.fn_BuildQueryCopyUserPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyUserPermission.sql)

## Purpose and behavior

Generates explicit database permissions and database-role membership statements (`alter role ... add member ...`) for `@SourceUser`, substituting `@TargetUser` when supplied.

## Parameters and defaults

```text
@SourceUser nvarchar(128) = null, 
@TargetUser nvarchar(128) = null
```

## Results, permissions, and limits

Returns `Ordinal int identity`, `Type varchar(100)`, `SQL nvarchar(max)`; order explicitly by `Ordinal`. Read-only. A `null` `@SourceUser` returns no rows.

## Dependencies

Native dependencies: `sys.assemblies`, `sys.asymmetric_keys`, `sys.certificates`, `sys.database_permissions`, `sys.database_principals`, `sys.database_role_members`, `sys.database_scoped_credentials`, `sys.external_languages`, `sys.fulltext_catalogs`, `sys.fulltext_stoplists`, `sys.registered_search_property_lists`, `sys.remote_service_bindings`, `sys.routes`, `sys.service_contracts`, `sys.service_message_types`, `sys.services`, `sys.symmetric_keys`, `sys.types`, `sys.xml_schema_collections`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns, available from the minimum supported SQL Server version, 2019 (15.x).
