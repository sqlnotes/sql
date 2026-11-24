# Trace

Captures selected SQL Server activity and stores the received events in database tables. Choose the events, columns and filters you need, then collect them on a dedicated connection. Optional stored-procedure callbacks can react to each recorded event.

Trace uses SQL Server Trace directly. Each definition has its own trace, receiving table and callbacks; it continues capturing until stopped or closed. [Monitoring](../../020-Monitoring/docs/readme.md) supplies ready-made diagnostic presets built on this framework.

- [Architecture](architecture.md)
- [Usage](usage.md)
- [Troubleshooting](troubleshooting.md)
- [Object reference](reference/readme.md)
- [Monitoring presets](../../020-Monitoring/docs/readme.md)
- [System](../../docs/readme.md)

Collection is best effort: bounded native rowset reads have known event-loss limits. Successful completion and zero reported drops do not prove complete reception.

When replacing the former shared-collector installation, the installer closes its registered native generations and removes the old trace definitions and configuration automatically. Receiving tables and captured diagnostic data are preserved. Run this transition during maintenance with collector calls quiesced; it does not provide a concurrent online upgrade. Native cleanup failures still stop installation so unresolved resources can be retried safely.
