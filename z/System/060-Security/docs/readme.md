# Security

[System documentation](../../docs/readme.md)

Generate login and permission scripts, repair SQL-user SID mappings, remap users to logins by transformed names, and change server-role owners.

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
