# z.usp_CreateS3BackupCredential

[Backup objects](readme.md) | [Usage](../usage.md)

Creates the server-level credential used by SQL Server 2022+ S3 backups and restores. Works on Windows and Linux. The credential name is the S3 URL prefix and its identity is `S3 Access Key`.

## Parameters

| Parameter | Type | Meaning |
| --- | --- | --- |
| `@CredentialUrl` | `nvarchar(4000)` | Required `s3://` bucket or folder URL prefix; the normalized credential name must fit 128 UTF-16 code units. |
| `@AccessKeyId` | `nvarchar(4000)` | Required storage access key ID. |
| `@SecretAccessKey` | `nvarchar(4000)` | Required storage secret access key. |
| `@ReplaceExisting` | `bit = 0` | Existing credentials cause an error unless explicitly set to 1, which replaces their identity and secret. |

Trailing forward slashes are removed; URL case is preserved. Supply the same prefix used by the backup destination, without a backup file name, query string or fragment. Both virtual-host and path-style URLs are supported. The helper does not construct endpoints or validate storage connectivity.

Neither key may be empty or contain a colon. Their combined `access-key:secret-key` value must fit 4,000 UTF-16 code units. Provider-specific key validity and permissions remain the provider's responsibility.

## Example

Supply key variables securely through your SQL client:

```sql
exec z.usp_CreateS3BackupCredential
    @CredentialUrl = N's3://example-bucket.s3.us-east-2.amazonaws.com/backups',
    @AccessKeyId = @StorageAccessKeyId,
    @SecretAccessKey = @StorageSecretAccessKey;
```

For key rotation, repeat the call with `@ReplaceExisting = 1`. The helper does not print or return keys or generated SQL. Protect client scripts and diagnostic capture that could record input parameters.

## Permissions and behavior

The caller needs `ALTER ANY CREDENTIAL` at the server level. Executing the procedure alone does not grant that permission; there is no impersonation or privilege elevation. Credentials belong to the SQL Server instance, even when Schema Z is installed in another database. Native DDL errors propagate, including concurrent creation and insufficient permissions.

Region configuration belongs to `BACKUP_OPTIONS` in the [backup procedure](z.usp_BackupDatabase.md), rather than the credential. This procedure does not change that API or create buckets, network endpoints or storage permissions.

See [Microsoft's S3 backup credential requirements](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage).

## Definition

[SQL source](../../modules/1070%20Procedures/z.usp_CreateS3BackupCredential.sql)
