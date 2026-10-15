# z.usp_FixOrphanUser

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_FixOrphanUser.sql)

## Purpose and behavior

For SQL_USER principals with same-named visible server principals and mismatched SIDs, execute ALTER USER WITH LOGIN. Null UserName selects all matches. It does not create missing logins. Cursor operations are not wrapped in an explicit transaction; earlier changes can persist if later execution fails.

## Parameters and defaults

```text
@UserName nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires permission to alter selected users and visibility of server principals.

## Dependencies

Native dependencies: `sys.database_principals`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
