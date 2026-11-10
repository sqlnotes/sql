/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/modules/1010%20Functions/z.fn_DecodeBackupFileName.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/020-Backup/docs/reference/z.fn_DecodeBackupFileName.md

Decodes recognized backup filename hints. Headers remain authoritative; unrecognized names return no rows.
*/
create or alter function z.fn_DecodeBackupFileName(@FileName nvarchar(4000))
returns table
as
return
(
	with e as
	(
		select ExtensionLength = case when right(@FileName, 5) collate Latin1_General_100_CI_AS = N'.diff' then 5 else 4 end,
			BackupType = convert(smallint, case when right(@FileName, 5) collate Latin1_General_100_CI_AS = N'.diff' then 5
				when right(@FileName, 4) collate Latin1_General_100_CI_AS = N'.bak' then 1
				when right(@FileName, 4) collate Latin1_General_100_CI_AS = N'.trn' then 2 end)
	), n as
	(
		select e.BackupType, Name = left(@FileName, case when len(@FileName) >= e.ExtensionLength then len(@FileName) - e.ExtensionLength else 0 end)
		from e where e.BackupType is not null
	), s as
	(
		select n.BackupType, Prefix = left(n.Name, case when len(n.Name) > v.StampLength then len(n.Name) - v.StampLength - 1 else 0 end),
			Stamp = right(n.Name, v.StampLength), v.FractionLength, v.SeparatorLength
		from n cross join (values (22, 6, 1), (23, 7, 1), (21, 6, 0), (22, 7, 0)) v(StampLength, FractionLength, SeparatorLength)
		where len(n.Name) > v.StampLength + 1 and substring(n.Name, len(n.Name) - v.StampLength, 1) = N'_'
	), d as
	(
		select s.Prefix, s.BackupType,
			BackupTime = try_convert(datetime2(7), substring(s.Stamp, 1, 4) + N'-' + substring(s.Stamp, 5, 2) + N'-' + substring(s.Stamp, 7, 2)
				+ N'T' + substring(s.Stamp, 10, 2) + N':' + substring(s.Stamp, 12, 2) + N':' + substring(s.Stamp, 14, 2)
				+ N'.' + substring(s.Stamp, 16 + s.SeparatorLength, s.FractionLength), 126)
		from s
		where substring(s.Stamp, 9, 1) = N'_' and (s.SeparatorLength = 0 or substring(s.Stamp, 16, 1) = N'_')
			and replace(s.Stamp, N'_', N'') collate Latin1_General_100_BIN2 not like N'%[^0-9]%'
			and datalength(replace(s.Stamp, N'_', N'')) = (14 + s.FractionLength) * 2
	), p as
	(
		select d.*, FirstDollar = charindex(N'$', d.Prefix),
			SecondDollar = iif(charindex(N'$', d.Prefix) > 0, charindex(N'$', d.Prefix, charindex(N'$', d.Prefix) + 1), 0)
		from d where d.BackupTime is not null
	), h as
	(
		select p.Prefix, p.BackupTime, p.BackupType,
			DatabaseName = case when p.FirstDollar = 0 then p.Prefix when p.SecondDollar = 0 then substring(p.Prefix, p.FirstDollar + 1, 4000)
				else substring(p.Prefix, p.SecondDollar + 1, 4000) end,
			SourceServerName = iif(p.FirstDollar = 0, null, left(p.Prefix, case when p.FirstDollar > 0 then p.FirstDollar - 1 else 0 end)),
			SourceInstanceName = case when p.FirstDollar = 0 then null when p.SecondDollar = 0 then null
				else substring(p.Prefix, p.FirstDollar + 1, case when p.SecondDollar > p.FirstDollar then p.SecondDollar - p.FirstDollar - 1 else 0 end) end
		from p
	)
	select h.Prefix, DatabaseName = convert(nvarchar(128), h.DatabaseName), h.BackupTime, h.BackupType,
		SourceServerName = convert(nvarchar(128), h.SourceServerName), SourceInstanceName = convert(nvarchar(128), h.SourceInstanceName)
	from h
	where datalength(h.DatabaseName) between 2 and 256
		and (h.SourceServerName is null or datalength(h.SourceServerName) between 2 and 256)
		and (h.SourceInstanceName is null or datalength(h.SourceInstanceName) between 2 and 256)
)
