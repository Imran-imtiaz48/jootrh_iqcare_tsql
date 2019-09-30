--Data Quality query
exec pr_OpenDecryptedSession
go

/*
WITH patient_master_cte AS (
	SELECT * FROM gcPatientView p WHERE PatientStatus = 'ACTIVE' 
),
*/

WITH current_in_care_cte AS (
SELECT A.ptn_pk,
  --A.PersonId,
  A.id,
  c.IdentifierValue AS PatientId,
  --c.IdentifierOld AS OldId,
  CONVERT(varchar(50),DecryptByKey(b.FirstName)) AS 'FirstName',
  CONVERT(varchar(50),DecryptByKey(b.LastName)) AS 'LastName',
  f.Name AS PatientType,
  m.Name AS Sex,
  DateDiff(yy, A.DateOfBirth, A.RegistrationDate) AS RegistrationAge,
  DateDiff(yy, A.DateOfBirth, GetDate()) AS currentAge,
  A.RegistrationDate,
  Z.VisitDate,
  P.NextAppointmentDate
  --w.Regimen,
  --w.DispensedDate
FROM IQCare_CPAD.dbo.Patient A
  INNER JOIN (SELECT IQCare_CPAD.dbo.PatientMasterVisit.PatientId,
    Max(IQCare_CPAD.dbo.PatientMasterVisit.CreateDate) AS VisitDate
  FROM IQCare_CPAD.dbo.PatientMasterVisit
  GROUP BY IQCare_CPAD.dbo.PatientMasterVisit.PatientId) Z ON A.id = Z.PatientId
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
WHERE P.NextAppointmentDate IS NOT NULL AND A.DeleteFlag = 0 AND 
  A.Id NOT IN (SELECT IQCare_CPAD.dbo.PatientCareending.PatientId
  FROM IQCare_CPAD.dbo.PatientCareending) AND 
  A.Id NOT IN (SELECT        Patient.Id AS PatientId
	FROM dtl_PatientCareEnded INNER JOIN
    Patient ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk)
),

missing_dob_cte AS (
	SELECT * FROM mst_Patient WHERE DOB IS NULL or ISDATE(DOB) = 0
),

last_vl_cte AS (
	SELECT * FROM (
		SELECT        patientId,CAST(SampleDate AS DATE) as VlDate, ResultValues  as VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
											FROM            dbo.PatientLabTracker
											WHERE        (Results = 'Complete')
											AND         (LabTestId = 3)  --	AND SampleDate <= '2018-05-15'
	) r WHERE r.RowNum = 1

),

missing_lastvl_cte AS (
	SELECT c.*, 'MISSING LAST VL' as DataIssue FROM current_in_care_cte c  
		LEFT JOIN last_vl_cte lv ON c.Id = lv.patientId	
	WHERE lv.VLResults IS NULL
),

missing_lastvl_date_cte AS (
	SELECT c.*, lv.VLResults, lv.VlDate FROM current_in_care_cte c  
		LEFT JOIN last_vl_cte lv ON c.Id = lv.patientId	
	WHERE lv.VLResults IS NOT NULL AND lv.VLResults IS NULL 
),

patient_enrolment_cte as (
	SELECT PatientId, min(EnrollmentDate) as EnrollmentDate FROM (
		SELECT        PatientId, EnrollmentDate
		FROM            PatientEnrollment AS pe
		UNION
		SELECT        PatientId, EnrollmentDate
		FROM            PatientHivDiagnosis AS phd
	) PatientEnrollments
	GROUP BY patientId
),

missing_patient_enrolments_cte AS (
	SELECT c.* FROM current_in_care_cte c  
		LEFT JOIN patient_enrolment_cte e ON c.Id = e.PatientId	
	WHERE e.PatientId IS NULL 
),

patient_artintitiation_dates_cte as (
	SELECT PatientId, min(ARTDate) as ARTInitiationDate FROM (
		SELECT        PatientId, ARTInitiationDate as ARTDate
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN (SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder WHERE (Prophylaxis = 0)) AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL
	) PatientARTdates
	GROUP BY patientId
),

missing_initialart_cte AS (
	SELECT c.*, 'MISSING ART START DATE' as DataIssue FROM current_in_care_cte c  
		LEFT JOIN patient_artintitiation_dates_cte e ON c.Id = e.PatientId	
	WHERE e.PatientId IS NULL 
),

discrepant_initialart_cte AS (
	SELECT c.*, 'DESCRIPANT ART START DATE' as DataIssue FROM current_in_care_cte c  
		LEFT JOIN patient_artintitiation_dates_cte e ON c.Id = e.PatientId	
	WHERE DATEDIFF(MONTH,c.RegistrationDate, e.ARTInitiationDate) > 6 AND c.PatientType <> 'Transfer-In'

),

