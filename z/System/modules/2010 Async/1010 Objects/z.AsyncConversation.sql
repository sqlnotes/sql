--drop table z.AsyncConversation
if object_id('z.AsyncConversation') is null
begin
	create table z.AsyncConversation
	(
		InitiatorSessionID smallint not null,
		ConfigurationID int not null,
		PayloadHandle uniqueidentifier not null,
		PayloadConversation uniqueidentifier not null,
		constraint PK_z_AsyncConversation primary key(InitiatorSessionID, ConfigurationID),
		index IX_z_AsyncConversation_ConfigurationID (ConfigurationID),
		index IX_z_AsyncConversation_PayloadHandle unique (PayloadHandle),
		index IX_z_AsyncConversation_PayloadConversation unique (PayloadConversation)
	)
end
