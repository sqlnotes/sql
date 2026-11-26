# z.fn_BuildQueryCopyLogin

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyLogin.sql)

## Purpose and behavior

Produces SQL scripts to recreate SQL logins, Windows logins/groups and user-defined server roles. Use it when preparing selected principals for another instance or creating a copy under a new name. It returns the scripts without running them.

`@SourceLogin` selects one principal; NULL includes all visible supported principals except `public` and fixed roles. `@TargetLogin` supplies the name to use in generated statements; NULL keeps the original names.

## Parameters and defaults

```text
@SourceLogin nvarchar(128) = null, 
@TargetLogin nvarchar(128) = null
```

## Results, permissions, and limits

Returns `ServerPrincipalID`, `LoginName`, `LoginType` and `SQL`. Review the `SQL` column before executing it. SQL-login scripts contain password hashes and preserve the source `SID` (omit or change `sid = ...` when creating a renamed copy on the same instance to avoid a duplicate-SID error), so restrict access to the output. They include default language and password-policy settings, but omit default database and disabled state. Metadata and password-hash visibility determine how complete the output can be.

## Dependencies

Native dependencies: `sys.server_principals`, `sys.sql_logins`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
