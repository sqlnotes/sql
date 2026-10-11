# Schema Z

Schema Z is a SQL Server library of shared SQL utilities and administration
features. SQL objects use the `z` schema. Numbered subsystem folders establish
deployment order and independent deployment histories.

Start with the [System developer guide](z/System/docs/readme.md). It links to
shared utilities, object references, and the seven feature subsystems:

- [Partition](z/System/010-Partition/docs/readme.md): boundaries and retention.
- [Monitoring](z/System/020-Monitoring/docs/readme.md): sessions and resource information.
- [Trace](z/System/030-Trace/docs/readme.md): SQL Trace configuration and collection.
- [Jobs](z/System/040-Jobs/docs/readme.md): SQL Agent jobs and schedule helpers.
- [Backup](z/System/050-Backup/docs/readme.md): backups and database snapshots.
- [Security](z/System/060-Security/docs/readme.md): permission generators and user utilities.
- [Async](z/System/070-Async/docs/readme.md): Service Broker sender infrastructure.

Read [deployment](z/docs/deploy.md) before running `z/Deploy.ps1`. Review each
feature's prerequisites and limitations before using its examples. Installation
does not automatically configure every operational feature.

The documentation beside the code is the authoritative developer reference.
Reference pages link to SQL definitions and describe current behavior, including
known limitations. The former wiki and separate legacy guides are retired.

For deployment mechanics and authoring scripts, see the
[deployment developer guide](z/docs/readme.md).
