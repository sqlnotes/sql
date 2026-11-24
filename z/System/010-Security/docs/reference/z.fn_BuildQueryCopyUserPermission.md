# z.fn_BuildQueryCopyUserPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyUserPermission.sql)

## Purpose and behavior

Produces scripts to copy a user's explicit permissions and role memberships in the current database. It does not create the destination user or execute the returned statements.

Supply the existing user in `@SourceUser`. Set `@TargetUser` to apply the copied permissions to another user, or leave it NULL to keep the source name. A NULL source returns no rows.

## Parameters and defaults

```text
@SourceUser nvarchar(128) = null, 
@TargetUser nvarchar(128) = null
```

## Results, permissions, and limits

Returns `Ordinal int`, `Type varchar(100)` and `SQL nvarchar(max)`. `Type` describes the generated statement and `SQL` contains the text to review or apply. Read rows in `Ordinal` order. Catalog visibility and the permission classes covered by the source limit what can be scripted.

## Dependencies

Native dependencies: `sys.assemblies`, `sys.asymmetric_keys`, `sys.certificates`, `sys.database_permissions`, `sys.database_principals`, `sys.database_role_members`, `sys.database_scoped_credentials`, `sys.external_languages`, `sys.fulltext_catalogs`, `sys.fulltext_stoplists`, `sys.registered_search_property_lists`, `sys.remote_service_bindings`, `sys.routes`, `sys.service_contracts`, `sys.service_message_types`, `sys.services`, `sys.symmetric_keys`, `sys.types`, `sys.xml_schema_collections`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns, available from the minimum supported SQL Server version, 2019 (15.x).
