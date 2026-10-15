# z.fn_BuildQueryCopyLoginPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyLoginPermission.sql)

## Purpose and behavior

Generate visible explicit server permissions for the named source and substitute the target in permission clauses; return membership statements with the limitations below. Supports SERVER, ENDPOINT, SERVER_PRINCIPAL and the source branch labelled AVAILABILITY GROUP; unsupported classes yield no SQL row.

## Parameters and defaults

```text
@SourceLogin nvarchar(128) = null, @TargetLogin nvarchar(128) = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns Ordinal int identity, Type varchar(100), SQL nvarchar(max); order explicitly by Ordinal. Read-only. Null source returns no rows. Membership uses database role catalog and source name. Catalog spelling/coverage must be checked for availability-group permissions.

## Dependencies

Native dependencies: `sys.availability_groups`, `sys.availability_replicas`, `sys.database_role_members`, `sys.endpoints`, `sys.server_permissions`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
