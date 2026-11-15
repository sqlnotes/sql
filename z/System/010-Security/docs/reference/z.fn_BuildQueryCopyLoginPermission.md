# z.fn_BuildQueryCopyLoginPermission

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyLoginPermission.sql)

## Purpose and behavior

Generates explicit server permissions and server-role membership statements (`alter server role ... add member ...`) for `@SourceLogin`, substituting `@TargetLogin` when supplied. Supports `SERVER`, `ENDPOINT`, `SERVER_PRINCIPAL`, and `AVAILABILITY GROUP` permission classes.

## Parameters and defaults

```text
@SourceLogin nvarchar(128) = null, 
@TargetLogin nvarchar(128) = null
```

## Results, permissions, and limits

Returns `Ordinal int identity`, `Type varchar(100)`, `SQL nvarchar(max)`; order explicitly by `Ordinal`. Read-only. A `null` `@SourceLogin` returns no rows.

## Dependencies

Native dependencies: `sys.availability_groups`, `sys.availability_replicas`, `sys.endpoints`, `sys.server_permissions`, `sys.server_principals`, `sys.server_role_members`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
