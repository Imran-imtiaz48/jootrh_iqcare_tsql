DECLARE @startDate as DATE = '20190101';
DECLARE @endDate as DATE = '20190131';

Open symmetric key Key_CTC 
decryption by password='ttwbvXWpqb5WOLfLrBgisw==';


-- select distinct 	tp.PatientId,tp.Gender,tp.PatientType,tp.RegistrationAtCCC,tp.PatientName,tp.DOB,tp.AgeCurrent,tp.ContactName,tp.ContactRelation,tp.ContactPhoneNumber from  [IQTools_KeHMIS].dbo.tmp_PatientMaster tp where tp.PatientPK = 11453

WITH all_Patients_cte as (
SELECT     g.Id as PatientID, g.PersonId, pc.MobileNumber as PhoneNumber,tp.ContactPhoneNumber,tp.ContactRelation,tp.ContactName, EnrollmentNumber, UPPER(CONCAT(FirstName, ' ', MiddleName, ' ', LastName)) AS PatientName, CASE WHEN Sex = 52 THEN 'F' ELSE 'M' END AS Sex, '' AS RegistrationAge, DATEDIFF(YY, DateOfBirth, @endDate) AS currentAge, '' AS EnrolledAt, CAST([EnrollmentDate ] AS Date) as [EnrollmentDate] , '' as ARTStartDate, '' AS FirstVisitDate,'' AS LastVisitDate, P.NextAppointmentDate, PatientStatus, CAST(ExitDate AS DATE) as ExitDate, DateOfBirth, PatientType, MaritalStatus, EducationLevel, ExitReason--, CareEndingNotes
FROM            gcPatientView2 g
--INNER JOIN PatientContact
LEFT JOIN (
	SELECT PersonId, MobileNumber, AlternativeNumber,EmailAddress FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY PersonId ORDER BY CreateDate) as RowNum, PC.PersonId, PC.MobileNumber, PC.AlternativeNumber,PC.EmailAddress FROM PersonContactView PC
	) pc1 WHERE pc1.RowNum = 1
) PC ON PC.PersonId = g.PersonId	
LEFT JOIN  (SELECT DISTINCT PatientPk,ContactPhoneNumber,ContactRelation,PhoneNumber,COntactName, p.MaritalStatus, p.EducationLevel, CONCAT(p.Landmark,'-', p.NearestHealthCentre) as Address FROM [IQTools_KeHMIS].[dbo].[tmp_PatientMaster] p) tp ON tp.PatientPK = g.ptn_pk
LEFT JOIN (
		SELECT PatientId,
		CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
	  FROM IQCare_CPAD.dbo.PatientAppointment X
	  GROUP BY X.PatientId
 ) P ON g.Id = p.patientId 
 ),

