if object_id('z.SeqGeneralID') is null
begin
	create sequence z.SeqGeneralID as int start with 1 increment by 1 minvalue  1 maxvalue 268435455  cycle cache 268435455
end