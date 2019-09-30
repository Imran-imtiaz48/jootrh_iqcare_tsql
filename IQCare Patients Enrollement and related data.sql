exec pr_OpenDecryptedSession
go
WITH all_visits_cte AS (

	SELECT PatientId,VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v WHERE Active = 1 AND VisitDate IS NOT NULL
	UNION
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening  
	UNION
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientVitals
	UNION
	SELECT PatientId,CreateDate as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientAppointment
),

last_visit_cte AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1
),

first_visit_cte AS (
	SELECT visitDate as firstVisitDate, PatientId, PatientMasterVisitId, lastProvider FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Asc) as rowNum,PatientId,VisitDate,PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1
),

patient_baseline_assessment_cte AS (
	SELECT CD4Count as BaselineCD4,WHOStagename as BaselineWHOStage, PatientId FROM (
	SELECT ROW_NUMBER() OVER (Partition by PatientId Order By CreateDate Asc) as rowNum,PatientId,CreateDate,CD4Count,WHOStage,
	(SELECT Name FROM dbo.LookupItem AS LookupItem_1 WHERE (Id = dbo.PatientBaselineAssessment.WHOStage)) as WHOStagename FROM PatientBaselineAssessment WHERE CD4Count IS NOT NULL OR WHOStage IS NOT NULL
	) pba  WHERE rowNum = 1
),

patient_master_cte as (
SELECT     
	DISTINCT   Id as PatientId, ptn_pk, EnrollmentNumber, FirstName, LastName,
	CASE WHEN Sex = 51 THEN 'M' 
		ELSE 'F'
	END as Sex, 
	PatientStatus, DateOfBirth, MobileNumber, DATEDIFF(yy, DateOfBirth, GETDATE()) as age, 
	tmp.PatientName, tmp.AgeEnrollment, tmp.AgeCurrent, tmp.RegistrationDate, tmp.PatientPK
FROM            gcPatientView AS pv INNER JOIN [IQTools_KeHMIS].dbo.tmp_PatientMaster tmp ON tmp.PatientPK = pv.ptn_pk
--WHERE
--[EnrollmentDate ] Between '2017-01-01' AND '2017-12-31'
--        (PatientStatus = 'ACTIVE')
),

patient_enrolment1_cte as (
SELECT        DISTINCT
	PatientId,
	EnrollmentWHOStageName, 
	EnrollmentDate as EnrollmentDateBL,
	(CASE 
		WHEN ARTInitiationDate IS NULL THEN ARTInitiationDateNew
		ELSE ARTInitiationDate
	 END) as ARTInitiationDate
FROM            
PatientBaselineView
),

patient_enrolment_cte as (
	SELECT PatientId, min(EnrollmentDate) as EnrollmentDate FROM (
		SELECT        PatientId, EnrollmentDate
		FROM            PatientEnrollment AS pe
		UNION
		SELECT        PatientId, EnrollmentDate
		FROM            PatientHivDiagnosis AS phd
	) PatientEnrollments
--	WHERE patientId = 2075
	GROUP BY patientId
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
	--WHERE	PatientId = 10079
	GROUP BY patientId
),

next_appointment_cte AS (
	SELECT AppointmentDate as nextAppointmentDate, PatientId FROM (
	SELECT ROW_NUMBER() OVER (Partition by a.PatientId Order By appointmentDate Desc) as rowNum,a.PatientId,a.AppointmentDate FROM PatientAppointment a WHERE a.ReasonId = 232 --Follow Up
	) nextAppointment WHERE rowNum = 1
),

last_vl_cte AS (
	SELECT distinct PatientId, ResultValues as LastVL, SampleDate as lastVLDate FROM [dbo].[Laboratory_ViralLoad]
),

first_vl_cte AS (
	SELECT distinct PatientId, ResultValues as firstVL, SampleDate as firstVLDate FROM [dbo].[Laboratory_first_ViralLoad]
),

last_cd4_cte AS (
	SELECT distinct PatientId, ResultValues as LastCd4, SampleDate as lastCd4Date FROM [dbo].[Laboratory_cd4]
),
pending_vl_cte AS (
	SELECT * FROM PatientLabTracker WHERE LabTestId =3 AND Results = 'Pending'
),

regimen_cte as (
	SELECT * FROM (
		SELECT PatientId, Regimen,RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY V.DispensedByDate DESC) AS rowNum FROM [dbo].[PatientTreatmentTrackerView] V
		WHERE v.RegimenId <> 0 AND [TreatmentStatus] IN ('Start Treatment','DrugSwitches','Continue current treatment','Drug Substitutio','Drug Interruptions')
	) r WHERE r.rowNum = 1

),

baseline_cte as (
	SELECT DISTINCT PatientId,HIVDiagnosisDate FROM PatientHIVDiagnosis
),

entry_point_cte AS (
	SELECT DISTINCT s.PatientId, s.EntryPointId, l.ItemName AS EntryPoint, p.ptn_pk
	FROM            ServiceEntryPoint AS s INNER JOIN
							 LookupItemView AS l ON s.EntryPointId = l.ItemId INNER JOIN
							 Patient AS p ON s.PatientId = p.Id
)
/*
-- 1. Patients enrolled between Oct-Dec 2017 with their baseline CD4 and WHO stage, include sex and age
SELECT p.PatientId, p.EnrollmentNumber, FirstName, LastName,p.DateOfBirth,p.age,p.sex,p.MobileNumber, e.EnrollmentDate
, (SELECT Name FROM dbo.LookupItem AS LookupItem_1 WHERE (Id = WHOStage)) as WHOStage
-- , pai.ARTInitiationDate 
,p.PatientStatus
--,pba.BaselineCD4,pba.baselineWHOStage 
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
--LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
LEFT JOIN patient_baseline_assessment_cte pba ON pba.PatientId = p.PatientId
LEFT JOIN last_visit_cte v on v.PatientId = p.[PatientId]
LEFT JOIN PatientWHOStage pw ON pw.PatientMasterVisitId = v.PatientMasterVisitId 
WHERE 
--p.patientId = 2075
e.[EnrollmentDate] Between '2017-10-31' AND '2017-12-31'
--AND p.PatientStatus = 'ACTIVE'
*/

