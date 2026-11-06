# Database settings

[Object index](readme.md)

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

The guarded table script belongs to System's baseline. The current System source
has one version folder, so baseline remains eligible on existing installations.
Hash checking skips unchanged ordinary scripts; a new table script executes before
the helpers. Fresh installations always include baseline. Existing subsystems with
multiple version folders skip baseline. Re-running the table script preserves
existing rows; it does not reconcile an existing table's schema. See the
[deployment rules](../../../docs/deployment-process.md#source-and-plan).

## z.fn_GetSetting

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

The single MERGE uses HOLDLOCK to protect the matching key or missing-key range
through the statement's transaction. It participates in an existing caller
transaction, which retains those locks until completion. Normal blocking and
deadlock handling still apply. The procedure sets XACT_ABORT ON; errors can make
a caller transaction uncommittable or roll it back. It opens no explicit
transaction and returns no result set. Grant EXECUTE to writers; ordinary
same-owner ownership chaining permits access to the table through the helpers.

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
