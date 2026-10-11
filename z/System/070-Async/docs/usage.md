# Async usage

[Subsystem](readme.md) | [Object reference](reference/readme.md)

## Examples

Execute against a database containing System and this subsystem. Examples describe current interfaces; environment permissions and data determine results.

```sql
select ConfigurationID, Name, InterfaceViewName, NumberOfInternalWorkers, IsActive, RowVersion
from z.AsyncConfiguration;

select InitiatorSessionID, ConfigurationID, PayloadHandle, PayloadConversation
from z.AsyncConversation;

select name, is_receive_enabled, is_activation_enabled
from sys.service_queues
where schema_id = schema_id('z') and name = 'AsyncSender';
```

This is infrastructure rather than a complete work-dispatch API. NumberOfInternalWorkers and IsActive are stored configuration values; this module does not implement their orchestration.
