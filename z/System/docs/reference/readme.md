# System object index

[Guide](../readme.md)

Choose a topic below to find the object for your task. Reference pages explain its purpose, how to call it, and the result or changes to expect; source links provide implementation details.

| Reference | Contents |
| --- | --- |
| [Functions](functions.md) | Every shared function: strings, dates, IDs, environment and SQL generation |
| [Catalog and baseline](catalog.md) | Sequence and every catalog view |
| [Schema copy](schema-copy.md) | Generation, execution, permissions and copy limits |
| [Coordination](coordination.md) | Semaphores and trigger flags |
| [Settings](settings.md) | Database-local key/value table, getter and setter |
| [Procedures](procedures.md) | Every shared procedure: exact declarations, sources and behavior |
| [Remove blocker](remove-blocker.md) | z.usp_RemoveBlocker and generated global temporary worker/job |
| [Installer reference](../../../docs/reference.md) | Deployment tables and procedure interfaces |

Required parameters have no default in the declaration. Function callers generally use `default` in an argument position to select a declared default. Supporting constraints/indexes are documented with their table and source.
