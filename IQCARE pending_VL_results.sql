

--exec pr_OpenDecryptedSession
--go

DECLARE @endDate AS Date = GETDATE();

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, @endDate) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate ] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, PatientStatus, CAST(ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, MaritalStatus, EducationLevel, ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
--INNER JOIN PatientContact
LEFT JOIN (
	SELECT PersonId, MobileNumber, AlternativeNumber,EmailAddress FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PersonId ORDER BY CreateDate) as RowNum, PC.PersonId, PC.MobileNumber, PC.AlternativeNumber,PC.EmailAddress FROM PersonContactView PC
	) pc1 WHERE pc1.RowNum = 1
) PC ON PC.PersonId = g.PersonId	
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN (
		SELECT PatientId,
		CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
-- WHERE g.PatientStatus = 'Death'
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

last_vl_cte AS (
	SELECT * FROM (
		SELECT        patientId,SampleDate as lastVLDate, ResultValues  as lastVL,ROW_NUMBER() OVER (Partition By PatientId ORDER BY SampleDate DESC) as RowNum
		FROM            dbo.PatientLabTracker
		WHERE        (Results = 'Complete')
		AND         (LabTestId = 3) 
	) vlr WHERE RowNum = 1 
),

pending_vl_cte AS (
	SELECT * FROM PatientLabTracker WHERE LabTestId =3 AND Results = 'Pending'
	 AND SAmpleDate >= DATEADD(MM,-3,GETDATE()) AND SampleDate<=GETDATE()
)


-- All patients pending Viral Load

SELECT p.PatientId, p.EnrollmentNumber, p.PatientName, p.currentAge,p.PhoneNumber, p.EnrollmentDate, p.PatientStatus 
, vl.lastVL,CAST (vl.lastVLDate AS DATE) as LastVlDate, CAST(pv.SampleDate AS DATE) as SampleOrderDate, pv.Reasons as VLReason
FROM all_Patients_cte p
LEFT JOIN last_vl_cte vl on vl.PatientId = p.PatientId
INNER JOIN pending_vl_cte pv on pv.PatientId = p.PatientId
WHERE
 pv.Id IS NOT NULL
 ORDER BY pv.SampleDate DESC
