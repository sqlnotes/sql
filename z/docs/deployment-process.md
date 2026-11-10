# Deployment process

[Installer guide](readme.md) Â· [Metadata reference](reference.md)

## Source and plan

[Deploy.ps1](../Deploy.ps1) orchestrates execution. [Deploy.Common.ps1](../Deploy.Common.ps1) defines traversal/connection/RPC helpers. [Deploy.sql](../Deploy.sql) bootstraps database/schema and current metadata; it requires SQLcmd mode and DatabaseName substitution.

Each folder visits pre â†’ baseline â†’ versions â†’ modules â†’ direct SQL files â†’ other folders alphabetically â†’ post. Files sort by filename with ordinal case-insensitive comparison. Version children parse as .NET Version and sort numerically. The installed version is included, along with newer versions; hashing normally prevents unchanged replay.

Only nonreserved children of subsystem roots become separately owned/versioned systems. Reserved names are pre, baseline, versions, modules, post, tests, docs. Descendants within a reserved stage organize that stage's files. Docs are excluded. Linked/reparse-point folders and invalid version paths are rejected.

Children run sequentially: 010-Jobs, 010-Partition, 010-Security, 010-Trace, 012-TaskQueue, 020-Backup, 020-Monitoring, then 050-AsyncChannel. A shared numeric prefix groups children with no installation ordering dependency among themselves; the installer still sorts their complete folder names alphabetically. System modules precede children and System post follows them.

The existing `890-SystemBeforePost/1010 Procedures` helpers are installed after the feature children and before System root post. Ordinary child discovery gives `890-SystemBeforePost` and its procedure folder separate deployment identities. Root post invokes general-maintenance job setup on each deployment.

## Baselines and identities

Baseline eligibility is decided independently for each owning subsystem. Fresh/unversioned systems at 0.0.0 include baseline followed by all available versions. Existing systems with zero or one version folder also include baseline, followed by the installed version folder and higher versions when present. Existing systems with more than one version folder skip the entire baseline subtree, including its pre/post stages. Only direct numeric version folders count; reserved stage folders and .vs do not. Eligible ordinary files still use hash checking; eligible pre/post scripts always run. Children without migrations can remain 0.0.0.

When version folders exist, a nonzero installed version older than the earliest retained version is rejected with an upgrade-path error. Upgrade using an intermediate release before using a source tree whose older migrations have been consolidated into baseline. Fresh installations can use the consolidated baseline. Versions above the latest available version remain rejected as downgrades.

CodeBase uses paths such as `/System/010-Partition`. SQL derives SystemID as GUID from MD5 of `trim(lower(CodeBase))`. Case/outer-space aliases share identity according to SQL normalization/collation; paths are not normalized independently by PowerShell. Renaming a folder, including its prefix, changes identity. The renamed Trace, Jobs, Backup and Security paths therefore initialize new subsystem owners and hashes; guarded baselines become eligible under those owners. Existing metadata history remains under the former paths; the installer does not remap it or carry its version forward. Review baseline replay before updating an existing installation.

## Hashes and logs

Every executed product script, including pre/post, gets SHA-256 from UTF-8 encoding of the original decoded file text. It is a content hash, not a hash of SQLcmd-expanded or sanitized SQL. Hashes are scoped to subsystem owner.

Only current successful hashes skip eligible scripts. Pre/post always execute within an eligible subtree, even if their hashes exist. Failed content retries. Identical contents share a canonical first filename; filenames alone do not determine identity.

Before metadata RPC, content containing password or encryption is replaced entirely with `***`. This keyword filter is not general secret detection; keep secret literals out of source. Original text is used for execution/hashing.

Logs reference owner/hash and retain failure text/times. Pruning deactivates obsolete hashes, preserving history and successful baseline/version rows. Tests have null hashes and no retained source content.

## Transactions, locking and failures

Bootstrap table creation is transactional; individual metadata begin/complete operations are transactional. The metadata connection holds session-owned binary semaphore `z.Deploy` with zero wait; a competing installer fails promptly. Bootstrap installs the shared semaphore helpers before the deployment-lock procedures. Bootstrap precedes this semaphore acquisition, so it does not serialize the complete bootstrap phase.

Before installing this synchronization update, stop active installers and drain affected Session-owned routines. Older callers may hold native locks without shared-helper context; replacing their release procedures mid-run cannot release those old holds through the new protocol. Let the old operation release them first, or close its physical connection before updating.

Product files execute through separate SQL execution connections. Each starts with standard session options/open-transaction guard and ends with an open-transaction rollback/error guard. A file manages its own transaction. Entire deployment is not atomic; successful prior files/children remain after a later failure.

Versions advance only on successful subsystem completion. Incomplete ancestors are marked failed when a child fails; completed siblings retain success. Investigate the failed log and partial state before retry. Hash disabling does not override baseline/version eligibility.
