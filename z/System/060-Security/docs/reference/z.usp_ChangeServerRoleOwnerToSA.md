# z.usp_ChangeServerRoleOwnerToSA

[Security](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_ChangeServerRoleOwnerToSA.sql)

## Purpose and behavior

Change ownership of visible SERVER_ROLE principals whose owning_principal_id differs from 1 to the literal login sa. Null CurrentOwnerName selects all such roles; otherwise current owner name uses LIKE, including wildcard semantics. No explicit transaction or catch; earlier role changes can persist on error.

## Parameters and defaults

```text
@CurrentOwnerName nvarchar(128) = null
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires native authority to alter selected server-role ownership; literal sa must exist.

## Dependencies

Native dependencies: `sys.server_principals`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
