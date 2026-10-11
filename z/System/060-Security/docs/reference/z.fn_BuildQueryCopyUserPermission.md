# z.fn_BuildQueryCopyUserPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyUserPermission.sql)

## Purpose and behavior

Generate visible explicit database permissions for the named source, grouping by state/securable and substituting target in permission clauses. Handles many securable classes, then appends database-role membership statements. Unsupported or null generated SQL is omitted.

## Parameters and defaults

```text
@SourceUser nvarchar(128) = null, @TargetUser nvarchar(128) = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Ordinal int identity, Type varchar(100), SQL nvarchar(max); order explicitly by Ordinal. Read-only. Membership statements still name source. Object/column revoke syntax and XML collection schema handling need correction before generated scripts are used.

## Dependencies

Native dependencies: `sys.assemblies`, `sys.asymmetric_keys`, `sys.certificates`, `sys.database_permissions`, `sys.database_principals`, `sys.database_role_members`, `sys.database_scoped_credentials`, `sys.external_languages`, `sys.fulltext_catalogs`, `sys.fulltext_stoplists`, `sys.registered_search_property_lists`, `sys.remote_service_bindings`, `sys.routes`, `sys.service_contracts`, `sys.service_message_types`, `sys.services`, `sys.symmetric_keys`, `sys.types`, `sys.xml_schema_collections`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns. This catalog is a SQL Server 2019-era feature, so the current function is not a reliable SQL Server 2017 interface despite the project baseline. Check the target version before installing or using it.
