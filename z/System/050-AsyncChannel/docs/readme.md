# AsyncChannel

[System documentation](../../docs/readme.md)

AsyncChannel sends structured data through database-local Service Broker conversations. It generates channel-specific serialization, enqueue and activation objects from an interface view, and invokes a processing procedure with typed message batches. Activator pools limit concurrent processing across channels. Conversation timers can wake processing without a data payload.

- [Usage](usage.md)
- [Architecture and limitations](architecture.md)
- [Framework object reference](reference/readme.md)

This module owns the generic framework and shared messaging interfaces. Applications own their channel registrations, interface views and processing procedures. Installation creates no application channels or pool registrations and sends no messages.

For a complete construction example, see [the demo creator](../modules/1070%20Examples/z.usp_CreateDemoAsyncChannel.sql). Usage comments precede its procedure definition. Calling it explicitly creates the example channel; [usage](usage.md) explains the steps.

Requires SQL Server 2019 or later, database Service Broker enabled for message delivery, and the shared System foundation. Installation does not enable Broker or change database settings. Administrative deployment and channel generation require the corresponding database DDL permissions; activation executes as queue owner. Configure channels only through trusted administrative code.
