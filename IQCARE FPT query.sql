Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw=='
GO

WITH index_patient_cte AS (
	SELECT p.PatientEnrollmentID as CCCNumber, tp.PatientName, tp.Gender,CAST(pa.RegistrationDate AS DATE) as RegistrationDate, tp.AgeCurrent, tp.AgeEnrollment,pa.id as PatientId
	FROM mst_Patient p 
	INNER JOIN Patient Pa ON Pa.ptn_pk = p.Ptn_Pk
	INNER JOIN [IQTools_KeHMIS].dbo.tmp_PatientMaster tp ON tp.PatientPK = p.Ptn_Pk
	WHERE 
		Pa.Active = 1 and Pa.DeleteFlag = 0 
--		AND len(RTRIM(p.MCHID)) > 0 
--		AND len(RTRIM(p.TBID)) > 0 

),
relationship_cte AS (
	SELECT pr.PatientId,pr.PersonId, (CAST(DECRYPTBYKEY(p.FirstName) AS varchar(50)) + ' ' + CAST(DECRYPTBYKEY(p.LastName) AS varchar(50))) as RelationsName,CASE WHEN p.Sex = 51 THEN 'MALE' ELSE 'FEMALE' END as RelationsSex ,CAST(P.DateOfBirth AS DATE) as RelationsDOB, ISNULL(DATEDIFF(YY,P.DateOfBirth,GETDATE()), CASE WHEN l1.DisplayName ='Spouse' THEN 18 WHEN l1.DisplayName ='Child' THEN 14 WHEN l1.DisplayName = 'Sibling' THEN 14 ELSE 18 END ) as RelationsAge,l1.DisplayName as Relationship, ISNULL(ISNULL(CAST(h.TestingDate AS DATE), BaselineDate), '') as RelationsTestingDate, (CASE WHEN h.TestingDate IS NULL THEN l2.DisplayName ELSE  l.DisplayName END) as RelationsTestingResult, pr.CreateDate, h.ReferredToCare FROM 
	PersonRelationship pr
	INNER JOIN Person p ON p.Id = pr.PersonId
	LEFT JOIN HIVTesting h ON h.PersonId = pr.PersonId
	INNER JOIN LookupItem l ON l.Id = h.TestingResult
	INNER JOIN LookupItem l1 ON l1.Id = pr.RelationshipTypeId
	INNER JOIN LookupItem l2 ON l2.Id = BaselineResult
),
art_cte AS (
	SELECT M.PatientId,
      M.Id,
      M.DispensedByDate as DispensedDate,
	  M.Regimen
    FROM (SELECT PatientTreatmentTrackerView.Id,
        PatientTreatmentTrackerView.PatientId,
        PatientTreatmentTrackerView.DispensedByDate,
		Regimen,
        Row_Number() OVER (PARTITION BY PatientTreatmentTrackerView.PatientId
        ORDER BY PatientTreatmentTrackerView.DispensedByDate DESC) RowNum
      FROM PatientTreatmentTrackerView WHERE DispensedByDate IS NOT NULL AND Regimen <> 'unknown'
	) AS M
    WHERE M.RowNum = 1

),
all_visits_cte AS (

	--SELECT PatientId,VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v WHERE Active = 1 AND VisitDate IS NOT NULL
	--UNION
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
	--UNION
	--SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientVitals
	--UNION
	--SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientAppointment
),

last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider, CONCAT(u.UserFirstName,' ',u.userLastName) as lastProviderName FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit left join mst_User u on u.UserID = lastProvider WHERE rowNum = 1
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1
),

last_vl_cte AS (
	SELECT distinct ptn_pk, PatientId, ResultValues as LastVL, SampleDate as lastVLDate FROM [dbo].[Laboratory_ViralLoad] vl
	INNER JOIN Patient p on vl.patientId = p.Id
),

without_relation_cte AS (
	SELECT i.* FROM index_patient_cte i LEFT JOIN relationship_cte r ON i.PatientId = r.PatientId
	WHERE r.PatientId IS NULL
)
SELECT p.*, CASE WHEN AgeCurrent < 15 THEN '0-14' WHEN AgeCurrent >=15 THEN '15+' END As IndexAgeGroup,vs.lastVisitDate, a.DispensedDate as ARTStartDate, vl.lastVLDate,vl.LastVL, r.RelationsName,r.RelationsSex,R.RelationsDOB,r.RelationsAge,r.Relationship,r.RelationsTestingResult,r.RelationsTestingDate , CASE WHEN RelationsAge < 15 THEN '0-14' WHEN RelationsAge >=15 THEN '15+' END As AgeGroup, CASE WHEN RelationsTestingResult = 'Tested Negetive' OR RelationsTestingResult = 'Tested Positive' THEN 1 ELSE 0 END AS EverTested, CASE WHEN RelationsTestingResult = 'Tested Positive' THEN 1 ELSE 0 END AS  Positive,ReferredToCare --,lastProvider,lastProviderName
FROM index_patient_cte p 
	LEFT JOIN relationship_cte r ON p.PatientId = r.PatientId 
	LEFT JOIN art_cte a ON a.PatientId = p.PatientId
	LEFT JOIN last_visit_cte vs ON vs.PatientId = p.PatientId
	LEFT JOIN last_vl_cte vl ON  vl.patientId = p.PatientId
WHERE 
--lastProvider IN (32,43,80,66,23,98,34,29,35,96,21,22,95,83,44,40,5,88,15,20,14,94,65,95,92,46,36,57) -- Everyone
--lastProvider IN (32,43,80,66,23,98,34,29,35,96,21,22,95,83,44,40,5,88,15,16,18,26,4) --PSC
-- lastProvider IN (20,14,94,65,95,56) --MCH
--lastProvider IN (92,46,36,57)--TB
--AND
-- Year(RelationsTestingDate) = 2018
--RegistrationDate <= '2018-06-30'
--AND
 AgeCurrent <=9
--AND Relationship NOT IN ('Sibling', 'Child')--  IN ('Mother', 'Father', 'Parent')
ORDER BY RelationsTestingDate DESC

-- select * from PersonRelationship

-- select * from HIVTesting WHERE Year(TestingDate) = 2018
 
/*
SELECT p.*,vs.lastVisitDate
--,vs.lastProvider,vs.lastProviderName
, a.DispensedDate as ARTStartDate, vl.lastVLDate,vl.LastVL 
FROM without_relation_cte p 
	INNER JOIN art_cte a ON a.PatientId = p.PatientId
	LEFT JOIN last_visit_cte vs ON vs.PatientId = p.PatientId
	LEFT JOIN last_vl_cte vl ON  vl.patientId = p.PatientId
WHERE 
lastProvider IN (32,43,80,66,23,98,34,29,35,96,21,22,95,83,44,40,5,88,15)
--lastProvider IN (20,14,94)
--INNER JOIN dtl_FamilyInfo f ON f.Ptn_pk = p.Ptn_Pk 
--WHERE MCHID IS NOT NULL 
--ORDER BY f.id DESC
*/
/*exec [dbo].[pr_OpenDecryptedSession]

exec [dbo].[pr_CloseDecryptedSession]

SELECT * FROM PersonRelationship order by CreateDate DESC

select * from LookupItem WHERE Id = 25

select * from gcPatientView WHERE EnrollmentNumber = 'TI/12345/14'

SELECT * FROM dtl_FamilyInfo 
--WHERE Ptn_Pk = 2001 
order by Id DESC

SELECT top 100 * FROM PersonRelationship ORDER BY CreateDate DESC
 
 */