
UPDATE c
SET c.CreatedBy = v.CreatedBy
FROM PatientCategorization c
INNER JOIN (SELECT DISTINCT e.PatientMasterVisitId, e.CreatedBy FROM PatientEncounter e INNER JOIN lnk_UserGroup g ON e.CreatedBy = g.UserID WHERE g.GroupID = 5) v  ON c.PatientMasterVisitId = v.PatientMasterVisitId
WHERE c.CreatedBy = 0 AND CAST(c.CreateDate AS DATE) =  CAST(DATEADD(D,0,GETDATE()) AS DATE)
AND c.Categorization = 1

/*
SELECT * FROM PatientCategorization c
INNER JOIN (SELECT DISTINCT e.PatientMasterVisitId, e.CreatedBy FROM PatientEncounter e INNER JOIN lnk_UserGroup g ON e.CreatedBy = g.UserID WHERE g.GroupID = 5) v  ON c.PatientMasterVisitId = v.PatientMasterVisitId
WHERE c.CreatedBy = 0 AND CAST(c.CreateDate AS DATE) = CAST(DATEADD(D,0,GETDATE()) AS DATE)
AND c.Categorization = 1
*/


/*
select * from gcPatientView WHERE EnrollmentNumber LIKE '%07366%'

select * from gcPatientView WHERE EnrollmentNumber LIKE '%19290%'

select * from gcPatientView WHERE EnrollmentNumber LIKE '%15258%'

select * from PatientCategorization WHERE PatientId IN (4937/*4295,5427*/) order by id desc
*/

UPDATE c
SET c.CreatedBy = v.CreatedBy
FROM PatientAppointment c
INNER JOIN (SELECT DISTINCT e.PatientMasterVisitId, e.CreatedBy FROM PatientEncounter e INNER JOIN lnk_UserGroup g ON e.CreatedBy = g.UserID WHERE g.GroupID = 5) v  ON c.PatientMasterVisitId = v.PatientMasterVisitId
WHERE c.CreatedBy = 0 AND CAST(c.CreateDate AS DATE) =  CAST(DATEADD(D,0,GETDATE()) AS DATE)
AND c.DifferentiatedCareId = 237
-- AND c.PatientId = 4937

/*
SELECT *
FROM PatientAppointment c
INNER JOIN (SELECT DISTINCT e.PatientMasterVisitId, e.CreatedBy FROM PatientEncounter e INNER JOIN lnk_UserGroup g ON e.CreatedBy = g.UserID WHERE g.GroupID = 5) v  ON c.PatientMasterVisitId = v.PatientMasterVisitId
WHERE c.CreatedBy = 0 AND CAST(c.CreateDate AS DATE) =  CAST(DATEADD(D,0,GETDATE()) AS DATE)
AND c.DifferentiatedCareId = 237 
--AND c.PatientId = 4937
*/
select * from PatientAppointment WHERE PatientId IN (/*4937,4295,*/5427) order by id desc


select * from LookupItem  WHERE id = 237


select * from mst_User WHERE UserID = 14
