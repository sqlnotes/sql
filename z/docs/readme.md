# Installer developer guide

[System and subsystem documentation](../System/docs/readme.md)

- [Install/update commands and parameters](deploy.md)
- [Traversal, repeatability and failure behavior](deployment-process.md)
- [Deployment tables and procedures](reference.md)
- [Preview and verification](testing.md)

The installer deploys local SQL source to a specified database. It can create the database if absent, create schema `z`, initialize metadata, then execute System and numbered children. It does not grant a complete application permission model or make all administrative features available on every edition/platform.