patient_artintitiation_dates_cte AS (
	SELECT PatientId, CAST(min(ARTDate) AS DATE) as ARTInitiationDate FROM (
		SELECT        PatientId, ARTInitiationDate as ARTDate
		FROM            PatientHivDiagnosis WHERE	ARTInitiationDate IS NOT NULL AND ARTInitiationDate >= 2000
		UNION
		SELECT p.id as PatientId, DispensedByDate as ARTDate 
		FROM dbo.ord_PatientPharmacyOrder o INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
		WHERE ptn_pharmacy_pk IN 
			(SELECT ptn_pharmacy_pk FROM dbo.dtl_PatientPharmacyOrder o INNER JOIN mst_drug d ON d.drug_pk=o.drug_pk
				WHERE (Prophylaxis = 0 AND d.Abbreviation IS NOT NULL) 				 
				 AND( d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND d.DrugName NOT  LIKE '%Septrin%'  AND d.DrugName  NOT  LIKE '%Dapson%'  )
				 )
		AND o.DeleteFlag = 0 AND o.DispensedByDate IS NOT NULL AND YEAR(o.DispensedByDate) >= 2000 
	) PatientARTdates
	GROUP BY patientId
),
last_vl_cte AS (
	SELECT * FROM  (
			SELECT   ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY lastVlDate DESC) as RowNum, patientId,lastVlDate,lastVLResult
							FROM (
									SELECT        patientId, SampleDate AS lastVlDate, ResultValues AS lastVLResult
									FROM            PatientLabTracker
									WHERE        (Results = 'Complete') AND (SampleDate < @startDate) AND (LabTestId = 3)
									UNION
									SELECT        p.Id AS PatientId, tvl.LastVLDate, tvl.LastVLResult
									FROM            IQTools_KeHMIS.dbo.IQC_LastVL AS tvl INNER JOIN
															 Patient AS p ON p.ptn_pk = tvl.PatientPK
									WHERE        (tvl.LastVLDate < @startDate)
							) all_vl
				) vl
	WHERE vl.RowNum = 1

),
routine_vl_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, @startDate) AS 'Months Since Last VL', 'Routine VL' as Reason FROM last_vl_cte WHERE (DateDiff(m, LastVLDate, @startDate) = 12)
),
high_vl_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, @startDate) AS 'Months Since Last VL', 'High VL' as Reason FROM last_vl_cte WHERE lastVLResult > 1000 AND DateDiff(m, LastVLDate, @startDate) = 3
),
initial_vl_cte AS (
	SELECT PatientId,ARTInitiationDate, 'FirstVL' as 'Reason' FROM patient_artintitiation_dates_cte WHERE (DateDiff(m, ARTInitiationDate, @startDate) = 6)
),
routine_vl_mch_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, @startDate) AS 'Months Since Last VL', 'Routine VL' as Reason FROM last_vl_cte WHERE (DateDiff(m, LastVLDate, @startDate) = 6)
),
high_vl_mch_cte AS (
	SELECT PatientId,lastVlDate,lastVLResult,DateDiff(m, LastVLDate, @startDate) AS 'Months Since Last VL', 'High VL' as Reason FROM last_vl_cte WHERE lastVLResult > 1000 AND DateDiff(m, LastVLDate, @startDate) = 3
),
initial_vl_mch_cte AS (
	SELECT PatientId,ARTInitiationDate, 'FirstVL' as 'Reason' FROM patient_artintitiation_dates_cte WHERE (DateDiff(m, ARTInitiationDate, @startDate) = 3)
),
vl_cte AS (
	SELECT PatientId, Reason, lastVlDate, lastVLResult,[Months Since Last VL] FROM routine_vl_cte
	UNION
	SELECT PatientId, Reason, lastVlDate, lastVLResult, [Months Since Last VL] FROM high_vl_cte
	UNION
	SELECT PatientId, Reason, null as lastVlDate, null as lastVLResult, 0 as [Months Since Last VL]  FROM initial_vl_cte
),

vl_cte_mch AS (
	SELECT PatientId, Reason, lastVlDate, lastVLResult,[Months Since Last VL] FROM routine_vl_mch_cte
	UNION
	SELECT PatientId, Reason, lastVlDate, lastVLResult, [Months Since Last VL] FROM high_vl_cte
	UNION
	SELECT PatientId, Reason, null as lastVlDate, null as lastVLResult, 0 as [Months Since Last VL]  FROM initial_vl_mch_cte

),

vls_taken_cte AS (
	SELECT * FROM  (
			SELECT   ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY lastVlDate DESC) as RowNum, patientId,lastVlDate,lastVLResult
							FROM (
									SELECT        patientId, SampleDate AS lastVlDate, ResultValues AS lastVLResult
									FROM            PatientLabTracker
									WHERE        (SampleDate >= @startDate AND SampleDate <= @endDate) AND (LabTestId = 3)
									/*UNION
									SELECT        p.Id AS PatientId, tvl.LastVLDate, tvl.LastVLResult
									FROM            IQTools_KeHMIS.dbo.IQC_LastVL AS tvl INNER JOIN
															 Patient AS p ON p.ptn_pk = tvl.PatientPK
									WHERE        (tvl.LastVLDate >= @startDate AND tvl.LastVLDate <= @endDate)*/
							) all_vl
				) vl
	WHERE vl.RowNum = 1 
),
tca_cte AS (
		SELECT PatientId,
		Max(X.AppointmentDate) AS NextAppointmentDate
	  FROM PatientAppointment X WHERE X.CreateDate <= @endDate
	  GROUP BY X.PatientId
),

providers_cte AS (
		SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
		INNER JOIN mst_User u ON u.UserID = lg.UserID
		WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
),

