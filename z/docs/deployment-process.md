# Deployment process

[Installer guide](readme.md) · [Metadata reference](reference.md)

The installer applies local SQL files in a predictable order, skips eligible scripts that have already succeeded unchanged, and keeps a history of each update. Use this page to understand repeat deployments, add a migration, or decide what to do after a failure. For commands and connection options, start with [install and update](deploy.md).

## Source and plan

[Deploy.ps1](../Deploy.ps1) orchestrates execution. [Deploy.Common.ps1](../Deploy.Common.ps1) defines traversal/connection/RPC helpers. [Deploy.sql](../Deploy.sql) bootstraps database/schema and current metadata; it requires SQLcmd mode and DatabaseName substitution.

Within a folder, setup scripts run before definitions and cleanup runs afterward: `pre` → `baseline` → `versions` → `modules` → direct SQL files → other child folders → `post`. Ordinary files and child folders sort alphabetically, ignoring case; version folders sort by version number. The installed version is included along with newer versions, but unchanged scripts normally skip through hash checking.

Only nonreserved children of subsystem roots become separately owned/versioned systems. Reserved names are pre, baseline, versions, modules, post, tests, docs. Descendants within a reserved stage organize that stage's files. Docs are excluded. Linked/reparse-point folders and invalid version paths are rejected.

Children run sequentially: 010-Jobs, 010-Partition, 010-Security, 010-Trace, 012-TaskQueue, 020-Backup, 020-Monitoring, then 050-AsyncChannel. A shared numeric prefix groups children with no installation ordering dependency among themselves; the installer still sorts their complete folder names alphabetically. System modules precede children and System post follows them.

The existing `890-SystemBeforePost/1010 Procedures` helpers are installed after the feature children and before System root post. Ordinary child discovery gives `890-SystemBeforePost` and its procedure folder separate deployment identities. Root post invokes general-maintenance job setup on each deployment.

## Baselines and identities

The installer reads each subsystem's installed version independently. A fresh or unversioned subsystem starts at 0.0.0. Only direct numeric children of `versions/` determine the supported range.

| Installed state | Baseline | Version folders visited |
| --- | --- | --- |
| No version folders | Included | None. Eligible non-version scripts in `versions/` still run. |
| Fresh, 0.0.0, or equal to the first retained version | Included | First through latest |
| Above the first version and at or below the latest | Skipped, including its pre/post scripts | Installed through latest |
| Nonzero and below the first version, or above the latest | Deployment rejected | None |

An installation below the retained version floor requires reinstallation. Hash checking applies to eligible ordinary scripts. Eligible pre/post scripts run on every deployment.

### Baseline, migrations and rebasing

The baseline contains complete initial table definitions and can be deployed
without version folders. During initial-version development, put the initial
columns, constraints and indexes directly in those definitions. Keep incremental upgrades in version folders.

After that initial definition is established, preserve it. Put each subsequent
schema change in the appropriate version folder, including CREATE TABLE for a
new table. For example, an existing 0.0.0 installation receives the guarded
0.0.1 migration. An empty installation receives the complete initial baseline;
that migration detects the already-present schema and performs no changes.
The installer still visits the version folder. A later 0.0.2 column addition
belongs in its migration rather than an edit to the baseline; fresh installations
reach that version by applying the later migrations after baseline creation.

A deliberate rebase replaces the baseline with the complete schema at the new supported floor and consolidates older migrations. Plan explicitly for existing unversioned databases because the installer also uses 0.0.0 for a fresh installation.

CodeBase uses paths such as `/System/010-Partition`. SQL derives SystemID as GUID from MD5 of `trim(lower(CodeBase))`. Case/outer-space aliases share identity according to SQL normalization/collation; paths are not normalized independently by PowerShell. Renaming a folder, including its prefix, changes identity. The renamed Trace, Jobs, Backup and Security paths therefore initialize new subsystem owners and hashes; guarded baselines become eligible under those owners. Existing metadata history remains under the former paths; the installer does not remap it or carry its version forward. Review baseline replay before updating an existing installation.

## Hashes and logs

Every executed product script, including pre/post, gets SHA-256 from UTF-8 encoding of the original decoded file text. It is a content hash, not a hash of SQLcmd-expanded or sanitized SQL. Hashes are scoped to subsystem owner.

Only current successful hashes skip eligible scripts. Pre/post always execute within an eligible subtree, even if their hashes exist. Failed content retries. Identical contents share a canonical first filename; filenames alone do not determine identity.

Stored source text is replaced with `***` when it contains the keywords `password` or `encryption`. This limits what is recorded in deployment metadata; it does not change the SQL that executes or reliably detect every secret. Keep secret values out of source files.

Logs reference owner/hash and retain failure text/times. Pruning deactivates obsolete hashes, preserving history and successful baseline/version rows. Tests have null hashes and no retained source content.

## Transactions, locking and failures

Bootstrap table creation and individual metadata begin and complete operations are transactional. After bootstrap, the metadata connection takes the exclusive session-owned application lock `z.Deploy` with zero wait. A competing installer using the same lock fails promptly. Bootstrap runs before the lock is taken. The shared semaphore procedures are installed later by System module traversal.

Finish active installations before applying this update. Earlier installers acquired the slot lock `1-z.Deploy`. This version acquires `z.Deploy`, so the two versions can hold different locks at the same time. Let routines using the earlier semaphore format release their permits or disconnect before the System helpers are replaced. [Semaphore ownership and upgrades](../System/docs/reference/coordination.md#semaphores)

Product files execute through separate SQL execution connections. Each starts with standard session options/open-transaction guard and ends with an open-transaction rollback/error guard. A file manages its own transaction. Entire deployment is not atomic; successful prior files/children remain after a later failure.

Versions advance only on successful subsystem completion. Incomplete ancestors are marked failed when a child fails; completed siblings retain success. Investigate the failed log and partial state before retry. Hash disabling does not override baseline/version eligibility.
