# Security troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Diagnose current behavior

A null source in either permission-copy function returns no rows because the catalog filter compares the name to null. Membership output uses the source principal instead of the requested target. The server generator incorrectly joins sys.database_role_members; server membership output cannot be trusted. The user generator emits revoke ... to for object/column permissions and derives XML collection schema from sys.types; those scripts can be invalid or omitted. Visibility depends on the caller. z.usp_ChangeServerRoleOwnerToSA uses the literal login sa, so it can fail when that login has been renamed.

## Permission and partial-operation failures

Server/database security catalogs provide input; native create login, grant/deny/revoke, alter user, and alter authorization provide execution. There are no cross-feature dependencies.

Read the relevant callable reference before retrying a failed write. Some procedures roll back any open transaction, including a caller's transaction; others leave earlier operations committed. Native server resources and filesystem actions do not share a single database rollback boundary. Catalog/DMV access is evaluated on the deployed server and depends on SQL Server version and caller context.

## Verification limits

These pages describe source behavior. A successful installation or module compilation does not demonstrate successful mail delivery, backup restoration, SQL Agent execution, trace workload collection, security migration, or application-specific Broker delivery.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns. This catalog is a SQL Server 2019-era feature, so the current function is not a reliable SQL Server 2017 interface despite the project baseline. Check the target version before installing or using it.
