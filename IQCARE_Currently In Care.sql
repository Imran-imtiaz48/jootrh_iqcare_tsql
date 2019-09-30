Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw=='
GO
WITH all_visits_cte AS (

	SELECT PatientId,VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v WHERE VisitDate IS NOT NULL AND CAST(VisitDate AS DATE) < (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId)
	UNION ALL
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
	UNION All
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientVitals
	UNION ALL
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientAppointment
),

last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = '2018-03-31'
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

second_last_vl_cte AS (
	SELECT        p.ptn_pk as ptn_pk, labTrac.Id, labTrac.patientId, labTrac.ResultValues as secondlastVL, labTrac.FacilityId, labTrac.SampleDate as secondlastVLDate
	FROM            (SELECT        ROW_NUMBER() OVER(PARTITION BY patientId ORDER BY SampleDate DESC) as row_num, patientId, ResultValues,FacilityId, SampleDate, Id
							  FROM            dbo.PatientLabTracker WHERE PatientLabTracker.Results = 'Complete'
							  AND         (LabTestId = 3)) labTrac
	INNER JOIN patient p on p.Id = labTrac.patientId
	WHERE        (labTrac.row_num = 2)

),

current_in_care_cte AS (
SELECT A.ptn_pk,
  A.Id as PID,
  A.PersonId,
  c.IdentifierValue AS PatientID,
  c.IdentifierOld AS PatientIDOld,
  CONVERT(varchar(50),DecryptByKey(b.FirstName)) AS 'FirstName',
  CONVERT(varchar(50),DecryptByKey(b.LastName)) AS 'LastName',
  f.Name AS PatientType,
  m.Name AS Sex,
  DateDiff(yy, A.DateOfBirth, A.RegistrationDate) AS RegistrationAge,
  DateDiff(yy, A.DateOfBirth, GetDate()) AS currentAge,
  A.RegistrationDate,
  Z.lastVisitDate as VisitDate,
  P.NextAppointmentDate,
  T.Regimen,
  T.DispensedDate as ARTStartDate
FROM IQCare_CPAD.dbo.Patient A
INNER JOIN last_visit_cte Z ON A.Id = Z.PatientId
LEFT OUTER JOIN (
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
    WHERE M.RowNum = 1) AS T ON T.patientId = A.Id
  INNER JOIN IQCare_CPAD.dbo.LookupItem f ON A.PatientType = f.Id
  INNER JOIN ( SELECT * FROM (SELECT *,ROW_NUMBER() OVER (PARTITION BY patientId ORDER BY patientId DESC) as rowNum FROM PatientIdentifier /*WHERE patientId = 2917*/) pid WHERE pid.rowNum = 1) c ON A.Id = c.PatientId
  INNER JOIN IQCare_CPAD.dbo.Person b ON A.PersonId = b.Id
  INNER JOIN IQCare_CPAD.dbo.LookupItem m ON b.Sex = m.Id
  LEFT JOIN (SELECT Y.ptn_pk AS PatientPK,
		Max(X.AppointmentDate) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
		INNER JOIN IQCare_CPAD.dbo.Patient Y ON X.PatientId = Y.Id
	  GROUP BY Y.ptn_pk) P ON A.ptn_pk = P.PatientPK
WHERE /*P.NextAppointmentDate IS NOT NULL AND*/ A.DeleteFlag = 0  AND 
  A.Id NOT IN 
  (
	  SELECT IQCare_CPAD.dbo.PatientCareending.PatientId
	  FROM IQCare_CPAD.dbo.PatientCareending WHERE DeleteFlag = 0 AND ExitDate < = '2018-03-31'
 ) 
  /*AND 
  A.Id NOT IN (SELECT        Patient.Id AS PatientId
	FROM dtl_PatientCareEnded INNER JOIN
    Patient ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk)*/
),

mch_cte AS (
	SELECT 
		p.Ptn_Pk, 'MCH' as ServicePoint , p.MCHID as id
	FROM mst_Patient p  WHERE p.MCHID IS NOT NULL
),

hts_cte AS (
	SELECT 
		p.Ptn_Pk, 'HTS' as ServicePoint , p.HTSID as id
	FROM mst_Patient p  WHERE p.HTSID IS NOT NULL
),

