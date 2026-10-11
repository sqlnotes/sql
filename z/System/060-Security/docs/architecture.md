# Security architecture

[Subsystem](readme.md) | [Object index](reference/readme.md)

## Dependencies and installation

Server/database security catalogs provide input; native create login, grant/deny/revoke, alter user, and alter authorization provide execution. There are no cross-feature dependencies.

The numbered folder installs in System's alphabetical child order. Shared System modules run before feature children; System post scripts run after all children. See [System documentation](../../docs/readme.md) for deployment and orchestration. Baseline tables use existence guards; they do not reconcile an existing table schema. Module definitions use create or alter.

## Data and control flow

The three `z.fn_BuildQueryCopy*` functions read security catalogs and return executable SQL text; callers decide whether and where to run it. Login creation and permission application are separate steps. `z.usp_FixOrphanUser` and `z.usp_RemapUserToLogin` directly change current-database user-to-login mappings. `z.usp_ChangeServerRoleOwnerToSA` directly changes server-role ownership. No subsystem procedure automatically applies the generated copy scripts or wraps an entire security migration in a transaction.

Functions return script text without executing it. Review generated text before use. Login output can contain password hashes and SIDs: handle it as security material. Permission generators contain known limitations; they are not complete security-migration tools.

Each callable reference describes writes, generated SQL, transaction boundaries, results and inputs. Supporting references describe keys, payloads and units. Procedures do not supply a blanket permission grant or one transaction around an entire administrative workflow.

## Integration constraints

A null source in either permission-copy function returns no rows because the catalog filter compares the name to null. Membership output uses the source principal instead of the requested target. The server generator incorrectly joins sys.database_role_members; server membership output cannot be trusted. The user generator emits revoke ... to for object/column permissions and derives XML collection schema from sys.types; those scripts can be invalid or omitted. Visibility depends on the caller. z.usp_ChangeServerRoleOwnerToSA uses the literal login sa, so it can fail when that login has been renamed.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns. This catalog is a SQL Server 2019-era feature, so the current function is not a reliable SQL Server 2017 interface despite the project baseline. Check the target version before installing or using it.
