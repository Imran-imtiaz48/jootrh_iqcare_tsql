exec pr_OpenDecryptedSession
go

UPDATE Patient SET NationalId = ENCRYPTBYKEY(KEY_GUID('Key_CTC'),'9999999') WHERE id IN (
	SELECT Id FROM gcPatientView WHERE len(NationalId) < 7  --AND id = 10408
)
