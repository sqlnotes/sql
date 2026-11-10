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
	declare @Character int = 1;
	select @FileName = translate(@FileName, N'<>:"/\|?* ', N'__________');
	while @Character <= 31
	begin
		select @FileName = replace(@FileName collate Latin1_General_100_BIN2, nchar(@Character), N'_'), @Character += 1;
	end
	if right(@FileName, 1) = N'.' select @FileName = left(@FileName, len(@FileName) - 1) + N'_';
	return @FileName;
end
