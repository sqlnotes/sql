/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1020%20Views/z.AsyncChannelMessage_Interface.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.AsyncChannelMessage_Interface.md

Shared insert interface sending each serialized fragment separately.
*/
create or alter view z.AsyncChannelMessage_Interface
as
	select top 0
		AsyncChannelID = cast(null as int),
		DataSequence = cast(null as bigint),
		Data = cast(null as nvarchar(max))
