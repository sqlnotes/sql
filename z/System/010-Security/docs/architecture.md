# Security architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

Server and database security catalogs provide input; native `create login`, `grant`/`deny`/`revoke`, `alter user`, and `alter authorization` provide execution. There are no cross-feature dependencies.

## Data and control flow

The three `z.fn_BuildQueryCopy*` functions read security catalogs and return executable SQL text without executing it:
- `z.fn_BuildQueryCopyLogin` scripts SQL logins (with hashed passwords and SIDs), Windows logins/groups, and user-defined server roles.
- `z.fn_BuildQueryCopyLoginPermission` scripts server-level permissions and server-role memberships (`sys.server_role_members`), substituting `@TargetLogin` when provided.
- `z.fn_BuildQueryCopyUserPermission` scripts database-level permissions and database-role memberships (`sys.database_role_members`), substituting `@TargetUser` when provided.

`z.usp_FixOrphanUser` and `z.usp_RemapUserToLogin` directly update current-database user-to-login mappings. `z.usp_ChangeServerRoleOwnerToSA` transfers ownership of user-defined server roles to `sa`.

## Version constraint

`z.fn_BuildQueryCopyUserPermission` references `sys.external_languages`, available starting in SQL Server 2019 (15.x).

