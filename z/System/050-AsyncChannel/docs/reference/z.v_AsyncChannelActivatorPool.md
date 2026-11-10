# z.v_AsyncChannelActivatorPool

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../modules/1020%20Views/z.v_AsyncChannelActivatorPool.sql)

## Purpose and output

Returns one row per configured [activator pool](z.AsyncChannelActivatorPool.md), with advisory current-database semaphore counts.

| Columns | Meaning |
| --- | --- |
| ActivatorPoolID, Name, Description, MaxConcurrency, TimeoutSeconds, IsActive, RowVersion | Pool table values |
| ChannelCount | Count of all channel registrations referencing the pool, including inactive channels |
| SlotsInUse | Sum of distinct granted exclusive slot resources across sessions |
| SessionsWaiting | Count of sessions with a granted intent-exclusive main marker and no granted slot |

Missing lock aggregates become zero. ChannelCount is independent of whether channel infrastructure is generated or currently running.

## Lock interpretation and permissions

Reads `sys.dm_tran_locks` for APPLICATION resources in `db_id()` with SESSION ownership. Pool acquisitions hold IX on `ADPool/<ID>` and X on `<slot>-ADPool/<ID>`. A pool-ID digit-boundary match keeps numeric prefixes distinct. Slot counting uses distinct resource descriptions per session.

The caller needs the server DMV permission required by its SQL Server version, as well as access to the view and underlying metadata. Results are read-only and change as concurrent acquisitions/releases progress.

## Limitations

SessionsWaiting is inferred from a polling protocol, not a native blocked-request queue or a fairness guarantee. A session between marker acquisition and slot acquisition/release may appear waiting. Canceling a waiting acquisition can leave its marker until disconnect and inflate this count. A waiting activator has already received its batch and can hold an open transaction.

Raw semaphore resource-name collisions are outside the view's validation. The view does not repair locks or session context and does not report processing completion. See [architecture](../architecture.md) for shared capacity and ownership rules.
