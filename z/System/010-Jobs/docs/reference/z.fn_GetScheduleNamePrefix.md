# z.fn_GetScheduleNamePrefix

[Jobs](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_GetScheduleNamePrefix.sql)

No arguments. Returns nvarchar(300): `Schema z: ` followed by the quoted current database name and `: `. Closing brackets in the name are doubled; Unicode and punctuation are preserved. The full prefix is returned without truncation, even if it is too long to form a valid Agent schedule name.

z.fn_ToSQLAgentSchedule adds the native schedule fields and rejects the complete definition if any final name exceeds 128 UTF-16 code units. Orphan cleanup uses a literal binary comparison against this prefix. A database rename produces a new prefix; it does not rename existing Agent schedules.

No writes, transaction or dependencies on other custom objects.
