# z.fn_BuildQueryCopyLogin

[Security](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_BuildQueryCopyLogin.sql)

## Purpose and behavior

Generate create statements for SQL/Windows logins, Windows groups, and non-fixed server roles. Null source includes visible supported principals except public/fixed roles. Null target keeps source names. SQL-login output includes hashed password, SID, default language and password-policy settings, but not default database or disabled state.

## Parameters and defaults

```text
@SourceLogin nvarchar(128) = null, @TargetLogin nvarchar(128) = null
```

These are the source-declared types and defaults. Table-valued-function callers must supply arguments or the `default` keyword explicitly.

## Results, permissions, and limits

Returns ServerPrincipalID, LoginName, LoginType, SQL. Metadata/hash visibility controls completeness; read-only.

## Dependencies

Native dependencies: `sys.server_principals`, `sys.sql_logins`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
