# z.usp_FixOrphanUser

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_FixOrphanUser.sql)

## Purpose and behavior

Repairs instance-authenticated SQL database users whose SID no longer matches a same-named SQL login, such as after moving a database to another instance. It maps each eligible user to that existing login and does not create missing logins.

Supply `@UserName` to select one user, or leave it NULL to repair all matching visible users in the current database. Changes are applied directly without a single transaction around the whole operation; earlier repairs can persist if a later one fails.

## Parameters and defaults

```text
@UserName nvarchar(128) = null
```

## Results, permissions, and limits

No defined result set. Requires permission to alter selected users and visibility of server principals.

## Dependencies

Native dependencies: `sys.database_principals`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
