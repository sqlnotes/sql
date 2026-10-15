# Backup usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select DatabaseName, BackupType, BackupFinishDate, LatestBackupLocation
from z.v_BackupRestore
where DatabaseName = db_name();
```

Backup execution can delete earlier backup files. The retention scan is based on msdb history and is not restricted to the requested backup folder. The parameterless Full/Log wrappers contain a fixed UNC destination; inspect them before use.
