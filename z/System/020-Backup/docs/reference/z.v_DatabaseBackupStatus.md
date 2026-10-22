# z.v_DatabaseBackupStatus

[Backup](../readme.md) | [View source](../../modules/1020%20Views/z.v_DatabaseBackupStatus.sql)

Shows three rows for every database visible through `sys.databases`: FULL, DIFF and LOG. The key is `(DatabaseID, BackupType)`. Backup status comes from database-level extended properties in the database containing this view, including for read-only backup targets. Visibility and property access depend on caller permissions; a visible type row does not establish native backup eligibility.

| Columns | Meaning |
| --- | --- |
| DatabaseID, DatabaseName, CreateDate | Current catalog identity; read-only. |
| IsReadOnly, StateDescription | Current catalog state; read-only. |
| BackupType | FULL, DIFF or LOG; read-only. |
| RunID | Nullable uppercase 64-character hexadecimal database-set hash. |
| SettingsHash | Nullable uppercase 64-character hexadecimal backup-settings hash. |
| SessionID | Nullable positive SQL session ID recorded by the caller. |
| StartDate, EndDate | Nullable `datetime2(7)` status timestamps; callers use UTC. |
| BackupStatus | Derived Unassigned, Pending, Started or Completed; read-only. |
| MetadataStatus | Missing, Invalid, Stale or Valid; read-only. |

Each database/type uses property `z.Backup.Work.<DatabaseID>.<BackupType>`, with no level arguments. JSON contains DatabaseID, DatabaseName, CreateDate, BackupType, RunID, SettingsHash, SessionID, StartDate and EndDate. Stored identity must match the current catalog; a reused database ID, changed name or creation date produces Stale. Malformed JSON, fields, types, backup type or state produce Invalid. Missing, Invalid and Stale properties expose null status fields and Unassigned; the catalog/type row remains visible.

Old untyped `z.Backup.Work.<DatabaseID>` records are ignored and retained. Their hashes cannot identify which backup type they represented, so their completion flags are not copied. Stop all existing workers before upgrading the view, trigger and procedure together, then start fresh typed work. Old separate run-settings properties are also unused. Backup files are unaffected by this metadata transition.

Pending means a RunID exists without a start time. Started means a session and start time exist without an end time. Completed includes an end time. Started describes recorded state; it does not prove the session still owns an active backup. Execution locks remain the scheduler's authority.

## Trigger

[`z.TRI_v_DatabaseBackupStatus`](../../modules/1080%20Triggers/z.TRI_v_DatabaseBackupStatus.sql) handles `INSTEAD OF UPDATE`. Only RunID, SettingsHash, SessionID, StartDate and EndDate are writable. It supports multiple rows and adds or updates one property per database through the native extended-property procedures. Setting all five fields to NULL removes that exact property. Assigning a new valid status can repair malformed or stale metadata.

RunID and SettingsHash must each be a 64-character uppercase hexadecimal value whenever status is present. SessionID and StartDate must either both be NULL or both present; SessionID must be positive. EndDate requires a start time and cannot precede it. The trigger stores current catalog identity and backup type and includes all nine JSON keys. Individual values must fit the extended-property 7,500-byte limit.

Updates participate in the caller's transaction. An exclusive transaction application lock on `z.Backup.Register` serializes writers until commit or rollback. The trigger compares the originally selected status with the current visible status after acquiring the gate and rejects changes that would overwrite another writer. Invalid/stale payloads are intentionally repairable; their hidden raw JSON is not a concurrency token. A session already holding the session-owned registration gate must release it before updating this view.

Requires UPDATE permission on the view, database-level extended-property write permissions and application-lock access. The trigger uses the caller's execution context and grants no additional permissions. INSERT and DELETE are unsupported. `z.usp_BackupDatabase` registers, claims and completes work by updating this view in short transactions. Status updates record metadata; the caller performs the actual backup and enforces assignment/ownership rules.

See [usage](../usage.md) and [backup coordination](z.usp_BackupDatabase.md#parallel-sessions).