all_visits_cte AS (
	SELECT * FROM (
		SELECT * FROM (
			SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, v.CreatedBy as lastProvider FROM PatientMasterVisit v 
			INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
			WHERE VisitDate IS NOT NULL AND VisitDate < (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
			UNION
			SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
			UNION
			SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
			WHERE VisitDate < @endDate -- AND VisitDate >= @startDate

		) v INNER JOIN providers_cte p ON p.UserID = v.lastProvider
	) visits WHERE VisitDate < = @endDate
),


last_visit_cte_wo_provider AS (
	SELECT visitDate as lastVisitDate, PatientId, PatientMasterVisitId,LastProvider,Visitdate, ProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, CAST(VisitDate AS DATE) AS Visitdate, ProviderName, PatientMasterVisitId, lastProvider FROM all_visits_cte v
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
),

last_visit_cte AS (
	SELECT lastVisitDate, PatientId, PatientMasterVisitId, lastProvider,LastProviderName FROM (
		SELECT ROW_NUMBER() OVER (Partition by PatientId Order By visitDate Desc) as rowNum, PatientId, LastVisitdate, PatientMasterVisitId, lastProvider, ProviderName as LastProviderName FROM last_visit_cte_wo_provider v
--		INNER JOIN providers_cte p ON p.UserID = v.lastProvider
	) lastVisit WHERE rowNum = 1  -- AND VisitDate < = @endDate
)




--select * from PatientLabTracker WHERE PatientId = 3074 ORDER BY SampleDate DESC

--select * from IQTools_KeHMIS.dbo.IQC_LastVL WHERE PatientPK = 1212

--select * from all_patients_cte a WHERE a.id = 11403
/*
-- MCH
SELECT  a.PatientID AS ID,
	a.EnrollmentNumber AS CCCNumber,REPLACE(REPLACE(a.EnrollmentNumber,'13939-',''),'/','-') as Matchingid,a.Sex,CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientTyp,CAST(a.EnrollmentDate AS Date) as RegistrationDate,a.PatientName,CAST(a.DateOfBirth AS DATE) as DateOfBirth,a.currentAge as Age,a.PhoneNumber,a.ContactName,a.ContactRelation,a.ContactPhoneNumber,art.ARTInitiationDate as ARTStartDate,v.Reason as VLReason, v.[Months Since Last VL],CAST(v.lastVlDate AS DATE) AS lastVlDate, v.lastVLResult, 
	vlt.lastVlDate, vlt.lastVLResult,
	tca.NextAppointmentDate, lv.lastVisitDate, lv.LastProviderName
FROM all_patients_cte a 
INNER JOIN vl_cte_mch v ON a.PatientID = v.patientId
LEFT JOIN vls_taken_cte vlt ON a.PatientID = vlt.patientId
LEFT JOIN patient_artintitiation_dates_cte art On a.PatientID = art.PatientId
LEFT JOIN tca_cte tca ON a.PatientID = tca.PatientId
LEFT JOIN last_visit_cte lv ON lv.patientId = a.PatientID
--WHERE vlt.patientId IS NULL and a.Id in (select id from xx) -- and a.PatientID = '13939-26232'
WHERE lv.LastProviderName IN ('Onywera Susan', 'Nancy Odhiambo')
ORDER BY vlt.lastVlDate desc
*/


SELECT  a.PatientID AS ID,
	a.EnrollmentNumber AS CCCNumber,REPLACE(REPLACE(a.EnrollmentNumber,'13939-',''),'/','-') as Matchingid,a.Sex,CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientTyp,CAST(a.EnrollmentDate AS Date) as RegistrationDate,a.PatientName,CAST(a.DateOfBirth AS DATE) as DateOfBirth,a.currentAge as Age,a.PhoneNumber,a.ContactName,a.ContactRelation,a.ContactPhoneNumber,art.ARTInitiationDate as ARTStartDate,v.Reason as VLReason, v.[Months Since Last VL],CAST(v.lastVlDate AS DATE) AS lastVlDate, v.lastVLResult, 
	vlt.lastVlDate, vlt.lastVLResult,
	tca.NextAppointmentDate, lv.lastVisitDate, lv.LastProviderName
FROM all_patients_cte a 
INNER JOIN vl_cte v ON a.PatientID = v.patientId
LEFT JOIN vls_taken_cte vlt ON a.PatientID = vlt.patientId
LEFT JOIN patient_artintitiation_dates_cte art On a.PatientID = art.PatientId
LEFT JOIN tca_cte tca ON a.PatientID = tca.PatientId
LEFT JOIN last_visit_cte lv ON lv.patientId = a.PatientID
--WHERE vlt.patientId IS NULL and a.Id in (select id from xx) -- and a.PatientID = '13939-26232'
ORDER BY vlt.lastVlDate desc


-- pending VL
SELECT  a.PatientID AS ID,
	a.EnrollmentNumber AS CCCNumber,REPLACE(REPLACE(a.EnrollmentNumber,'13939-',''),'/','-') as Matchingid,a.Sex,CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientTyp,CAST(a.EnrollmentDate AS Date) as RegistrationDate,a.PatientName,CAST(a.DateOfBirth AS DATE) as DateOfBirth,a.currentAge as Age,a.PhoneNumber,a.ContactName,a.ContactRelation,a.ContactPhoneNumber,art.ARTInitiationDate as ARTStartDate,v.Reason as VLReason, v.[Months Since Last VL],CAST(v.lastVlDate AS DATE) AS lastVlDate, v.lastVLResult, 
	vlt.lastVlDate, vlt.lastVLResult,
	tca.NextAppointmentDate, lv.lastVisitDate, lv.LastProviderName
FROM all_patients_cte a 
INNER JOIN vl_cte v ON a.PatientID = v.patientId
LEFT JOIN vls_taken_cte vlt ON a.PatientID = vlt.patientId
LEFT JOIN patient_artintitiation_dates_cte art On a.PatientID = art.PatientId
LEFT JOIN tca_cte tca ON a.PatientID = tca.PatientId
LEFT JOIN last_visit_cte lv ON lv.patientId = a.PatientID
--WHERE vlt.patientId IS NULL and a.Id in (select id from xx) -- and a.PatientID = '13939-26232'
ORDER BY vlt.lastVlDate desc


/*
select * from last_vl_cte WHERE PatientId IN (
	select id from gcPatientView WHERE EnrollmentNumber = '02868-04'
)
 */
--select p.PatientID,r.* from routine_vl_cte r INNER JOIN all_patients_cte p ON P.id = r.patientId

-- select * from high_vl_cte
--select * from initial_vl_cte

/*
SELECT p.PatientId,p.Gender,p.DOB, lv.lastVlDate, lv.lastVLResult, a.ARTInitiationDate as ARTStartDate, DateDiff(m, ARTInitiationDate, @startDate) AS 'Months Since ART Start', DateDiff(m, LastVLDate, @startDate) AS 'Months Since Last VL' FROM all_patients_cte p 
LEFT JOIN patient_artintitiation_dates_cte a ON p.id = a.PatientId
LEFT JOIN last_vl_cte lv ON p.Id = lv.patientId
INNER JOIN vl_cte v ON p.id = v.patientId 
*/

/*

SELECT tmp_PatientMaster.PatientID,
  tmp_PatientMaster.Gender,
  tmp_PatientMaster.DOB,
  IQC_LastVL.LastVLDate,
  IQC_LastVL.LastVLResult,
  tmp_ARTPatients.LastVisit,
  tmp_ARTPatients.StartARTDate,
  tmp_ARTPatients.AgeLastVisit,
  DateDiff(m, IQC_LastVL.LastVLDate, @startDate) AS 'Months Since Last VL',
  CAST(IQC_LastVL.LastVLResult AS float) AS LastVL
FROM [IQTools_KeHMIS].dbo.tmp_PatientMaster
  LEFT JOIN (SELECT *
  FROM (SELECT CAST(Row_Number() OVER (PARTITION BY p.PatientPK ORDER BY
      p.OrderedbyDate DESC) AS Varchar) AS RowID,
      p.PatientPK,
      CAST(Floor(p.TestResult) AS int) LastVLResult,
      CASE WHEN p.TestName = 'Viral Load' THEN p.TestResult
        WHEN p.TestName = 'ViralLoad Undetectable' THEN 'Undetectable' ELSE NULL
      END AS LastVL,
      p.OrderedbyDate LastVLDate
    FROM [IQTools_KeHMIS].dbo.tmp_Labs p
    WHERE p.OrderedbyDate <= @startDate AND p.TestName LIKE '%Viral%') AS LastVLTbl
  WHERE LastVLTbl.RowID = 1) AS IQC_LastVL ON tmp_PatientMaster.PatientPK =
    IQC_LastVL.PatientPK
  LEFT JOIN [IQTools_KeHMIS].dbo.tmp_ARTPatients ON tmp_PatientMaster.PatientPK =
    tmp_ARTPatients.PatientPK
WHERE 
(
	(DateDiff(m, IQC_LastVL.LastVLDate, @startDate) = 12)
	-- OR (IQC_LastVL.LastVLResult > 1000 AND DateDiff(m, IQC_LastVL.LastVLDate, @startDate) = 3)
    --OR (DateDiff(m, tmp_ARTPatients.StartARTDate, @startDate) = 6)
 )
AND
 tmp_PatientMaster.PatientPk = 2734
*/