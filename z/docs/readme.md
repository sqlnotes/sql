# Installer developer guide

[System and subsystem documentation](../System/docs/readme.md)

Use the installer to put Schema Z in a chosen SQL Server database or update an existing installation. It reads the local SQL files, runs eligible changes in dependency order and records which scripts succeeded. It creates the target database when needed.

Start with the install commands. Use the process and metadata references when you need to author deployment scripts or investigate an update.

- [Install/update commands and parameters](deploy.md)
- [Traversal, repeatability and failure behavior](deployment-process.md)
- [Deployment tables and procedures](reference.md)
- [Preview and verification](testing.md)

Installation also runs administrative setup, including the maintenance job described in the install guide. Your login needs permissions for that work; defining the library does not grant its callers access to every administrative feature.
