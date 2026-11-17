/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/modules/1010%20Functions/z.fn_StandardizeFileName.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/functions.md#zfn_standardizefilename

Replaces filename-unsafe characters and spaces with underscores, preserving Unicode and case.
*/
create or alter function z.fn_StandardizeFileName(@FileName nvarchar(4000))
returns nvarchar(4000)
as
begin
	if @FileName is null return null;
	select	@FileName = translate(@FileName collate Latin1_General_100_BIN2,
			N'<>:"/\|?* ' + cast(0x0100020003000400050006000700080009000A000B000C000D000E000F0010001100120013001400150016001700180019001A001B001C001D001E001F00 as nvarchar(31)), replicate(N'_', 41));
	if right(@FileName, 1) = N'.' select @FileName = left(@FileName, len(@FileName) - 1) + N'_';
	return @FileName;
end