/*
-- 2. All active patients with their diastolic and systolic BP at last visit, include sex, age, telephone number and TCA if available
SELECT p.PatientId, p.EnrollmentNumber, FirstName, LastName,p.DateOfBirth,p.age,p.sex,p.MobileNumber, e.EnrollmentDate
, vl.lastVL,vl.lastVLDate,cd.LastCd4, cd.lastCd4Date
-- , pai.ARTInitiationDate 
,p.PatientStatus,pv.BPSystolic,pv.BPDiastolic,v.lastVisitDate,a.nextAppointmentDate
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
LEFT JOIN last_visit_cte v on v.PatientId = p.[PatientId]
--LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
--LEFT JOIN patient_baseline_assessment_cte pba ON pba.PatientId = p.PatientId
LEFT JOIN PatientVitals pv ON pv.PatientMasterVisitId = v.PatientMasterVisitId  
LEFT JOIN next_appointment_cte a on a.PatientId = p.PatientId
LEFT JOIN last_vl_cte vl on vl.PatientId = p.PatientId
LEFT JOIN last_cd4_cte cd on cd.PatientId = p.PatientId
WHERE 
--p.patientId = 2075
--e.[EnrollmentDate] Between '2017-10-31' AND '2017-12-31'
-- AND 
p.PatientStatus = 'ACTIVE'
-- AND vl.ResultValues IS NULL
-- AND LastCd4 IS NOT NULL
*/
--Select * from all_visits_cte WHERE PatientId = 10564

-- All patients enrolled between Jan-Dec 2017 with their enrollment dates and date of ART initiation

SELECT p.PatientId, p.EnrollmentNumber, p.PatientName, p.AgeEnrollment, p.AgeCurrent,se.EntryPoint as EnrolledAt, p.RegistrationDate,pai.ARTInitiationDate as ARTStartDate,fvt.firstVisitDate,lvt.LastVisitDate, vl.lastVLDate, vl.lastVL
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
LEFT JOIN last_vl_cte vl on vl.PatientId = p.PatientId
LEFT JOIN first_visit_cte fvt on fvt.PatientId = p.PatientId
LEFT JOIN last_visit_cte lvt on lvt.PatientId = p.PatientId
LEFT JOIN [IQTools_KeHMIS].dbo.tmp_ARTPatients art ON art.PatientPK = p.ptn_pk
LEFT JOIN entry_point_cte se ON se.ptn_pk = p.ptn_pk
WHERE 
--p.patientId = 2075
e.[EnrollmentDate] Between '2018-01-01' AND '2018-03-31'



/*
-- All patients pending Viral Load

SELECT p.PatientId, p.EnrollmentNumber, FirstName, LastName, p.age,p.MobileNumber, e.EnrollmentDate, p.PatientStatus 
, vl.lastVL,vl.lastVLDate, pv.SampleDate, pv.Reasons
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
LEFT JOIN last_vl_cte vl on vl.PatientId = p.PatientId
LEFT JOIN pending_vl_cte pv on pv.PatientId = p.PatientId
WHERE
 pv.Id IS NOT NULL
 ORDER BY pv.SampleDate DESC
*/

/*
--Current Patient Regimen
SELECT p.PatientId, p.EnrollmentNumber, FirstName, LastName, p.age,p.MobileNumber, e.EnrollmentDate, p.PatientStatus 
, r.regimen, pai.ARTInitiationDate 
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
INNER JOIN Patient pt ON pt.Id = p.PatientId
LEFT JOIN regimen_cte r on r.PatientId = p.PatientId
LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
--WHERE regimen  is null and ARTInitiationDate is NOT NULL
*/

/*
--Patients tested hiv + between oct 2016 and june 2017
SELECT p.PatientId, p.EnrollmentNumber, p.age,p.Sex, e.EnrollmentDate, p.PatientStatus, b.HIVDiagnosisDate 
, pai.ARTInitiationDate, f.firstVL,f.firstVLDate,  l.lastVl, l.lastVLDate
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e
ON p.patientId = e.PatientId
INNER JOIN Patient pt ON pt.Id = p.PatientId
INNER JOIN baseline_cte b ON b.PatientId = p.PatientId
LEFT JOIN regimen_cte r on r.PatientId = p.PatientId
LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
LEFT JOIN last_vl_cte l on l.PatientId = p.PatientId
LEFT JOIN first_vl_cte f on f.PatientId = p.PatientId
WHERE b.HIVDiagnosisDate BETWEEN '2016-10-01' AND '2017-06-30'
*/
/*
SELECT * FROM ord_PatientPharmacyOrder WHERE PatientId = 1632
AND 
ptn_pharmacy_pk 
	IN 
		(SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder WHERE Prophylaxis = 0) 

	SELECT PatientId, min(ARTDate) as ARTInitiationDate FROM (
		SELECT        PatientId, ARTInitiationDate as ARTDate
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN (SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder WHERE (Prophylaxis = 0)) AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL
	) PatientARTdates
	WHERE	PatientId = 1632
	GROUP BY patientId
	*/