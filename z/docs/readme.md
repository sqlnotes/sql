# Deployment developer guide

Start here when using or changing the Schema Z deployment tools.
Command examples in these guides assume your working directory is `z`.

1. [Deploy a database](deploy.md): prerequisites, authentication, preview, and redeployment.
2. [Run tests](testing.md): tests for deployed SQL objects and test authoring.
3. [Understand the process](deployment-process.md): folder traversal, subsystem versions,
   script hashes, logging, and guidelines for writing deployment scripts.

The tools are `Deploy.ps1`, `Deploy.sql`, `Deploy.Common.ps1`, and `TestDB.ps1`.
Documentation for individual modules belongs in their own `docs` folders, such
as [System/docs](../System/docs/readme.md). Documentation contents are never executed.
