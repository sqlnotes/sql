# Security usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Preview login and permission scripts

The first query scripts `ExampleLogin` under the new name `ExampleLoginCopy`. The second scripts `ExampleUser`'s database permissions and role memberships for `ExampleUserCopy`. Both return SQL text; neither creates a principal or grants a permission.

```sql
select LoginName, LoginType, SQL
from z.fn_BuildQueryCopyLogin(N'ExampleLogin', N'ExampleLoginCopy');

select Ordinal, Type, SQL
from z.fn_BuildQueryCopyUserPermission(N'ExampleUser', N'ExampleUserCopy')
order by Ordinal;
```

These queries return script text. Restrict access to generated SQL login definitions because they can include password hashes and SIDs. Review the [supported login attributes](reference/z.fn_BuildQueryCopyLogin.md) and [permission classes](reference/z.fn_BuildQueryCopyLoginPermission.md) before applying the scripts.
