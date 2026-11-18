# z.usp_RemapUserToLogin

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemapUserToLogin.sql)

## Purpose and behavior

Compare transformed database-user and server-login names for WINDOWS/INSTANCE authentication and matching principal types with unequal SIDs, then execute ALTER USER WITH LOGIN. REPLACE is applied to names only for matching; it does not rename principals. Null patterns fall back to original names. Multiple matching logins are not rejected. No explicit transaction or catch.

## Parameters and defaults

```text
@UserNameContains nvarchar(128) = null,
@UserNameReplacedWith nvarchar(128) = null,
@LoginNameContains nvarchar(128) = null,
@LoginNameReplacedWith nvarchar(128) = null
```

## Results, permissions, and limits

No defined result set. Requires ALTER USER authority and metadata visibility. For either side, a NULL replacement defaults to that side's search text, leaving the original name intact. Supply an empty replacement string to remove the matched text.

## Dependencies

Native dependencies: `sys.database_principals`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
