# z.usp_RemapUserToLogin

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemapUserToLogin.sql)

## Purpose and behavior

Compare transformed database-user and server-login names for WINDOWS/INSTANCE authentication and matching principal types with unequal SIDs, then execute ALTER USER WITH LOGIN. REPLACE is applied to names only for matching; it does not rename principals. Null patterns fall back to original names. Multiple matching logins are not rejected. No explicit transaction or catch.

## Parameters and defaults

```text
@UserNameContains nvarchar(128) = null,@UserNameReplacedWith nvarchar(128) = null,@LoginNameContains nvarchar(128) = null,@LoginNameReplacedWith nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires ALTER USER authority and metadata visibility. User replacement null falls back to the user pattern; login replacement null makes REPLACE null and falls back to original login.

## Dependencies

Native dependencies: `sys.database_principals`, `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
