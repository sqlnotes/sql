# Database settings

[Object index](readme.md)

Use settings to share named text values among procedures in one database. Write a value with `z.usp_SetSetting` and read it with `z.fn_GetSetting`; for example, an application can store its default retention period as `System.DefaultRetentionDays`. Settings affect only code that chooses to read them.

## z.Settings

[Source](../../baseline/2020%20Tables/z.Settings.sql)

Stores settings in the current database. Names use the database collation and
may use dotted groups such as `System.DefaultRetentionDays`.

| Column | Type | Behavior |
| --- | --- | --- |
| Name | nvarchar(200), required | Clustered primary key `PK_z_Settings` |
| Value | nvarchar(max), required | Unicode text, including empty strings |
| Description | nvarchar(1000), nullable | Optional explanation |

Values are text; consumers own type conversion and validation. No settings are
seeded and no existing routine automatically reads this table. Missing settings
and empty values are distinct. The table does not provide encrypted secret storage.

The table is installed with System's baseline. When updating an existing
database, baseline eligibility determines whether a newly added table script
runs; see the [deployment rules](../../../docs/deployment-process.md#baselines-and-identities).
Re-running the guarded table script preserves existing rows, but does not
change the definition of a table that already exists.

## z.fn_GetSetting

Reads one setting by name. It returns the stored text, or NULL when the setting does not exist. Convert the text to the type your application expects.

[Source](../../modules/1010%20Functions/z.fn_GetSetting.sql)

```sql
create or alter function z.fn_GetSetting
(
	@Name nvarchar(200)
)
returns nvarchar(max)
```

Returns the matching value, or null when the setting is missing or the name is
null. There is no default-value parameter. Reading does not insert a setting.
Grant EXECUTE on this scalar function to callers who need to read settings.

## z.usp_SetSetting

Creates a setting or changes its value. Supply a name and a non-NULL text value; an optional description explains what the setting means. There is no returned result set.

[Source](../../modules/1070%20Procedures/z.usp_SetSetting.sql)

```sql
create or alter procedure z.usp_SetSetting
(
	@Name nvarchar(200),
	@Value nvarchar(max),
	@Description nvarchar(1000) = null
)
```

Inserts or updates one setting. Rejects null, empty and spaces-only names, and
null values. Names are stored as supplied, without trimming. A null description
preserves the existing description on update; an empty string replaces it with
an empty string. A new row may have a null description.

Concurrent writes to the same setting are serialized by the update. Within a
caller transaction, its locks remain until that transaction completes; normal
blocking and deadlocks are still possible. Errors can affect the caller's
transaction because the procedure uses `XACT_ABORT ON`. Grant EXECUTE to writers;
ordinary same-owner ownership chaining permits access through the helpers.

```sql
exec z.usp_SetSetting
	@Name = N'System.DefaultRetentionDays',
	@Value = N'30',
	@Description = N'Default retention period in days.';

select z.fn_GetSetting(N'System.DefaultRetentionDays');

-- Update the value and retain the existing description.
exec z.usp_SetSetting
	@Name = N'System.DefaultRetentionDays',
	@Value = N'60';
```
