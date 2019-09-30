WITH patient_master_cte as (
SELECT     
	DISTINCT   Id as PatientId, ptn_pk, EnrollmentNumber, FirstName, LastName, 
	CASE WHEN Sex = 51 THEN 'MALE' 
		ELSE 'FEMALE'
	END as Sex, 
	PatientStatus, DateOfBirth, PatientType, MobileNumber, DATEDIFF(yy, DateOfBirth, GETDATE()) as age
FROM            gcPatientView AS pv
--WHERE
--[EnrollmentDate ] Between '2017-01-01' AND '2017-12-31'
--        (PatientStatus = 'ACTIVE')
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

regimen_cte as (
	SELECT * FROM (
		SELECT PatientId, Regimen,RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY V.DispensedByDate DESC) AS rowNum FROM [dbo].[PatientTreatmentTrackerView] V
		WHERE v.RegimenId <> 0 AND [TreatmentStatus] IN ('Start Treatment','DrugSwitches','Continue current treatment','Drug Substitutio','Drug Interruptions')
	) r WHERE r.rowNum = 1

)


SELECT p.PatientId,p.ptn_pk, p.EnrollmentNumber, FirstName, LastName, p.age,p.MobileNumber, e.EnrollmentDate, p.PatientStatus 
, r.regimen, pai.ARTInitiationDate 
FROM patient_master_cte p LEFT JOIN patient_enrolment_cte e ON p.patientId = e.PatientId
LEFT JOIN regimen_cte r on r.PatientId = p.PatientId
LEFT JOIN patient_artintitiation_dates_cte as pai ON pai.PatientId = p.PatientId