gbvrc_cte AS (
	SELECT 
		p.Ptn_Pk, 'GBV' as ServicePoint , p.GBVRCID as id
	FROM mst_Patient p  WHERE p.GBVRCID IS NOT NULL
),

mat_cte AS (
	SELECT 
		p.Ptn_Pk, 'MAT' as ServicePoint , p.MATID as id
	FROM mst_Patient p  WHERE p.MATID IS NOT NULL
),

tb_cte AS (
	SELECT 
		p.Ptn_Pk, 'TB' as ServicePoint , p.TBID as id
	FROM mst_Patient p  WHERE p.TBID IS NOT NULL
),

ccc_cte AS (
	SELECT 
		p.Ptn_Pk, 'CCC' as ServicePoint, p.PatientEnrollmentID as id 
	FROM mst_Patient p  WHERE p.MCHID IS NULL AND p.GBVRCID IS NULL AND p.MATID IS NULL
),

service_point_cte AS (
		SELECT * FROM mch_cte 
		UNION SELECT * FROM hts_cte 
		UNION SELECT * FROM gbvrc_cte 
		UNION SELECT * FROM mat_cte 
		UNION SELECT * FROM tb_cte 
		UNION SELECT * FROM ccc_cte 
),
entry_point_cte AS (
	SELECT * FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY s.PatientId ORDER BY s.CreateDate DESC) as rowNUm,  s.PatientId, s.EntryPointId, l.ItemName AS EntryPoint, p.ptn_pk
		FROM            ServiceEntryPoint AS s INNER JOIN
								 LookupItemView AS l ON s.EntryPointId = l.ItemId INNER JOIN
								 Patient AS p ON s.PatientId = p.Id
	) ep WHERE rowNum =1
)

-- SELECT * FROM service_point_cte;

/*SELECT  c.ptn_pk,count(*) FROM current_in_care_cte c
INNER JOIN service_point_cte s ON s.ptn_pk = c.ptn_pk
LEFT OUTER JOIN last_vl_cte v ON
c.ptn_pk = v.ptn_pk 
Group BY c.ptn_pk 
HAVING COUNT(*) > 1
*/
-- select count(distinct patientId) from current_in_care_cte --(9842)
select count(*) from current_in_care_cte WHERE year(NextAppointmentDate) = 2018 -- AND NextAppointmentDate <= '2018-03-31' --(5829)
-- select * from current_in_care_cte WHERE PatientId = '07827-05'
-- select PatientId, count(*) from current_in_care_cte group by PatientId HAVING count(*) >1

-- SELECT count(distinct patientId) from last_visit_cte WHERE lastVisitDate <= '2018-03-31' --(6930)
-- select count(*) from current_in_care_cte

-- select c.* from current_in_care_cte c INNER JOIN last_visit_cte v ON c.PID = v.PatientId
select * from last_visit_cte WHERE PatientId not in (select PId FROM current_in_care_cte)

SELECT /*v.patientId,*/ c.*,se.EntryPoint,v.LastVL,v.lastVLDate, sl.secondlastVL, sl.secondlastVLDate/*, s.servicePoint*/ FROM current_in_care_cte c
--LEFT JOIN service_point_cte s ON s.ptn_pk = c.ptn_pk
LEFT JOIN entry_point_cte se ON se.ptn_pk = c.ptn_pk
LEFT OUTER JOIN last_vl_cte v ON c.ptn_pk = v.ptn_pk 
LEFT OUTER JOIN second_last_vl_cte sl ON sl.ptn_pk = v.ptn_pk
LEFT JOIN last_visit_cte lv ON lv.PatientId = c.PID
-- WHERE
-- VisitDate < '2018-03-31'
 --AND 
-- RegistrationDate <= '2018-01-31'
-- AND c.PatientID LIKE '%26240%'
--AND VisitDate > NextAppointmentDate
--c.ptn_pk IN (5583,10176)
-- s.ServicePoint = 'CCC'
-- c.ptn_pk = 2917
-- ORDER BY RegistrationDate DESC
--ORDER BY VisitDate ASC
CLOSE SYMMETRIC KEY Key_CTC;
GO
