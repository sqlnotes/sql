# Security usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select LoginName, LoginType, SQL
from z.fn_BuildQueryCopyLogin(N'ExampleLogin', N'ExampleLoginCopy');

select Ordinal, Type, SQL
from z.fn_BuildQueryCopyUserPermission(N'ExampleUser', N'ExampleUserCopy')
order by Ordinal;
```

Functions return script text without executing it. Review generated text before use. Login output can contain password hashes and SIDs: handle it as security material. Permission generators contain known limitations; they are not complete security-migration tools.
