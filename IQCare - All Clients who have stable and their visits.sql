SELECT g.Id, g.EnrollmentNumber AS [CCC Number], pc.CategorizationDate AS [Categorization/VisitDate], /*pa.AppointmentDate,*/ pc.StabilityStatus , pa.DCModel, pa.PatientMasterVisitId
FROM (
		SELECT p.id, mp.PatientEnrollmentID as EnrollmentNUmber FROM mst_Patient mp INNER JOIN patient p ON mp.Ptn_Pk = p.ptn_pk WHERE p.DeleteFlag = 0 AND mp.DeleteFlag = 0
	) g 
INNER JOIN
	(
		SELECT  DISTINCT v.id AS PatientMasterVisitId, v.PatientId, CAST(c.DateAssessed AS DATE) as CategorizationDate, CASE WHEN c.Categorization = 1 THEN 'Stable' WHEN c.Categorization = 2 THEN 'Unstable' END StabilityStatus 
		FROM PatientMasterVisit v 
		--INNER JOIN PatientEncounter e ON v.id = e.PatientMasterVisitId AND e.EncounterTypeId =  1482
		INNER JOIN PatientCategorization c ON c.PatientId = v.PatientId AND c.PatientMasterVisitId = v.id
	) pc ON pc.PatientId = g.Id
INNER JOIN 
	(
		SELECT DISTINCT a.PatientMasterVisitId, a.PatientId, /*CAST (a.AppointmentDate AS DATE) AS AppointmentDate,*/ li.Name AS DCModel 
		FROM PatientAppointment a  INNER JOIN LookupItem li ON a.DifferentiatedCareId = li.Id
	) pa ON pa.PatientId = g.Id AND pa.PatientMasterVisitId = pc.PatientMasterVisitId
INNER JOIN (
		SELECT DISTINCT a.PatientId 
		FROM PatientMasterVisit v 
		INNER JOIN PatientEncounter e ON v.id = e.PatientMasterVisitId AND e.EncounterTypeId =  1482
		INNER JOIN PatientCategorization c ON c.PatientId = v.PatientId AND c.PatientMasterVisitId = v.id
		INNER JOIN PatientAppointment a ON a.PatientId = v.PatientId AND a.PatientMasterVisitId = v.Id
		INNER JOIN LookupItem li ON a.DifferentiatedCareId = li.Id AND li.Name <> 'Standard Care'
) s ON s.PatientId = g.Id
INNER JOIN (
		SELECT fdc.PatientId, fdc.CategorizationDate FROM (
			SELECT a.PatientId, CAST(c.DateAssessed AS DATE) as CategorizationDate, ROW_NUMBER() OVER (PARTITION BY a.PatientId ORDER BY c.DateAssessed) AS rown
			FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON v.id = e.PatientMasterVisitId AND e.EncounterTypeId =  1482
			INNER JOIN PatientCategorization c ON c.PatientId = v.PatientId AND c.PatientMasterVisitId = v.id
			INNER JOIN PatientAppointment a ON a.PatientId = v.PatientId AND a.PatientMasterVisitId = v.Id
			INNER JOIN LookupItem li ON a.DifferentiatedCareId = li.Id AND li.Name <> 'Standard Care'
		) fdc WHERE fdc.rown = 1
) fdc ON fdc.PatientId = g.Id AND pc.CategorizationDate >= fdc.CategorizationDate
 WHERE g.EnrollmentNumber = '13939-12300'
--	select * from LookupItem WHERE id = 1482

-- select * from PatientAppointment WHERE PatientId = 49


