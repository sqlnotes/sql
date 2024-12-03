declare @ID bigint, @Date datetime

select @ID = 268435455
if not exists(
				select x0.SeqID
				from (select z.fn_GetZSequenceID(@ID) SeqID) x0
					cross apply z.fn_DecodeZSequenceID(x0.SeqID) a
				where z.fn_ZSequenceIDToDatetime(x0.SeqID) = a.Date
					and a.Sequence = @ID
			)
begin
	raiserror('Z Sequence test1 failed', 16, 1)
end

select @ID = 0
if not exists(
				select x0.SeqID
				from (select z.fn_GetZSequenceID(@ID) SeqID) x0
					cross apply z.fn_DecodeZSequenceID(z.fn_GetZSequenceID(@ID)) a
				where z.fn_ZSequenceIDToDatetime(x0.SeqID) = a.Date
					and a.Sequence = @ID
			)
begin
	raiserror('Z Sequence test2 failed', 16, 1)
end

select @ID = next value for z.SeqGeneralID
if not exists(
				select x0.SeqID
				from (select z.fn_GetZSequenceID(@ID) SeqID) x0
					cross apply z.fn_DecodeZSequenceID(z.fn_GetZSequenceID(@ID)) a
				where z.fn_ZSequenceIDToDatetime(x0.SeqID) = a.Date
					and a.Sequence = @ID
			)
begin
	raiserror('Z Sequence test2 failed', 16, 1)
end


select @ID = next value for z.SeqGeneralID, @Date = getdate()
if not exists(
				select x0.SeqID, z.fn_ZSequenceIDToDatetime(x0.SeqID), a.*, @Date, @ID
				from (select z.fn_GenerateZSequenceID(@Date, @ID) SeqID) x0
					cross apply z.fn_DecodeZSequenceID(x0.SeqID) a
				where z.fn_ZSequenceIDToDatetime(x0.SeqID) = a.Date
					and a.Sequence = @ID
			)
begin
	raiserror('Z Sequence test3 failed', 16, 1)
end


