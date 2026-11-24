# Security

[System documentation](../../docs/readme.md)

Prepare scripts to recreate logins or copy a principal's permissions, and repair database users whose login mappings no longer match. The scripting functions return SQL for review; the mapping and ownership procedures apply changes directly.

Security works with SQL Server's server logins, database users, roles and permission catalogs. Use it for selected security-administration tasks rather than as a complete security-migration tool.

## Start here

- [Usage and examples](usage.md)
- [Architecture and dependencies](architecture.md)
- [Object reference](reference/readme.md)
- [Troubleshooting and current limitations](troubleshooting.md)

## Operational scope

Functions return script text without executing it. Review generated text before use. Login output can contain password hashes and SIDs: handle it as security material. Permission generators contain known limitations; they are not complete security-migration tools.

## Prerequisites

Server/database security catalogs provide input; native create login, grant/deny/revoke, alter user, and alter authorization provide execution. There are no cross-feature dependencies.

## Version constraint

z.fn_BuildQueryCopyUserPermission references sys.external_languages and its external_language_id/language columns, available from the minimum supported SQL Server version, 2019 (15.x).
