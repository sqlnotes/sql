# Running tests

This guide covers tests for deployed SQL objects. Commands below run from the
`z` directory.

## Product tests: Deploy.ps1 -RunTests

First deploy the required objects into the intended test database. Supply your
test tree and preview `-RunTests` (off by default):

```powershell
./Deploy.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests -ShowPlan
./Deploy.ps1 -ServerName MyTestServer -DatabaseName MyTestDatabase -RootPath ./MyTestSuite/System -RunTests
```

This mode discovers only reserved `tests` folders in recursive execution order.
It records batches with version `Test`, preserves subsystem version/completion
date, and never calculates, compares, or stores hashes. Test logs have batch/log
IDs without filename/content or script-hash references. Supply and review your
own test tree; tests are not bundled with the public project.

Inspect the previewed scripts and their side effects before execution. Discovery
includes subsystem and organizational folders, skips `docs`, and stops at the
first SQL error. Product code is not deployed in test mode.

Use the deployment authentication and certificate parameters; the default root is
`System` beside the script.
The old `-All` and `-PerformTest` options are not supported.

Test mode initializes deployment metadata in the specified database and can
create it when missing; it does not remove the database automatically.
Administrative tests can create/drop objects or
operate on server traces; use an appropriate test environment and authorized scope.

## Writing tests

Put product tests in the owning subsystem's `tests` folder. Make assertions fail
with an error, keep test data isolated, and clean up objects/data created by the
test. Do not assume rollback alone can undo operations outside the database.
Place explanatory SQL examples in `docs`, where they cannot run accidentally.
