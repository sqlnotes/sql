# z.usp_ChangeServerRoleOwnerToSA

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_ChangeServerRoleOwnerToSA.sql)

## Purpose and behavior

Transfers ownership of user-defined server roles to the login named `sa`. Use it when replacing individual administrator ownership with a common server-role owner. Roles already owned by principal ID 1 and fixed server roles are left unchanged.

`@CurrentOwnerName` limits the changes to roles owned by a matching login. It uses SQL `LIKE` patterns, so `%` and `_` are wildcards. Leave it NULL to select all eligible visible roles. Changes are applied directly without a single transaction around the whole operation; earlier changes can persist if a later one fails.

## Parameters and defaults

```text
@CurrentOwnerName nvarchar(128) = null
```

## Results, permissions, and limits

No defined result set. Requires native authority to alter selected server-role ownership; literal sa must exist.

## Dependencies

Native dependencies: `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
