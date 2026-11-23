# z.fn_BuildQueryCopyLoginPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyLoginPermission.sql)

## Purpose and behavior

Produces scripts to copy a login's explicit server permissions and server-role memberships. It does not create the destination login or execute the returned statements.

Supply the existing principal in `@SourceLogin`. Set `@TargetLogin` to put the copied permissions on another principal, or leave it NULL to keep the source name. A NULL source returns no rows. Supported permission classes are `SERVER`, `ENDPOINT`, `SERVER_PRINCIPAL` and `AVAILABILITY GROUP`.

## Parameters and defaults

```text
@SourceLogin nvarchar(128) = null, 
@TargetLogin nvarchar(128) = null
```

## Results, permissions, and limits

Returns `Ordinal int`, `Type varchar(100)` and `SQL nvarchar(max)`. `Type` describes the generated statement and `SQL` contains the text to review or apply. Read rows in `Ordinal` order. Catalog visibility limits which permissions and role memberships can be scripted.

## Dependencies

Native dependencies: `sys.availability_groups`, `sys.availability_replicas`, `sys.endpoints`, `sys.server_permissions`, `sys.server_principals`, `sys.server_role_members`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
