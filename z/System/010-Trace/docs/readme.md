# Trace

The Trace subsystem creates and collects native SQL Server rowset traces. One definition corresponds to one physical trace, with its own events, native filters, receiving table and callbacks. Traces have no scheduled stop time and continue until explicitly stopped or closed.

- [Architecture](architecture.md)
- [Usage](usage.md)
- [Troubleshooting](troubleshooting.md)
- [Object reference](reference/readme.md)
- [Monitoring presets](../../020-Monitoring/docs/readme.md)
- [System](../../docs/readme.md)

Collection is best effort: bounded native rowset reads have known event-loss limits. Successful completion and zero reported drops do not prove complete reception.

When replacing the former shared-collector installation, the installer closes its registered native generations and removes the old trace definitions and configuration automatically. Receiving tables and captured diagnostic data are preserved. Run this transition during maintenance with collector calls quiesced; it does not provide a concurrent online upgrade. Native cleanup failures still stop installation so unresolved resources can be retried safely.
