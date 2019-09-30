EXEC pr_OpenDecryptedSession
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('vw_EncounterSearch'))
	DROP VIEW vw_EncounterSearch
GO
CREATE VIEW vw_EncounterSearch AS (
	SELECT DISTINCT 
		g.CCCNumber,
		UPPER(CONCAT(CAST (DECRYPTBYKEY(ps.FirstName) AS varchar(50)), ' ', CAST (DECRYPTBYKEY(ps.MidName) AS varchar(50)), ' ', CAST (DECRYPTBYKEY(ps.LastName) AS varchar(50)))) AS Patientname,
		FORMAT(VisitDate, 'd MMM, yyyy', 'en-GB') AS VisitDate,
		lastProviders = STUFF((
			SELECT DISTINCT ',' + pr.ProviderName
			FROM (SELECT CONCAT(u.UserFirstName, ' ', u.userLastName) as ProviderName, e.PatientMasterVisitId FROM PatientEncounter e INNER JOIN mst_User u ON e.CreatedBy = u.UserID ) pr
			WHERE pr.PatientMasterVisitId = v.id 
			FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, ''),
		e.PatientId
	FROM PatientMasterVisit v 
	INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id
	INNER JOIN (SELECT DISTINCT PatientId, IdentifierValue as CCCNumber FROM PatientIdentifier WHERE IdentifierTypeId = 1) g ON g.PatientId = v.PatientId			
	INNER JOIN Patient p ON p.Id = e.PatientId
	INNER JOIN Person ps ON p.PersonId = ps.id
	WHERE VisitDate IS NOT NULL 
)
GO