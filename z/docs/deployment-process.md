# Deployment process

[Installer guide](readme.md) · [Metadata reference](reference.md)

## Source and plan

[Deploy.ps1](../Deploy.ps1) orchestrates execution. [Deploy.Common.ps1](../Deploy.Common.ps1) defines traversal/connection/RPC helpers. [Deploy.sql](../Deploy.sql) bootstraps database/schema and current metadata; it requires SQLcmd mode and DatabaseName substitution.

Each folder visits pre → baseline → versions → modules → direct SQL files → other folders alphabetically → post. Files sort by filename with ordinal case-insensitive comparison. Version children parse as .NET Version and sort numerically. The installed version is included, along with newer versions; hashing normally prevents unchanged replay.

Only nonreserved children of subsystem roots become separately owned/versioned systems. Reserved names are pre, baseline, versions, modules, post, tests, docs. Descendants within a reserved stage organize that stage's files. Docs are excluded. Linked/reparse-point folders and invalid version paths are rejected.

Children run sequentially: 010-Jobs, 010-Partition, 010-Security, 010-Trace, 020-Backup, 020-Monitoring, then 070-Async. A shared numeric prefix groups children with no installation ordering dependency among themselves; the installer still sorts their complete folder names alphabetically. System modules precede children and System post follows them.

## Baselines and identities

Installed version >0.0.0 excludes the owning subsystem's entire baseline subtree, even with hash checking disabled. Unversioned/new systems at 0.0.0 remain eligible. Children without migrations can remain 0.0.0, using hashes for repeat skipping.

CodeBase uses paths such as `/System/010-Partition`. SQL derives SystemID as GUID from MD5 of `trim(lower(CodeBase))`. Case/outer-space aliases share identity according to SQL normalization/collation; paths are not normalized independently by PowerShell. Renaming a folder, including its prefix, changes identity. The renamed Trace, Jobs, Backup and Security paths therefore initialize new subsystem owners and hashes; guarded baselines become eligible under those owners. Existing metadata history remains under the former paths; the installer does not remap it or carry its version forward. Review baseline replay before updating an existing installation.

## Hashes and logs

Every executed product script, including pre/post, gets SHA-256 from UTF-8 encoding of the original decoded file text. It is a content hash, not a hash of SQLcmd-expanded or sanitized SQL. Hashes are scoped to subsystem owner.

Only current successful hashes skip eligible scripts. Pre/post always execute within an eligible subtree, even if their hashes exist. Failed content retries. Identical contents share a canonical first filename; filenames alone do not determine identity.

Before metadata RPC, content containing password or encryption is replaced entirely with `***`. This keyword filter is not general secret detection; keep secret literals out of source. Original text is used for execution/hashing.

Logs reference owner/hash and retain failure text/times. Pruning deactivates obsolete hashes, preserving history and successful baseline/version rows. Tests have null hashes and no retained source content.

## Transactions, locking and failures

Bootstrap table creation is transactional; individual metadata begin/complete operations are transactional. The metadata connection holds session-owned exclusive application lock `z.Deploy` with zero wait; a competing installer fails promptly. Bootstrap precedes this lock, so it does not serialize the complete bootstrap phase.

Product files execute through separate SQL execution connections. Each starts with standard session options/open-transaction guard and ends with an open-transaction rollback/error guard. A file manages its own transaction. Entire deployment is not atomic; successful prior files/children remain after a later failure.

Versions advance only on successful subsystem completion. Incomplete ancestors are marked failed when a child fails; completed siblings retain success. Investigate the failed log and partial state before retry. Hash disabling does not override baseline/version eligibility.
