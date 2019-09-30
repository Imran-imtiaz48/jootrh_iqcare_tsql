exec pr_OpenDecryptedSession
go
with enrollment_CTE AS (
	SELECT        UPPER(CONCAT(FirstName, ' ',LastName)) as PatientName, EnrollmentNumber, PersonId, Id AS PatientId, [EnrollmentDate ] AS EnrollmentDate
	FROM            gcPatientView
),
art_initiation_CTE AS (
	SELECT a.patientId, min(a.ARTInitiationDate) as ARTInitiationDate FROM (
		SELECT H.PatientId, H.ARTInitiationDate FROM PatientHivDiagnosis H  WHERE H.ARTInitiationDate IS NOT NULL
		UNION
		SELECT O.PatientId, MIN(O.DispensedByDate) as ARTInitiationDate FROM dbo.ord_PatientPharmacyOrder O WHERE ptn_pharmacy_pk IN (SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder WHERE (Prophylaxis = 0)) 
		AND PatientId IS NOT NULL AND O.DispensedByDate IS NOT NULL GROUP BY O.PatientId
	) a GROUP BY a.PatientId
)

SELECT *, DATEDIFF(dd,EnrollmentDate,ARTInitiationDate) as TimeTakenToInitiate FROM enrollment_CTE e 
INNER JOIN art_initiation_CTE a ON
e.PatientId = a.PatientId