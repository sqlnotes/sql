# Running tests

This guide covers tests for deployed SQL objects. Commands below run from the
`z` directory.

## Product tests: TestDB.ps1

`Deploy.ps1` also supports `-RunTests` (off by default):

```powershell
./Deploy.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests -ShowPlan
./Deploy.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests
```

This mode discovers only reserved `tests` folders in recursive execution order.
It records batches with version `Test`, preserves subsystem version/completion
date, and never calculates, compares, or stores hashes. Test logs have batch/log
IDs without filename/content or script-hash references. Supply and review your
own test tree; tests are not bundled with the public project.

Supply a test tree with a `System/tests` folder using `RootPath`. Test scripts
are not bundled with the public project. First deploy the objects into the intended
test database, then preview your tests:

```powershell
./TestDB.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -ShowPlan
```

Inspect the listed scripts and their side effects before executing them:

```powershell
./TestDB.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System
```

The runner discovers `tests` folders under the module root, including subsystem
and organizational folders. It executes their SQL using the standard folder
order and stops on the first error. It skips `docs` and never deploys product code.
Tests do not use deployment hash skipping or advance subsystem versions.

`TestDB.ps1` accepts `ServerName`, `DatabaseName`, optional `UserName` and `Password`,
`DisableTrustServerCertificate`, `RootPath`, and `ShowPlan`. Authentication behaves like
the deployer, and the default root is `System` beside the script.
The old `-All` and `-PerformTest` options are not supported.

This runner uses the database you specify. It does not create or remove that
database automatically. Administrative tests can create/drop objects or
operate on server traces; use an appropriate test environment and authorized scope.

## Writing tests

Put product tests in the owning subsystem's `tests` folder. Make assertions fail
with an error, keep test data isolated, and clean up objects/data created by the
test. Do not assume rollback alone can undo operations outside the database.
Place explanatory SQL examples in `docs`, where they cannot run accidentally.
