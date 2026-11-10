# z.AsyncChannel

[AsyncChannel](../readme.md) | [Reference](readme.md) | [Source](../../baseline/1020%20Tables/z.AsyncChannel.sql)

## Purpose and behavior

Stores channel registrations and the settings used by sending, generation and processing. Installation creates the table when absent and seeds no registrations. Registering a row does not generate its channel objects; use `z.usp_AsyncChannelDeploy` separately.

## Columns and defaults

| Column | Type | Required | Default and meaning |
| --- | --- | --- | --- |
| AsyncChannelID | int | Yes | Explicit channel identifier; clustered primary key |
| Name | nvarchar(128) | Yes | Unique name used in generated object names |
| Description | nvarchar(256) | No | Application description |
| ProcessingProcedure | nvarchar(128) | Yes | Application processor name; its schema determines generated object placement |
| ActivationType | varchar(20) | Yes | `Auto`; permits `Auto` or `Manual` |
| Readers | tinyint | Yes | `1`; at least one automatic queue reader |
| MaxRowsPerMessage | int | No | NULL means no configured row chunk limit; otherwise positive |
| MaxMessagesPerReceive | int | Yes | `1500`; positive maximum native messages per receive |
| MaxIdleDurationSeconds | int | Yes | `60`; nonnegative idle limit; zero uses a nonwaiting receive |
| MaxExecutionSeconds | int | Yes | `0`; zero disables the configured execution limit |
| IsActive | bit | Yes | `1`; sending helpers check channel activity |
| DebugMode | bit | Yes | `0`; enables generated processing diagnostics |
| ActivatorPoolID | int | Yes | Configured pool identifier; no foreign key requires a matching pool |
| RowVersion | rowversion | Yes | SQL Server-generated change token |

## Constraints and operational limits

Name starts with an ASCII letter and contains only letters, digits and underscores according to the database collation's pattern rules. It has a unique nonclustered constraint. The declaration also enforces the activation choices and positive/nonnegative numeric settings shown above.

A missing, inactive or zero-capacity pool imposes no processing limit. `Readers` controls automatic readers per channel, whereas pool capacity is shared across channels. Idle and execution limits are cooperative checks and do not interrupt a processor or semaphore wait.

Changes to configuration do not automatically regenerate existing object definitions or activation bindings. Each generated activator invocation reads MaxIdleDurationSeconds, MaxExecutionSeconds, MaxMessagesPerReceive and DebugMode at entry and keeps those values for that invocation. Pool acquisition resolves the channel's current ActivatorPoolID and current pool settings on each acquisition; sending helpers also read current channel settings. Inspect [z.v_AsyncChannel](z.v_AsyncChannel.md) and [z.v_AsyncChannelScripts](z.v_AsyncChannelScripts.md), and review [architecture](../architecture.md) before regeneration.
