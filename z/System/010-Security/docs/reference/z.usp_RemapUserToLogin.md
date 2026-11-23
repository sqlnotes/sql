# z.usp_RemapUserToLogin

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_RemapUserToLogin.sql)

## Purpose and behavior

Maps existing database users to logins whose names match after optional text substitutions. Use it when user and login naming conventions differ, for example after a domain or naming-prefix change. It changes the login mapping without renaming either principal.

`@UserNameContains` and `@UserNameReplacedWith` describe the substitution used to compare user names. The corresponding Login parameters transform login names for comparison. Omit a search value to use the original names; an omitted replacement keeps the matched text, while an empty string removes it.

Only Windows- or instance-authenticated users with matching principal types and different SIDs are remapped. Ensure each transformed user name identifies the intended login: multiple matching logins are not rejected. The operation is not wrapped in a single transaction, so earlier changes can remain after a later failure.

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
