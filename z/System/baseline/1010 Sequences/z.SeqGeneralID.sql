/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/baseline/1010%20Sequences/z.SeqGeneralID.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/docs/reference/catalog.md#zseqgeneralid

Creates a cached cycling integer sequence supplying the low 28 bits of datetime-encoded
identifiers.
*/
if object_id('z.SeqGeneralID') is null
begin
	create sequence z.SeqGeneralID as int start with 1 increment by 1 minvalue  1 maxvalue 268435455  cycle cache 268435455
end