regimen_cte as (
	SELECT * FROM (
		SELECT PatientId, Regimen,RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY V.DispensedByDate DESC) AS rowNum FROM [dbo].[PatientTreatmentTrackerView] V
		WHERE v.RegimenId <> 0 AND [TreatmentStatus] IN ('Start Treatment','DrugSwitches','Continue current treatment','Drug Substitutio','Drug Interruptions')
	) r WHERE r.rowNum = 1

),

missing_regimen_cte AS (
	SELECT c.*, 'MISSING REGIMEN' as DataIssue FROM current_in_care_cte c  
		LEFT JOIN regimen_cte e ON c.Id = e.PatientId	
	WHERE e.PatientId IS NULL 
),

patient_baseline_assessment_cte AS (
	SELECT CD4Count as BaselineCD4,WHOStagename as BaselineWHOStage, PatientId FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By CreateDate Asc) as rowNum,PatientId,CreateDate,CD4Count,WHOStage,
	(SELECT Name FROM dbo.LookupItem AS LookupItem_1 WHERE (Id = dbo.PatientBaselineAssessment.WHOStage)) as WHOStagename FROM PatientBaselineAssessment WHERE WHOStage IS NOT NULL
	) pba  WHERE rowNum = 1
),

missing_baseline_assessment_cte AS (
	SELECT c.*, 'MISSING BASELINE INFO' as DataIssue FROM current_in_care_cte c  
		LEFT JOIN patient_baseline_assessment_cte e ON c.Id = e.PatientId	
	WHERE e.PatientId IS NULL 
),

invalid_ccc_number as (
	SELECT *, 'INVALID CCC Number' as DataIssue FROM current_in_care_cte WHERE LEN(PatientId) < 10
	OR PatientId = '%ti%'
	--AND RegistrationDate > '2017-04-30'
),

tbscreening_cte AS (
	SELECT        Id, PatientId, PatientMasterVisitId, CreatedBy as [Provider], CreateDate as VisitDate
	FROM            PatientScreening
	WHERE        (ScreeningTypeId = 4 OR ScreeningTypeId = 12)
),

visits_cte AS (
	SELECT        Id as PatientMasterVisitId, PatientId, CreatedBy as UserId
	FROM            PatientMasterVisit
	WHERE        (VisitDate IS NOT NULL)	
),

activevisits_cte AS (
	SELECT v.*, t.VisitDate, COALESCE(t.[Provider],v.UserId) as [Provider] FROM visits_cte v INNER JOIN tbscreening_cte t ON
	v.PatientMasterVisitId = t.PatientMasterVisitId
),

last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,v.PatientMasterVisitId, u.UserFirstName + ' ' + u.UserLastName as lastProvider FROM activevisits_cte v
	INNER JOIN mst_User u ON u.UserID = v.[Provider]
	) lastVisit WHERE rowNum = 1
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

linelist_cte as (

	SELECT * FROM missing_baseline_assessment_cte
	UNION ALL
	SELECT * FROM missing_regimen_cte
	UNION ALL
	SELECT * FROM missing_initialart_cte
	UNION ALL
	SELECT * FROM missing_lastvl_cte
	UNION ALL
	SELECT * FROM invalid_ccc_number
	UNION ALL
	SELECT * FROM discrepant_initialart_cte
),

linelist2_cte as (
	SELECT A.id,A.PatientId,A.FirstName,A.LastName,A.PatientType,Sex,RegistrationAge,CurrentAge,RegistrationDate,ARTInitiationDate,VisitDate,NextAppointmentDate,v.lastProvider,s.ServicePoint as EnrolmentServicePoint
	FROM linelist_cte A 
	LEFT JOIN last_visit_cte V ON A.Id = v.patientId
	INNER JOIN service_point_cte s ON A.ptn_pk = s.ptn_pk
	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = A.Id
	GROUP BY A.id,A.PatientId,FirstName,LastName,PatientType,Sex,RegistrationAge,ARTInitiationDate,CurrentAge,RegistrationDate,VisitDate,NextAppointmentDate ,v.lastProvider,s.ServicePoint
	--ORDER BY PatientId Desc
)

-- select A.*,art.ARTInitiationDate from linelist_cte A
--	LEFT JOIN patient_artintitiation_dates_cte art ON art.PatientId = A.Id

--SELECT *,DATEDIFF(mm,getdate(),RegistrationDate) FROM missing_lastvl_cte WHERE abs(DATEDIFF(mm,getdate(),RegistrationDate)) > 6
-- SELECT * FROM missing_baseline_assessment_cte order by RegistrationDate desc

SELECT *
, DataIssueDetails = STUFF((
          SELECT ',' + B.DataIssue
          FROM linelist_cte B
          WHERE A.ID = B.ID
          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
 FROM  linelist2_cte A
/*
 SELECT * FROM PatientScreening WHERE ScreeningTypeId = 4 and PatientId = 134
 */
-- select * from nutrition