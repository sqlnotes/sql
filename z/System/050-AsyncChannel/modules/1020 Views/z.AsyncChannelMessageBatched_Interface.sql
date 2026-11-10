/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1020%20Views/z.AsyncChannelMessageBatched_Interface.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelMessageBatched_Interface.md

Shared insert interface batching serialized fragments by channel.
*/
create or alter view z.AsyncChannelMessageBatched_Interface
as
	select top 0
		AsyncChannelID = cast(null as int),
		DataSequence = cast(null as bigint),
		Data = cast(null as nvarchar(max))
