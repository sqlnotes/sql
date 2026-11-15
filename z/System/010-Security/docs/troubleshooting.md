# Security troubleshooting

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Behavior and constraints

- A `null` `@SourceLogin` or `@SourceUser` in `z.fn_BuildQueryCopyLoginPermission` or `z.fn_BuildQueryCopyUserPermission` returns no rows because the catalog filter compares the principal name to `@SourceLogin` / `@SourceUser`.
- Both permission generators substitute `@TargetLogin` / `@TargetUser` (when supplied) in permission statements and role membership statements (`alter server role ... add member ...` and `alter role ... add member ...`).
- `z.usp_ChangeServerRoleOwnerToSA` transfers ownership of non-fixed server roles to the login named `sa`; if `sa` has been renamed, the generated `alter authorization` statement will fail.
- `z.usp_FixOrphanUser` remaps instance-authenticated `SQL_USER` principals whose SIDs differ from a same-named `SQL_LOGIN`.

## Version constraint

`z.fn_BuildQueryCopyUserPermission` references `sys.external_languages` (`external_language_id`, `language`), available starting in SQL Server 2019 (15.x).

