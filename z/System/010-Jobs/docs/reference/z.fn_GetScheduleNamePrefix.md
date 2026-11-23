# z.fn_GetScheduleNamePrefix

[Jobs](../readme.md) | [Source](../../modules/1010%20Functions/z.fn_GetScheduleNamePrefix.sql)

Returns the beginning of every Schema Z schedule name for the current database. Jobs uses this prefix to keep one database's schedules separate from another's and to limit orphan cleanup to the owning database.

There are no parameters. The `nvarchar(300)` result has the form `Schema z: [DatabaseName]: `. Unicode and punctuation are preserved, and closing brackets in the database name are escaped. The prefix itself is not shortened, even if it leaves too little room for a valid Agent schedule name.

z.fn_ToSQLAgentSchedule adds the native schedule fields and rejects the complete definition if any final name exceeds 128 UTF-16 code units. Orphan cleanup uses a literal binary comparison against this prefix. A database rename produces a new prefix; it does not rename existing Agent schedules.

No writes, transaction or dependencies on other custom objects.
