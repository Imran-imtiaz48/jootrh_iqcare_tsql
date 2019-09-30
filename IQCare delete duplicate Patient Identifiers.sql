DELETE FROM PatientIdentifier WHERE Id IN (
	SELECT Id FROM (
		SELECT *,ROW_NUMBER() OVER(PARTITION BY PatientId,identifierTypeId ORDER BY CreateDate DESC) as rowNum FROM PatientIdentifier --WHERE PatientId = 10514
	) d WHERE d.rowNum >1
)