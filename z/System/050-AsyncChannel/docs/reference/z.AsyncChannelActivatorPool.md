# z.AsyncChannelActivatorPool

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1020%20Tables/z.AsyncChannelActivatorPool.sql)

## Purpose and behavior

Stores shared processing capacity and acquisition timeout settings. Multiple channels can reference one pool through `ActivatorPoolID`. Installation creates the table when absent and seeds no pools.

## Columns and defaults

| Column | Type | Required | Default and meaning |
| --- | --- | --- | --- |
| ActivatorPoolID | int | Yes | Explicit identifier; clustered primary key |
| Name | nvarchar(128) | Yes | Unique nonclustered pool name |
| Description | nvarchar(256) | No | Pool description |
| MaxConcurrency | tinyint | Yes | Explicit capacity; zero bypasses limiting |
| TimeoutSeconds | int | Yes | `300`; `-1` waits indefinitely, otherwise at least one second |
| IsActive | bit | Yes | `1`; inactive pools bypass limiting |
| RowVersion | rowversion | Yes | SQL Server-generated change token |

## Coordination and limits

[Pool acquisition](z.usp_AsyncChannelActivatorPoolAcquire.md) maps this row to the Session-owned System semaphore `ADPool/<ActivatorPoolID>`. Capacity limits processing sessions across the pool, independently of each channel's automatic queue-reader setting. Timeout is converted to milliseconds and capped at 2147483647 for finite waits.

There is no foreign key from the channel registry. A channel with no matching pool row also bypasses limiting. Editing capacity or activity does not evict current holders or retroactively apply new settings to an acquisition already underway. Coordinate configuration changes with active work.

Use [z.v_AsyncChannelActivatorPool](z.v_AsyncChannelActivatorPool.md) for configuration, channel count and advisory lock-state counts. See [architecture](../architecture.md) for repeat-acquisition ownership and cancellation limits.
