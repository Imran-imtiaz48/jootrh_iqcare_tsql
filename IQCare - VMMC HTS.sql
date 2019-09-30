/*
select l.name,* from HtsEncounter h 
LEFT JOIN LookupItem l ON h.TestEntryPoint = l.Id
WHERE l.Name LIKE '%voluntary%'	


select * from LookupItem WHERE id = 18

select * from patient WHERE PersonId = 33583

exec pr_OpenDecryptedSession

select CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)), CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)) from mst_Patient WHERE Ptn_Pk = 12119

select * from HTS_EncountersView
*/
SELECT * FROM (
	SELECT CAST(pe.EncounterStartTime AS DATE) AS EncounterDate,UPPER(CONCAT(CAST(DECRYPTBYKEY(FirstName) AS VARCHAR(50)),' ', CAST(DECRYPTBYKEY(LastName) AS VARCHAR(50)))) as ClientName,pid.IdentifierValue AS HTSNo,h.EverTested,h.MonthsSinceLastTest, h1.FinalResult, h.EncounterRemarks,
	ROW_NUMBER() OVER(PARTITION BY pid.identifierValue ORDER BY h1.FinalResult DESC) AS rown
	FROM HtsEncounter h INNER JOIN LookupItem l ON l.Id = h.TestEntryPoint
	INNER JOIN PatientEncounter pe ON pe.Id = h.PatientEncounterID
	INNER JOIN patient p ON p.PersonId = h.PersonId
	INNER JOIN mst_Patient mp ON mp.Ptn_Pk =  p.ptn_pk
	INNER JOIN PatientIdentifier pid ON pid.PatientId = p.id
	INNER JOIN HTS_EncountersView h1 ON h1.EncounterId = h.Id
	WHERE 
	pe.EncounterStartTime BETWEEN '2019-04-01' AND '2019-05-31'
	AND
	ProviderId = 125
	AND pid.IdentifierTypeId = 8
) hts_vmmc WHERE rown = 1

-- select * from LookupItemView WHERE MasterName LIKE 'HTSEntryPoints'


