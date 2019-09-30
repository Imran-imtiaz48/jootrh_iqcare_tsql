DECLARE @startDate AS DATE; 
DECLARE @endDate AS DATE; 

set @startDate ='2019-03-25';
set @endDate ='2019-03-25';

WITH providers_cte AS (
	SELECT CONCAT(u.UserFirstName, ' ', u.UserLastName) AS ProviderName, lg.GroupID, u.UserID 
	FROM lnk_UserGroup lg
      INNER JOIN mst_User u ON u.UserID = lg.UserID WHERE (lg.GroupID = 5) OR (lg.GroupID = 7)),
  all_visits_cte AS (
	SELECT visits.PatientId, visits.VisitDate, visits.PatientMasterVisitId, visits.ProviderId, visits.ProviderName, visits.UserID, visits.GroupID,   visits.VisitBy
    FROM (
		SELECT v.PatientId, v.VisitDate, v.PatientMasterVisitId, v.ProviderId, p.ProviderName, p.GroupID, p.UserID, v.VisitBy, Row_Number() OVER (PARTITION BY v.PatientId, v.PatientMasterVisitId ORDER BY v.VisitDate DESC) AS RowNum
		  FROM (
			SELECT v.PatientId, CAST(v.VisitDate AS DATE) AS VisitDate, v.Id AS PatientMasterVisitId, v.CreatedBy AS ProviderId, v.VisitBy
			FROM PatientMasterVisit v
			INNER JOIN PatientEncounter p ON p.PatientMasterVisitId = v.Id
			WHERE v.VisitDate IS NOT NULL AND v.VisitDate <= (SELECT Max(a.AppointmentDate) FROM PatientAppointment a WHERE a.PatientId = v.PatientId) AND v.VisitDate = @endDate
			UNION
			SELECT PatientScreening.PatientId, CAST(PatientScreening.CreateDate AS DATE) AS VisitDate, PatientScreening.PatientMasterVisitId, PatientScreening.CreatedBy AS lastProvider, 108 AS VisitBy
			FROM PatientScreening WHERE CreateDate = @endDate
			) v
			INNER JOIN providers_cte p ON p.UserID = v.ProviderId
			WHERE v.VisitDate = @endDate
			) visits
		WHERE visits.RowNum = 1
	),
  last_visit_cte AS (
	SELECT lv.lastVisitDate,
      lv.PatientId,
      lv.PatientMasterVisitId,
      lv.lastProvider,
      lv.LastProviderName,
	  LastProviders = STUFF((
			SELECT DISTINCT ',' + pr.ProviderName
			FROM PatientEncounter e INNER JOIN providers_cte pr ON e.CreatedBy = pr.UserID
			WHERE e.PatientMasterVisitId = lv.PatientMasterVisitId
			FOR XML PATH('')), 1, 1, ''),
      lv.VisitBy
    FROM (
		SELECT 
			Row_Number() OVER (PARTITION BY v.PatientId ORDER BY v.Visitdate DESC) AS rowNum,
			v.PatientId,
			v.PatientMasterVisitId,
			v.VisitBy,
			v.ProviderName as LastProviderName,
			v.ProviderId as LastProvider,
			v.VisitDate as LastVisitDate
		FROM all_visits_cte v) lv
		WHERE lv.rowNum = 1),
  current_in_care_cte AS (
	SELECT A.ptn_pk,
      A.Id,
      A.PersonId,
      c.IdentifierValue AS PatientID,
      c.IdentifierOld AS PatientIDOld,
      b.PatientName,
      f.Name AS PatientType,
      b.Gender AS Sex,
	  ps.Sex as GenderId,
      b.AgeEnrollment AS RegistrationAge,
      b.AgeCurrent AS CurrentAge,
      A.RegistrationDate,
      P.NextAppointmentDate
    FROM Patient A
	  INNER JOIN IQCare_CPAD.dbo.Person ps ON ps.Id = A.PersonId
      INNER JOIN LookupItem f ON A.PatientType = f.Id
      INNER JOIN (SELECT *
		  FROM (SELECT *,
			  Row_Number() OVER (PARTITION BY PatientIdentifier.PatientId ORDER BY
			  PatientIdentifier.PatientId DESC) AS rowNum
			FROM PatientIdentifier) pid
		  WHERE pid.rowNum = 1) c ON A.Id = c.PatientId
      INNER JOIN (SELECT Upper(tpm.PatientName)
			AS PatientName,
			tpm.Gender,
			tpm.DOB,
			tpm.PatientPK,
			tpm.PatientID,
			tpm.AgeEnrollment,
			tpm.AgeCurrent
		  FROM IQTools_KeHMIS.dbo.tmp_PatientMaster tpm 
		  INNER JOIN patient pt ON pt.ptn_pk = tpm.PatientPK 
	  ) b ON A.ptn_pk = b.PatientPK
      LEFT JOIN (
		  SELECT Y.ptn_pk AS PatientPK,
			Max(X.AppointmentDate) AS NextAppointmentDate
		  FROM IQCare_CPAD.dbo.PatientAppointment X
			INNER JOIN IQCare_CPAD.dbo.Patient Y ON X.PatientId = Y.Id
		  GROUP BY Y.ptn_pk) P ON A.ptn_pk = P.PatientPK
		WHERE A.Id NOT IN (SELECT IQCare_CPAD.dbo.PatientCareending.PatientId
		  FROM IQCare_CPAD.dbo.PatientCareending) AND A.Id NOT IN (SELECT Patient.Id
			AS PatientId
		  FROM dtl_PatientCareEnded INNER JOIN Patient
			  ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk) AND
		  P.NextAppointmentDate IS NOT NULL AND A.DeleteFlag = 0
		),
  last_vl_cte AS (
	  SELECT *
		FROM (SELECT p.ptn_pk,
			ptr.patientId,
			CAST(ptr.SampleDate AS DATE) AS VlResultsDate,
			ptr.ResultValues AS VLResultsValue,
			Row_Number() OVER (PARTITION BY ptr.patientId ORDER BY ptr.SampleDate
			DESC) AS RowNum
		  FROM dbo.PatientLabTracker ptr
			INNER JOIN Patient p ON ptr.patientId = p.Id
		  WHERE ptr.Results = 'Complete' AND ptr.LabTestId = 3) r
		WHERE r.RowNum = 1),
  missing_lastvl_cte AS (SELECT c.PatientId,
      'MISSING LAST VL' AS DataIssue
    FROM current_in_care_cte c
      LEFT JOIN last_vl_cte lv ON c.ptn_pk = lv.ptn_pk
    WHERE lv.VLResultsValue IS NULL AND DateDiff(M, GetDate(),
      c.RegistrationDate) > 6),
  patient_enrolment_cte AS (SELECT PatientEnrollments.PatientId,
      Min(PatientEnrollments.EnrollmentDate) AS EnrollmentDate
    FROM (SELECT pe.PatientId,
        pe.EnrollmentDate
      FROM PatientEnrollment AS pe
      UNION
      SELECT phd.PatientId,
        phd.EnrollmentDate
      FROM PatientHivDiagnosis AS phd) PatientEnrollments
    GROUP BY PatientEnrollments.PatientId),
  missing_patient_enrolments_cte AS (SELECT c.PatientId
    FROM current_in_care_cte c
      LEFT JOIN patient_enrolment_cte e ON c.Id = e.PatientId
    WHERE e.PatientId IS NULL),
  patient_artintitiation_dates_cte AS (SELECT PatientARTdates.PatientId,
      Min(PatientARTdates.ARTDate) AS ARTInitiationDate
    FROM (SELECT PatientHivDiagnosis.PatientId,
        PatientHivDiagnosis.ARTInitiationDate AS ARTDate
      FROM PatientHivDiagnosis
      WHERE PatientHivDiagnosis.ARTInitiationDate IS NOT NULL
      UNION
      SELECT p.Id AS PatientId,
        o.DispensedByDate AS ARTDate
      FROM dbo.ord_PatientPharmacyOrder o
        INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
      WHERE o.DispensedByDate IS NOT NULL AND o.ptn_pharmacy_pk IN (SELECT
          dbo.dtl_PatientPharmacyOrder.ptn_pharmacy_pk
        FROM dbo.dtl_PatientPharmacyOrder
        WHERE dbo.dtl_PatientPharmacyOrder.Prophylaxis = 0) AND
        o.DeleteFlag = 0) PatientARTdates
    GROUP BY PatientARTdates.PatientId),
  missing_initialart_cte AS (SELECT c.PatientID,
      'MISSING ART START DATE' AS DataIssue
    FROM current_in_care_cte c
      LEFT JOIN patient_artintitiation_dates_cte e ON c.Id = e.PatientId
    WHERE e.PatientId IS NULL),
  regimen_cte AS (SELECT *
    FROM (SELECT V.PatientId,
        V.Regimen,
        V.RegimenId,
        Row_Number() OVER (PARTITION BY V.PatientId ORDER BY V.DispensedByDate
        DESC) AS rowNum
      FROM dbo.PatientTreatmentTrackerView V
      WHERE V.RegimenId <> 0 AND V.TreatmentStatus IN ('Start Treatment',
        'DrugSwitches', 'Continue current treatment', 'Drug Substitutio',
        'Drug Interruptions')) r
    WHERE r.rowNum = 1),
  missing_regimen_cte AS (SELECT c.PatientId,
      'MISSING REGIMEN' AS DataIssue
    FROM current_in_care_cte c
      LEFT JOIN regimen_cte e ON c.Id = e.PatientId
    WHERE e.PatientId IS NULL),
  patient_baseline_assessment_cte AS (SELECT pba.CD4Count AS BaselineCD4,
      pba.WHOStagename AS BaselineWHOStage,
      pba.PatientId
    FROM (SELECT Row_Number() OVER (PARTITION BY
        PatientBaselineAssessment.PatientId ORDER BY
        PatientBaselineAssessment.CreateDate) AS rowNum,
        PatientBaselineAssessment.PatientId,
        PatientBaselineAssessment.CreateDate,
        PatientBaselineAssessment.CD4Count,
        PatientBaselineAssessment.WHOStage,
        (SELECT LookupItem_1.Name FROM dbo.LookupItem AS LookupItem_1
        WHERE LookupItem_1.Id = dbo.PatientBaselineAssessment.WHOStage) AS
        WHOStagename
      FROM PatientBaselineAssessment
      WHERE (PatientBaselineAssessment.CD4Count IS NOT NULL) OR
        (PatientBaselineAssessment.WHOStage IS NOT NULL)) pba
    WHERE pba.rowNum = 1),
  missing_baseline_assessment_cte AS (SELECT e.PatientId,
      'MISSING BASELINE INFO' AS DataIssue
    FROM patient_baseline_assessment_cte e
    WHERE e.PatientId IS NULL),
  invalid_ccc_number AS (SELECT *,
      'INVALID CCC Number' AS DataIssue
    FROM current_in_care_cte
    WHERE Len(current_in_care_cte.PatientID) < 11),
  arv_cte AS (SELECT ord.PatientMasterVisitId,
      ord.PatientId,
      dis.Drug_Pk,
      dis.Prophylaxis,
      ord.orderstatus,
      dr.DrugName,
      ord.Ptn_pk,
      dis.OrderedQuantity,
      dis.DispensedQuantity,
      dis.Duration,
      dis.FrequencyID,
      dis.StrengthID
    FROM ord_PatientPharmacyOrder AS ord
      INNER JOIN dtl_PatientPharmacyOrder AS dis ON ord.ptn_pharmacy_pk =
        dis.ptn_pharmacy_pk
      INNER JOIN Mst_Drug AS dr ON dis.Drug_Pk = dr.Drug_pk
    WHERE dr.Abbreviation IS NOT NULL AND ord.DeleteFlag = 0),
  missed_arv_cte AS (SELECT v.PatientId,
      v.PatientMasterVisitId,
      v.lastVisitDate,
      v.lastProvider,
      c.DrugName,
      c.OrderedQuantity,
      c.DispensedQuantity,
      c.Duration,
      c.FrequencyID,
      c.StrengthID
    FROM last_visit_cte v
      LEFT OUTER JOIN arv_cte c ON c.PatientMasterVisitId =
        v.PatientMasterVisitId
    WHERE c.PatientId IS NULL),
  missing_arv_cte AS (SELECT PatientId,
      'MISSING ART PRESCRIPTION' AS DataIssue
    FROM missed_arv_cte e),
  ctx_cte AS (SELECT ord.PatientMasterVisitId,
      ord.PatientId,
      dis.Drug_Pk,
      dis.Prophylaxis,
      ord.orderstatus,
      dr.DrugName,
      ord.Ptn_pk,
      dis.OrderedQuantity,
      dis.DispensedQuantity,
      dis.Duration,
      dis.FrequencyID,
      dis.StrengthID
    FROM ord_PatientPharmacyOrder AS ord
      INNER JOIN dtl_PatientPharmacyOrder AS dis ON ord.ptn_pharmacy_pk =
        dis.ptn_pharmacy_pk
      INNER JOIN Mst_Drug AS dr ON dis.Drug_Pk = dr.Drug_pk
    WHERE (dr.DrugName LIKE '%cotrimoxazole%' OR dr.DrugName LIKE '%DAPSONE%' OR
        dr.DrugName LIKE '%Sulfa%') AND dr.DeleteFlag = 0 AND
      ord.DeleteFlag = 0),
  missed_ctx_cte AS (SELECT v.PatientId,
      v.PatientMasterVisitId,
      v.lastVisitDate,
      v.lastProvider,
      c.DrugName,
      c.OrderedQuantity,
      c.DispensedQuantity,
      c.Duration,
      c.FrequencyID,
      c.StrengthID
    FROM last_visit_cte v
      LEFT OUTER JOIN ctx_cte c ON c.PatientMasterVisitId =
        v.PatientMasterVisitId
    WHERE c.PatientId IS NULL),
  missing_ctx_cte AS (SELECT PatientId,
      'MISSING CTX PRESCRIPTION' AS DataIssue
    FROM missed_ctx_cte e),
  missed_stiscreening_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN PatientPHDP A ON A.PatientMasterVisitId =
        B.PatientMasterVisitId AND A.Phdp = 76
    WHERE A.Id IS NULL AND B.VisitBy = 108),
  missing_stiscreening_cte AS (SELECT PatientId,
      'MISSING STI SCREENING' AS DataIssue
    FROM missed_stiscreening_cte e),
  missed_adherence_assessment_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN AdherenceOutcome A ON A.PatientMasterVisitId =
        B.PatientMasterVisitId
    WHERE A.Id IS NULL AND B.VisitBy = 108),
  missing_adherence_assessment_cte AS (SELECT PatientId,
      'MISSING ADHERENCE ASSESSMENT' AS DataIssue
    FROM missed_adherence_assessment_cte e),
  missed_pia_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN PatientPregnancyIntentionAssessment A ON A.PatientMasterVisitId =
        B.PatientMasterVisitId
    WHERE A.Id IS NULL),
  missing_pia_cte AS (SELECT e.PatientId,
      'MISSING PIA' AS DataIssue
    FROM current_in_care_cte c
      INNER JOIN missed_pia_cte e ON c.Id = e.PatientId AND c.GenderId = 52),
  missed_fp_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN PatientFamilyPlanning A ON A.PatientMasterVisitId = B.PatientMasterVisitId
	  LEFT OUTER JOIN PatientFamilyPlanningMethod C ON C.PatientFPId = A.Id
    WHERE A.Id IS NULL OR (A.FamilyPlanningStatusId = 1 AND C.ID IS NULL)),
  missing_fp_cte AS (SELECT e.PatientId,
      'MISSING FP METHODS' AS DataIssue
    FROM current_in_care_cte c
      INNER JOIN missed_fp_cte e ON c.Id = e.PatientId AND c.GenderId = 52),
  missed_stability_assessment_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN PatientCategorization A ON A.PatientMasterVisitId =
        B.PatientMasterVisitId
    WHERE A.id IS NULL AND B.VisitBy = 108),
  missing_stability_assessment_cte AS (SELECT PatientId,
      'MISSING STABILITY ASSESSMENT' AS DataIssue
    FROM missed_stability_assessment_cte e),
  missed_appointments_cte AS (SELECT B.PatientMasterVisitId,
      B.PatientId
    FROM last_visit_cte B
      LEFT OUTER JOIN PatientAppointment A ON A.PatientMasterVisitId =
        B.PatientMasterVisitId
    WHERE A.Id IS NULL AND B.VisitBy = 108),
  missing_appointments_cte AS (SELECT PatientId,
      'MISSING APPOINTMENTS' AS DataIssue
    FROM missed_appointments_cte e),
  linelist_cte AS (
	--SELECT * FROM missing_regimen_cte
    --UNION
    --SELECT * FROM missing_initialart_cte
    --UNION
    --SELECT * FROM missing_lastvl_cte
    --UNION
    SELECT * FROM missing_ctx_cte
    UNION
    SELECT * FROM missing_stiscreening_cte
    UNION
    SELECT * FROM missing_stability_assessment_cte
    UNION
    SELECT * FROM missing_adherence_assessment_cte
    UNION    
	SELECT * FROM missing_arv_cte
    UNION
    SELECT * FROM missing_appointments_cte
	UNION
	SELECT * FROM missing_pia_cte
	--UNION
	--SELECT * FROM missing_fp_cte	
	)
--	select * from linelist_cte
-- select * from current_in_care_cte
--	select * from last_visit_cte
--	return
SELECT 
  A.Id,
  A.PatientID,
  A.PatientName,
  A.PatientType,
  A.Sex,
  A.RegistrationDate,
  V.lastVisitDate,
  V.LastProviders as [LastProvider(s)],
  A.NextAppointmentDate AS TCADate,
  B.DataIssue
FROM linelist_cte B 
INNER JOIN current_in_care_cte A ON B.PatientId = A.Id 
 INNER JOIN last_visit_cte V ON A.Id = V.PatientId
 WHERE v.LastProviderName IN ('Nancy Odhiambo', 'Onywera Susan', 'Diana Oketch')
ORDER BY V.lastProvider, V.lastVisitDate
