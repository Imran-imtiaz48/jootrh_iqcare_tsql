DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2018-06-01';
set @endDate = '2018-12-31';

BEGIN TRY
drop table #tmpAllTreatment
END TRY
BEGIN CATCH
END CATCH

;WITH all_treatment_cte AS (
		SELECT * FROM (
			SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
					INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
					 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
					)		
			 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
		) t
)

SELECT * 
INTO #tmpAllTreatment
FROM all_treatment_cte 

;WITH all_Patients_cte AS (SELECT g.Id AS PatientID,
      g.PersonId,
      PC.MobileNumber AS PhoneNumber,
      g.EnrollmentNumber,
      Upper(CONCAT(g.FirstName, ' ', g.MiddleName, ' ', g.LastName)) AS
      PatientName,
      CASE WHEN g.Sex = 52 THEN 'F' ELSE 'M' END AS Sex,
      DateDiff(M, g.[EnrollmentDate ], @endDate) / 12 AS RegistrationAge,
      DateDiff(M, g.DateOfBirth, @endDate) / 12 AS currentAge,
      '' AS EnrolledAt,
      CAST(CASE WHEN TI.TransferInDate IS NOT NULL THEN TI.TransferInDate
        ELSE g.[EnrollmentDate ] END AS Date) AS EnrollmentDate,
      '' AS ARTStartDate,
      '' AS FirstVisitDate,
      '' AS LastVisitDate,
      P.NextAppointmentDate,
      CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason
      END PatientStatus,
      CAST(ce.ExitDate AS DATE) AS ExitDate,
      g.DateOfBirth,
      g.PatientType,
      ce.ExitReason	  
    FROM gcPatientView2 g
      LEFT JOIN (SELECT ce.PatientId,
        ce.ExitReason,
        ce.ExitDate,
        ce.TransferOutfacility,
        ce.CreatedBy
      FROM (SELECT ce.PatientId,
          l.Name AS ExitReason,
          ce.ExitDate,
          ce.TransferOutfacility,
          ce.CreatedBy,
          Row_Number() OVER (PARTITION BY ce.PatientId ORDER BY ce.CreateDate
          DESC) AS RowNum
        FROM patientcareending ce
          INNER JOIN LookupItem l ON l.Id = ce.ExitReason
        WHERE ce.ExitDate < @startDate AND ce.DeleteFlag = 0) ce
      WHERE ce.RowNum = 1) ce ON g.Id = ce.PatientId
      LEFT JOIN (SELECT pc1.PersonId,
        pc1.MobileNumber,
        pc1.AlternativeNumber,
        pc1.EmailAddress
      FROM (SELECT Row_Number() OVER (PARTITION BY PC.PersonId ORDER BY
          PC.CreateDate) AS RowNum,
          PC.PersonId,
          PC.MobileNumber,
          PC.AlternativeNumber,
          PC.EmailAddress
        FROM PersonContactView PC) pc1
      WHERE pc1.RowNum = 1) PC ON PC.PersonId = g.PersonId
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = g.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM PatientAppointment X
      GROUP BY X.PatientId) P ON g.Id = P.PatientId),
 marital_status_cte AS (
	SELECT PatientId, MaritalStatus FROM (
		SELECT ROW_NUMBER() OVER (PARTITION BY m.personId ORDER BY m.CreateDate DESC) AS rown, p.id AS PatientId, m.PersonId, l.Name AS MaritalStatus FROM PatientMaritalStatus m 
		INNER JOIN LookupItem l ON m.MaritalStatusId = l.Id 
		INNER JOIN Patient p ON p.PersonId = m.PersonId
		WHERE m.DeleteFlag = 0
	) m WHERE m.rown = 1 
 ),

  baseline_cd4_results_cte AS (SELECT *
    FROM (SELECT *,
        Row_Number() OVER (PARTITION BY cd4.patientId ORDER BY cd4.CD4Date) AS
        RowNum
      FROM (SELECT dbo.PatientLabTracker.patientId,
          dbo.PatientLabTracker.SampleDate AS CD4Date,
          dbo.PatientLabTracker.ResultValues AS CD4Results
        FROM dbo.PatientLabTracker
        WHERE dbo.PatientLabTracker.SampleDate <= @endDate AND
          dbo.PatientLabTracker.Results = 'Complete' AND
          dbo.PatientLabTracker.LabTestId = 1
        UNION
        SELECT PatientBaselineAssessment.PatientId,
          PatientBaselineAssessment.CreateDate,
          PatientBaselineAssessment.CD4Count
        FROM PatientBaselineAssessment
        WHERE PatientBaselineAssessment.CD4Count > 0) cd4) cd4
    WHERE cd4.RowNum = 1),

  cd4_results_cte AS (SELECT *
    FROM (SELECT dbo.PatientLabTracker.patientId,
        dbo.PatientLabTracker.SampleDate AS CD4Date,
        dbo.PatientLabTracker.ResultValues AS CD4Results,
        Row_Number() OVER (PARTITION BY dbo.PatientLabTracker.patientId ORDER BY
        dbo.PatientLabTracker.SampleDate DESC) AS RowNum
      FROM dbo.PatientLabTracker
      WHERE dbo.PatientLabTracker.SampleDate <= @endDate AND
        dbo.PatientLabTracker.Results = 'Complete' AND
        dbo.PatientLabTracker.LabTestId = 1) cd4
    WHERE cd4.RowNum = 1),

  all_vl_cte AS (SELECT DISTINCT t.patientId,
      CAST(t.SampleDate AS DATE) AS VlDate,
      CASE WHEN tr.Undetectable = 1 OR t.ResultTexts LIKE '%< LDL%' THEN 0
        ELSE t.ResultValues END AS VLResults
    FROM dbo.PatientLabTracker t
      INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
    WHERE t.Results = 'Complete' AND t.LabTestId = 3 AND t.SampleDate <=
      @endDate),

  pending_vl_results_cte AS (SELECT *
    FROM (SELECT dbo.PatientLabTracker.patientId,
        dbo.PatientLabTracker.SampleDate AS VLDate,
        dbo.PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY dbo.PatientLabTracker.patientId ORDER BY
        dbo.PatientLabTracker.SampleDate DESC) AS RowNum
      FROM dbo.PatientLabTracker
      WHERE dbo.PatientLabTracker.SampleDate <= @endDate AND
        dbo.PatientLabTracker.Results = 'Pending' AND
        dbo.PatientLabTracker.LabTestId = 3) vlr),

  last_vl_sample_in_past_1yr_cte AS (SELECT vlr.patientId,
      vlr.SampleDate,
      vlr.VLResults
    FROM (SELECT dbo.PatientLabTracker.patientId,
        CAST(dbo.PatientLabTracker.SampleDate AS DATE) AS SampleDate,
        dbo.PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY dbo.PatientLabTracker.patientId ORDER BY
        dbo.PatientLabTracker.SampleDate DESC) AS RowNum
      FROM dbo.PatientLabTracker
      WHERE dbo.PatientLabTracker.LabTestId = 3 AND
        dbo.PatientLabTracker.SampleDate <= @endDate AND DateDiff(MM,
        dbo.PatientLabTracker.SampleDate, @endDate) <= 12) vlr
    WHERE vlr.RowNum = 1),

  baseline_vl_cte AS (SELECT *
    FROM (SELECT dbo.PatientLabTracker.patientId,
        CAST(dbo.PatientLabTracker.SampleDate AS DATE) AS VlDate,
        dbo.PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY dbo.PatientLabTracker.patientId ORDER BY
        dbo.PatientLabTracker.SampleDate) AS RowNum
      FROM dbo.PatientLabTracker
      WHERE dbo.PatientLabTracker.Results = 'Complete' AND
        dbo.PatientLabTracker.LabTestId = 3 AND dbo.PatientLabTracker.SampleDate
        <= @endDate) r
    WHERE r.RowNum = 1),

  vl_cte AS (SELECT *
    FROM (SELECT all_vl_cte.patientId,
        all_vl_cte.VlDate,
        all_vl_cte.VLResults,
        Row_Number() OVER (PARTITION BY all_vl_cte.patientId ORDER BY
        all_vl_cte.VlDate DESC) AS RowNum
      FROM all_vl_cte) r
    WHERE r.RowNum = 1),

  second_last_vl_cte AS (SELECT *
    FROM (SELECT all_vl_cte.patientId,
        all_vl_cte.VlDate AS VlResultsDate,
        all_vl_cte.VLResults,
        Row_Number() OVER (PARTITION BY all_vl_cte.patientId ORDER BY
        all_vl_cte.VlDate DESC) AS RowNum
      FROM all_vl_cte) r
    WHERE r.RowNum = 2),

  regimen_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY r.patientId ORDER BY
        r.RowNumber DESC) AS RowNumber,
        r.patientId,
        r.ptn_pk,
        r.RegimenType
      FROM RegimenMapView r) r
    WHERE r.RowNumber = 1),

	all_vl_sample_cte AS (
		SELECT        DISTINCT patientId,CAST(SampleDate AS DATE) as VlSampleDate, CASE WHEN tr.Undetectable = 1  OR ResultTexts LIKE '%< LDL%' then 0 else ResultValues END  as VLResults
		FROM            dbo.PatientLabTracker t
		INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
		WHERE        (t.LabTestId = 3) AND SAmpleDate <= @endDate --	AND SampleDate <= '2018-05-15'
	),

	last_vl_sample_cte AS (
		SELECT PatientId, VlSampleDate, VLResults FROM (
			SELECT        patientId, VlSampleDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY VlSampleDate DESC) as RowNum
			FROM            all_vl_sample_cte
		) r WHERE r.RowNum = 1
	),

	first_vl_sample_cte AS (
		SELECT PatientId, VlSampleDate, VLResults FROM (
			SELECT        patientId, VlSampleDate, VLResults,ROW_NUMBER() OVER (Partition By PatientId ORDER BY VlSampleDate ASC) as RowNum
			FROM            all_vl_sample_cte
		) r WHERE r.RowNum = 1
	),

  patient_artintitiation_dates_cte AS (
  SELECT PatientARTdates.PatientId, CAST(Min(PatientARTdates.ARTDate) AS DATE) AS ARTInitiationDate
    FROM (SELECT PatientHivDiagnosis.PatientId,
        PatientHivDiagnosis.ARTInitiationDate AS ARTDate
      FROM PatientHivDiagnosis
      WHERE PatientHivDiagnosis.ARTInitiationDate IS NOT NULL AND
        PatientHivDiagnosis.ARTInitiationDate >= 2000
      UNION
      SELECT p.Id AS PatientId,
        o.DispensedByDate AS ARTDate
      FROM dbo.ord_PatientPharmacyOrder o
        INNER JOIN patient p ON p.ptn_pk = o.Ptn_pk
      WHERE o.DispensedByDate IS NOT NULL AND o.DispensedByDate <= @endDate AND
        o.ptn_pharmacy_pk IN (SELECT o.ptn_pharmacy_pk
        FROM dbo.dtl_PatientPharmacyOrder o INNER JOIN mst_drug d
            ON d.Drug_pk = o.Drug_Pk
        WHERE o.Prophylaxis = 0 AND d.Abbreviation IS NOT NULL AND
          d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND
          d.DrugName NOT LIKE '%Septrin%' AND d.DrugName NOT LIKE '%Dapson%')
        AND o.DeleteFlag = 0 AND Year(o.DispensedByDate) >=
        2000) PatientARTdates
    GROUP BY PatientARTdates.PatientId),

	all_treatmenttracker_cte AS (
		SELECT * FROM (
			SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenStartDate DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenStartDate as RegimenDate,  CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			TLE400 = (SELECT CASE WHEN COUNT(o.PatientMasterVisitId)>0 THEN 1 ELSE 0 END FROM dtl_PatientPharmacyOrder d
					INNER JOIN ord_PatientPharmacyOrder o ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
					 WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND d.Drug_Pk = 1702 --TLE400
					)		
			 FROM PatientTreatmentTrackerViewD4T t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenStartDate) >= 2000 AND t.RegimenStartDate <= @endDate
		) t
	),

	curr_treatmenttracker_cte AS (
		SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine, TLE400 FROM (
			SELECT RegimenId,ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenDate DESC,t.PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen,t.RegimenDate as RegimenDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			TLE400
			 FROM #tmpAllTreatment t WHERE t.Regimen IS NOT NULL AND YEAR(t.RegimenDate) >= 2000 AND t.RegimenDate <= @endDate

		) t WHERE t.rowNum = 1
	),

	init_treatmenttracker_cte AS (
		SELECT TLE400,PatientMasterVisitId, PatientId,Regimen,RegimenId, t.ARTInitiationDate, Line as regimenLine FROM (
			SELECT PatientMasterVisitId, RegimenId, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY t.RegimenDate ASC, t.RegimenDate ASC,PatientMasterVisitId DESC) as rowNum, t.PatientId,t.RegimenLine,t.Regimen, CAST(t.RegimenDate AS DATE) as ARTInitiationDate, CASE WHEN t.RegimenLine LIKE '%First%' THEN '1' WHEN t.RegimenLine LIKE '%Second%' THEN '2' WHEN t.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line ,
			TLE400		
			FROM #tmpAllTreatment t WHERE t.Regimen IS NOT NULL  AND YEAR(t.RegimenDate) >= 2000 AND t.RegimenDate <= @endDate --and t.RegimenStartDate IS NOT NULL
		) t WHERE t.rowNum = 1
	),

	prev_treatmenttracker_cte AS (
		SELECT PatientId,Regimen,RegimenId, RegimenDate, Line as regimenLine, TLE400 FROM (
			SELECT att.RegimenDate, att.PatientId, att.RegimenId, att.Regimen,  CASE WHEN att.RegimenLine LIKE '%First%' THEN '1' WHEN att.RegimenLine LIKE '%Second%' THEN '2' WHEN att.regimenLine LIKE '%third%' THEN 3 ELSE  NULL END as Line,
			t.TLE400, ROW_NUMBER() OVER(PARTITION BY att.PatientId ORDER BY att.RegimenDate DESC) as RowNum FROM curr_treatmenttracker_cte t 
			INNER JOIN #tmpAllTreatment att ON t.PatientId = att.PatientId AND t.RegimenId <> att.RegimenId 
		) t WHERE t.rowNum = 1
	),

  prev_regimen_date_cte AS (SELECT attx.PatientId,
      Min(attx.RegimenDate) AS Regimendate
    FROM #tmpAllTreatment attx
      INNER JOIN prev_treatmenttracker_cte pttx ON attx.PatientId =
        pttx.PatientId AND pttx.RegimenId = attx.RegimenId
    GROUP BY attx.PatientId),
  curr_regimen_date_cte AS (SELECT attx.PatientId,
      Min(attx.RegimenDate) AS Regimendate
    FROM #tmpAllTreatment attx
      INNER JOIN curr_treatmenttracker_cte pttx ON attx.PatientId =
        pttx.PatientId AND pttx.RegimenId = attx.RegimenId
    GROUP BY attx.PatientId),
  providers_cte AS (SELECT CONCAT(u.UserFirstName, ' ', u.UserLastName) AS
      ProviderName,
      u.UserID,
      lg.GroupID
    FROM lnk_UserGroup lg
      INNER JOIN mst_User u ON u.UserID = lg.UserID
    WHERE (lg.GroupID = 5) OR
      (lg.GroupID = 7)),

  all_visits_cte AS (
  SELECT visits.PatientId, visits.VisitDate,     visits.PatientMasterVisitId,     visits.ProviderId,     visits.ProviderName,     visits.UserID,     visits.GroupID,     visits.VisitBy
    FROM (
		SELECT v.PatientId, v.VisitDate, v.PatientMasterVisitId, v.ProviderId,  p.ProviderName,  p.GroupID,  p.UserID,  v.VisitBy,   Row_Number() OVER (PARTITION BY v.PatientId, v.PatientMasterVisitId
        ORDER BY v.VisitDate DESC) AS RowNum
      FROM (SELECT v.PatientId,
          CAST(v.VisitDate AS DATE) AS VisitDate,
          v.Id AS PatientMasterVisitId,
          v.CreatedBy AS ProviderId,
          v.VisitBy
        FROM PatientMasterVisit v
          INNER JOIN PatientEncounter p ON p.PatientMasterVisitId = v.Id
        WHERE v.VisitDate IS NOT NULL AND
          v.VisitDate <= (SELECT Max(a.AppointmentDate)
          FROM PatientAppointment a
          WHERE a.PatientId = v.PatientId) AND v.VisitDate <= @endDate
        /*
		UNION
        SELECT PatientScreening.PatientId,
          CAST(PatientScreening.CreateDate AS DATE) AS VisitDate,
          PatientScreening.PatientMasterVisitId,
          PatientScreening.CreatedBy AS lastProvider,
          108 AS VisitBy
        FROM PatientScreening
        WHERE PatientScreening.CreateDate = @endDate
		*/
		) v
        INNER JOIN providers_cte p ON p.UserID = v.ProviderId
      WHERE v.VisitDate <= @endDate) visits
    WHERE visits.RowNum = 1),

  last_visit_cte AS (
	  SELECT 
		  lv.LastVisitDate,
		  lv.PatientId,
		  lv.PatientMasterVisitId,
		  lv.LastProvider,
		  lv.LastProviderName,
		  LastProviders = Stuff((SELECT DISTINCT ',' + pr.ProviderName  FROM PatientEncounter e INNER JOIN providers_cte pr ON e.CreatedBy =
			  pr.UserID	  WHERE e.PatientMasterVisitId = lv.PatientMasterVisitId  FOR XML PATH('')), 1, 1, ''),
		  lv.VisitBy
	  FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        v.PatientMasterVisitId,
        v.VisitBy,
        v.ProviderName AS LastProviderName,
        v.ProviderId AS LastProvider,
        v.VisitDate AS LastVisitDate
      FROM all_visits_cte v) lv
    WHERE lv.rowNum = 1),

  last_visit_filtered_cte AS (SELECT lastVisit.VisitDate AS lastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        v.VisitDate,
        v.PatientMasterVisitId,
        v.UserID lastProvider,
        CONCAT(u.UserFirstName, ' ', u.UserLastName) AS LastProviderName
      FROM all_visits_cte v
        INNER JOIN mst_User u ON v.UserID = u.UserID
      WHERE v.VisitDate <= @endDate AND v.VisitDate >= @startDate) lastVisit
    WHERE lastVisit.rowNum = 1),

  first_visit_cte AS (SELECT lastVisit.VisitDate AS firstVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate) AS rowNum,
        v.PatientId,
        v.VisitDate,
        v.PatientMasterVisitId,
        v.UserID lastProvider,
        CONCAT(u.UserFirstName, ' ', u.UserLastName) AS LastProviderName
      FROM all_visits_cte v
        INNER JOIN mst_User u ON v.UserID = u.UserID) lastVisit
    WHERE lastVisit.rowNum = 1),
  screening_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY PatientScreening.PatientId
        ORDER BY PatientScreening.VisitDate DESC) AS rowNum,
        PatientScreening.PatientId,
        PatientScreening.CreateDate AS VisitDate,
        PatientScreening.PatientMasterVisitId,
        PatientScreening.CreatedBy AS lastProvider
      FROM PatientScreening) ps
    WHERE ps.rowNum = 1),
  bluecard_bl_who_stage_cte AS (SELECT who.PatientId,
      who.WHOStage,
      who.VisitDate,
      2 AS bpriority
    FROM (SELECT Row_Number() OVER (PARTITION BY who.PatientId ORDER BY
        who.VisitDate) AS r,
        who.PatientId,
        who.WHOStage,
        who.VisitDate
      FROM (SELECT s.PatientId,
          l.Name AS WHOStage,
          CAST(PatientMasterVisit.VisitDate AS DATE) AS VisitDate
        FROM PatientWHOStage AS s
          INNER JOIN LookupItem AS l ON l.Id = s.WHOStage
          INNER JOIN PatientMasterVisit ON s.PatientMasterVisitId =
            PatientMasterVisit.Id
        UNION
        SELECT p.Id AS patientId,
          CASE d.Name WHEN 1 THEN 'Stage1' WHEN 2 THEN 'Stage2'
            WHEN 3 THEN 'Stage3' WHEN 4 THEN 'Stage4' END AS WHOStage,
          CAST(ord_Visit.VisitDate AS DATE) AS VisitDate
        FROM ord_Visit
          INNER JOIN (dtl_PatientStage AS s
          INNER JOIN mst_Decode AS d ON s.WHOStage = d.ID
          INNER JOIN Patient AS p ON s.Ptn_pk = p.ptn_pk)
            ON ord_Visit.Visit_Id = s.Visit_Pk
        WHERE IsNumeric(d.Name) = 1) who) who
    WHERE who.r = 1),

  greencard_bl_who_stage_cte AS (SELECT who.PatientId,
      who.WHOStage,
      who.VisitDate,
      who.bpriority
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
        s.CreateDate) AS rowNum,
        s.PatientId,
        l.Name AS WHOStage,
        CAST(v.VisitDate AS DATE) AS VisitDate,
        1 AS bpriority
      FROM PatientBaselineAssessment AS s
        INNER JOIN LookupItem AS l ON l.Id = s.WHOStage
        INNER JOIN PatientMasterVisit AS v ON s.PatientMasterVisitId = v.Id
      WHERE s.WHOStage != 500) who
    WHERE who.rowNum = 1),
  baseline_who_stage_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY who.PatientId ORDER BY
        who.bpriority, who.VisitDate) AS rowNum,
        who.PatientId,
        who.WHOStage,
        who.VisitDate
      FROM (SELECT *
        FROM greencard_bl_who_stage_cte
        UNION
        SELECT *
        FROM bluecard_bl_who_stage_cte) who) who
    WHERE who.rowNum = 1),
  ti_cte AS (SELECT ti.PatientId,
      ti.TINumber
    FROM (SELECT Row_Number() OVER (PARTITION BY PatientIdentifier.PatientId
        ORDER BY PatientIdentifier.PatientId) AS rowNUm,
        PatientIdentifier.PatientId,
        PatientIdentifier.IdentifierValue AS TINumber
      FROM PatientIdentifier
      WHERE PatientIdentifier.IdentifierTypeId = 17) ti
    WHERE ti.rowNUm = 1),
  mch_cte AS (SELECT ti.PatientID,
      ti.MCHNumber,
      ti.MCHEnrollmentDate
    FROM (SELECT Row_Number() OVER (PARTITION BY P.Id ORDER BY P.Id) AS rowNUm,
        P.Id AS PatientID,
        M.MCHID AS MCHNumber,
        CAST(ps.StartDate AS DATE) AS MCHEnrollmentDate
      FROM mst_Patient M
        INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk
        LEFT JOIN Lnk_PatientProgramStart ps ON ps.Ptn_pk = M.Ptn_Pk
        INNER JOIN mst_module modu ON ps.ModuleId = modu.ModuleID
      WHERE M.MCHID IS NOT NULL AND modu.ModuleID = 15) ti
    WHERE ti.rowNUm = 1),
  otz_cte AS (SELECT ti.PatientID,
      ti.OTZNumber
    FROM (SELECT Row_Number() OVER (PARTITION BY P.Id ORDER BY P.Id) AS rowNUm,
        P.Id AS PatientID,
        CAST(M.OTZNumber AS nvarchar(10)) AS OTZNumber
      FROM mst_Patient M
        INNER JOIN Patient P ON P.ptn_pk = M.Ptn_Pk
      WHERE M.OTZNumber IS NOT NULL) ti
    WHERE ti.rowNUm = 1),
  all_tca_cte AS (SELECT p.PatientId,
      CAST(p.AppointmentDate AS DATE) AS AppointmentDate,
      CAST(v.VisitDate AS DATE) AS Visitdate,
      l.Name AS VisitStatus
    FROM PatientAppointment p
      INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id
      INNER JOIN LookupItem l ON l.Id = p.StatusId
    WHERE (v.VisitDate <= @endDate AND Abs(DateDiff(M, v.VisitDate,
      p.AppointmentDate)) <= 3) OR
      (p.AppointmentDate <= @endDate)
    UNION
    SELECT p.Id AS PatientId,
      CAST(a.AppDate AS DATE) AS AppointmentDate,
      CAST(o.VisitDate AS DATE) AS VisitDate,
      ''
    FROM dtl_PatientAppointment a
      INNER JOIN Patient p ON a.Ptn_pk = p.ptn_pk
      INNER JOIN ord_Visit o ON o.Visit_Id = a.Visit_pk
    WHERE o.VisitDate <= @endDate),
  fp_method_cte AS (SELECT DISTINCT fp.PatientMasterVisitId,
      fpm.PatientId,
      l.DisplayName AS FPMethod,
      fp.VisitDate,
      fp.ReasonNotOnFPId
    FROM PatientFamilyPlanning AS fp
      INNER JOIN PatientFamilyPlanningMethod AS fpm ON fp.Id = fpm.PatientFPId
      INNER JOIN LookupItem AS l ON fpm.FPMethodId = l.Id
    WHERE fp.VisitDate <= @endDate AND fp.VisitDate >= DateAdd(M, -6,
      @endDate)),
  last_tca_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY all_tca_cte.PatientId
        ORDER BY all_tca_cte.Visitdate DESC, all_tca_cte.AppointmentDate DESC)
        AS rowNUm,
        *
      FROM all_tca_cte) tca
    WHERE tca.rowNUm = 1),
  secondlast_tca_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY all_tca_cte.PatientId
        ORDER BY all_tca_cte.Visitdate DESC, all_tca_cte.AppointmentDate DESC)
        AS rowNUm,
        *
      FROM all_tca_cte) tca
    WHERE tca.rowNUm = 2),
  thirdlast_tca_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY all_tca_cte.PatientId
        ORDER BY all_tca_cte.Visitdate DESC, all_tca_cte.AppointmentDate DESC)
        AS rowNUm,
        *
      FROM all_tca_cte) tca
    WHERE tca.rowNUm = 3),
  all_who_stage_cte AS (SELECT DISTINCT PatientWHOStage.PatientId,
      PatientWHOStage.PatientMasterVisitId
    FROM PatientWHOStage),

  pregnancy_cte AS (SELECT *
    FROM (SELECT pgs.PatientId,
        pgs.PregnancyStatus,
        pgs.LMP,
        pgs.EDD,
        pgs.VisitDate,
        Row_Number() OVER (PARTITION BY pgs.PatientId ORDER BY pgs.LMP
        DESC) AS RowNum,
        pgs.Outcome,
        pgs.DateOfOutcome,
        pgs.Parity,
        pgs.[ANC/PNC]
      FROM (SELECT PI.Id,
          PI.PatientId,
          PI.LMP,
          CASE WHEN L1.Name = 'PG' THEN PI.EDD ELSE NULL END AS EDD,
          CAST(PI.CreateDate AS DATE) AS VisitDate,
          L1.DisplayName AS PregnancyStatus,
          P.Outcome,
          P.DateOfOutcome,
          P.Parity,
          CASE PI.ANCProfile WHEN 1 THEN 'ANC' ELSE 'PNC' END AS [ANC/PNC]
        FROM PregnancyIndicator AS PI
          INNER JOIN LookupItem L1 ON PI.PregnancyStatusId = L1.Id
          LEFT JOIN Pregnancy P ON P.PatientId = PI.PatientId AND
            P.PatientMasterVisitId = PI.PatientMasterVisitId) pgs) p
    WHERE p.RowNum = 1),
  stability_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
        v.VisitDate DESC, s.id DESC) AS rowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        v.VisitDate AS CategorizationDate
      FROM PatientCategorization s
	   INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
      WHERE v.DeleteFlag = 0 AND s.DeleteFlag = 0 AND v.VisitDate <= @endDate) s
    WHERE s.rowNum = 1),

	dc_cte AS (
		SELECT dc.PatientId,
			dc.DCModel
		FROM (SELECT PA.PatientId,
			PA.DifferentiatedCareId,
			V.VisitDate,
			L.Name,
			L.DisplayName AS DCModel,
			Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate
			DESC, [description],PA.CreateDate DESC,PA.CreatedBy DESC) AS RowNum
			FROM PatientAppointment AS PA
			INNER JOIN PatientMasterVisit AS V ON V.id = PA.PatientMasterVisitId
			INNER JOIN PatientCategorization AS PC ON PC.PatientMasterVisitId = PA.PatientMasterVisitId
			INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
			WHERE V.VisitDate <= @endDate AND PA.DeleteFlag =0 AND PC.DeleteFlag = 0) dc
		WHERE dc.RowNum = 1
	),

	dsd_cte AS (
		SELECT PA.PatientId,
			PA.DifferentiatedCareId,
			V.VisitDate AS DSDDate,
			L.Name,
			L.DisplayName AS DCModel,
			Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate
			ASC, [description],PA.CreateDate DESC,PA.CreatedBy DESC) AS RowNum
			FROM PatientAppointment AS PA
			INNER JOIN PatientMasterVisit AS V ON V.id = PA.PatientMasterVisitId
			INNER JOIN PatientCategorization AS PC ON PC.PatientMasterVisitId = PA.PatientMasterVisitId
			INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id AND l.Name IN ('Express Care', 'Community Based Dispensing')
			WHERE V.VisitDate <= @endDate AND PA.DeleteFlag =0 AND PC.DeleteFlag = 0
	),

	dsd_start_cte AS (
		SELECT dc.PatientId,
			dc.DCModel,
			CAST(dc.VisitDate AS DATE) AS StartDate
		FROM (SELECT PA.PatientId,
			PA.DifferentiatedCareId,
			V.VisitDate,
			L.Name,
			L.DisplayName AS DCModel,
			Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate
			ASC, [description],PA.CreateDate DESC,PA.CreatedBy DESC) AS RowNum
			FROM PatientAppointment AS PA
			INNER JOIN PatientMasterVisit AS V ON V.id = PA.PatientMasterVisitId
			INNER JOIN PatientCategorization AS PC ON PC.PatientMasterVisitId = PA.PatientMasterVisitId
			INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id AND l.Name = 'Express Care'
			WHERE V.VisitDate <= @endDate AND PA.DeleteFlag =0 AND PC.DeleteFlag = 0) dc
		WHERE dc.RowNum = 1		
	),

  fp_cte AS (SELECT fp.PatientId,
      fp.CurrentlyOnFp,
      fp.ReasonNotOnFp,
      fp.VisitDate,
      fp.PatientMasterVisitId,
      fp.Id,
      MethodsCount = (SELECT Count(DISTINCT fpm.FPMethodId)
      FROM PatientFamilyPlanningMethod fpm WHERE fpm.PatientFPId = fp.Id)
    FROM (SELECT fp.Id,
        Row_Number() OVER (PARTITION BY fp.PatientId ORDER BY fp.VisitDate DESC)
        AS rowNum,
        fp.PatientId,
        CASE fp.FamilyPlanningStatusId WHEN 1 THEN 'Y' WHEN 2 THEN 'N' ELSE 'W'
        END AS CurrentlyOnFp,
        l.DisplayName AS ReasonNotOnFp,
        fp.VisitDate,
        fp.PatientMasterVisitId
      FROM PatientFamilyPlanning fp
        LEFT JOIN LookupItem l ON fp.ReasonNotOnFPId = l.Id
      WHERE fp.VisitDate <= @endDate AND fp.VisitDate >= DateAdd(M, -9,
        @endDate)) fp
    WHERE fp.rowNum = 1),
  location_cte AS (SELECT *
    FROM (SELECT PL.Id,
        PL.LandMark,
        PL.PersonId,
        PL.Location,
        C.CountyName,
        SC.Subcountyname,
        Patient.Id AS PatientId,
        W.WardName,
        Row_Number() OVER (PARTITION BY Patient.Id ORDER BY PL.CreateDate DESC)
        AS RowNum
      FROM PersonLocation AS PL
        INNER JOIN County AS C ON PL.County = C.CountyId
        INNER JOIN County AS SC ON PL.SubCounty = SC.SubcountyId
        INNER JOIN Patient ON PL.PersonId = Patient.PersonId
        INNER JOIN County AS W ON PL.Ward = W.WardId) r
    WHERE r.RowNum = 1),
  all_curr_month_stability_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId,
        Month(v.VisitDate) ORDER BY v.VisitDate DESC) AS RowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        s.PatientMasterVisitId,
        CAST(v.VisitDate AS DATE) AS CategorizationDate
      FROM PatientCategorization s
	   INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
       WHERE s.CreateDate >= DateAdd(M, DateDiff(M, 0, @startDate), 0) AND
        v.VisitDate <= EOMONTH(@startDate)) s
    WHERE s.RowNum = 1),
  curr_month_dc_cte AS (SELECT dc.PatientId,
      dc.DCModel
    FROM (SELECT PA.PatientId,
        PA.DifferentiatedCareId,
        v.VisitDate,
        L.Name,
        L.DisplayName AS DCModel,
        Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY v.VisitDate
        DESC) AS RowNum
      FROM PatientAppointment AS PA
		INNER JOIN PatientMasterVisit AS V ON V.id = PA.PatientMasterVisitId
		INNER JOIN PatientCategorization S ON s.PatientMasterVisitId = PA.PatientMasterVisitId
         INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
      WHERE v.VisitDate >= DateAdd(M, DateDiff(M, 0, @startDate), 0)
        AND v.VisitDate <= EOMONTH(@startDate)) dc
    WHERE dc.RowNum = 1),
  all_prev_stability_cte AS (SELECT s.PatientId, s.Categorization, s.CategorizationDate
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
        v.VisitDate DESC) AS RowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        s.PatientMasterVisitId,
        CAST(v.VisitDate AS DATE) AS CategorizationDate
      FROM PatientCategorization s
		INNER JOIN PatientMasterVisit AS V ON V.id = s.PatientMasterVisitId
       WHERE v.VisitDate <= DateAdd(M, DateDiff(M, 0, @startDate), 0)) s
    WHERE s.RowNum = 1),
  prev_dc_cte AS (
    SELECT dc.PatientId, dc.DCModel
    FROM (SELECT PA.PatientId,
        PA.DifferentiatedCareId,
        v.VisitDate,
        L.Name,
        L.DisplayName AS DCModel,
        Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY v.VisitDate
        DESC) AS RowNum
      FROM PatientAppointment AS PA
		INNER JOIN PatientMasterVisit AS V ON V.id = PA.PatientMasterVisitId
		INNER JOIN PatientCategorization S ON s.PatientMasterVisitId = PA.PatientMasterVisitId
        INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
      WHERE v.VisitDate <= DateAdd(M, DateDiff(M, 0, @startDate), 0)) dc
    WHERE dc.RowNum = 1),

 art_adherence_cte AS (
	SELECT PatientId,AdherenceScore FROM (
		SELECT a.PatientId, li.Name as AdherenceScore, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) AS rown FROM AdherenceOutcome a INNER JOIN LookupItem li ON a.Score = li.Id
		WHERE AdherenceType = 34
	) adh WHERE adh.rown = 1
 ),

 ovc_cte AS (
	SELECT PatientId,InSchool  FROM (
		SELECT 
			ROW_NUMBER() OVER (PARTITION BY o.PersonId ORDER BY o.CreateDate DESC) AS rown, p.Id AS PatientId, o.PersonId, CASE o.InSchool WHEN 0 THEN 'N' WHEN 1 THEN 'Y' END AS InSchool 
		FROM PatientOVCStatus o INNER JOIN Patient p ON p.PersonId = o.PersonId
		WHERE o.DeleteFlag = 0
	) o WHERE o.rown = 1
 ),

 apc_cte AS (
	SELECT pa.PatientId, CASE WHEN Occupation = 'Student' THEN 'Y' ELSE  ISNULL(o.InSchool, 'N') END AS [InSchool], Education FROM (
		SELECT        
		ROW_NUMBER() OVER(PARTITION BY p.id ORDER BY pa.CreateDate DESC) AS rown,
		p.id AS PatientId,
		Education.Name AS Education, 
		Occupation.Name AS Occupation, 
		TypeOfSchool.Name AS TypeOfSchool
		FROM            
			DTL_FBCUSTOMFIELD_Adolescent_Followup_Psychosocial_Assessment AS pa 
			INNER JOIN patient p ON p.ptn_pk = pa.Ptn_pk
			LEFT OUTER JOIN mst_ModDeCode AS Education ON pa.Education = Education.ID 
			LEFT OUTER JOIN mst_ModDeCode AS Occupation ON pa.Occupation = Occupation.ID 
			LEFT OUTER JOIN mst_ModDeCode AS TypeOfSchool ON pa.TypeOfSchool = TypeOfSchool.ID
		WHERE pa.UserId > 1 
	) pa LEFT JOIN ovc_cte o ON pa.PatientId = o.PatientId
	WHERE pa.rown = 1 
 ),

ever_on_tb_tx_cte AS (
	SELECT PatientId, 'Y' as EverBeenOnTBTx FROM (
		SELECT PatientId, ROW_NUMBER() OVER (PARTITION BY PatientId ORDER BY CreateDate DESC) as RowNum FROM PatientIcf WHERE OnAntiTbDrugs = 1
	) tb WHERE tb.RowNum =1 
),

careending_cte AS (
	SELECT 
		a.PatientId,
		CAST(ce.ExitDate AS DATE) AS ExitDate,
		l.DisplayName AS ExitReason,
		CAST(a.AppointmentDate AS DATE) AS AppointmentDate,
		CAST(DATEADD(DAY, 31, AppointmentDate) AS DATE) AS ProjectedLTFUDate
	FROM PatientAppointment a
	LEFT JOIN PatientCareending ce ON a.PatientId = ce.PatientId AND ce.DeleteFlag = 0 
	LEFT JOIN LookupItem l ON l.Id = ce.ExitReason
	WHERE 
		a.DeleteFlag = 0
--		AND a.PatientId = 9866

),

patient_status_6_months_after_dsd_start AS (
--	SELECT * FROM (
		SELECT 
			d.PatientId,
			d.StartDate,
			CASE WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate < DATEADD(MONTH, 6, d.StartDate)) OR c.ExitDate >= DATEADD(MONTH, 6, d.StartDate) THEN 'Active' WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate >= DATEADD(MONTH, 6, d.StartDate)) THEN 'Lost To Follow Up' ELSE c.ExitReason END AS StatusAt6M,
			CASE WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate < DATEADD(MONTH, 6, d.StartDate)) OR c.ExitDate >= DATEADD(MONTH, 6, d.StartDate) THEN NULL ELSE 
				(CASE WHEN c.ExitDate < DATEADD(MONTH, 6, d.StartDate) THEN c.ExitDate ELSE c.ProjectedLTFUDate END)			
			END AS ExitDateAt6M,
--			c.ExitDate,
--			c.ExitReason,
			ROW_NUMBER() OVER(PARTITION BY d.PatientId ORDER BY c.AppointmentDate DESC) rown
		FROM dsd_start_cte d
		LEFT JOIN careending_cte c 
			ON c.PatientId = d.PatientId
		WHERE 
			(CASE WHEN c.ExitDate < DATEADD(MONTH, 6, d.StartDate) THEN c.ExitDate ELSE c.ProjectedLTFUDate END)
			< DATEADD(MONTH, 6, d.StartDate)
--	) s WHERE s.rown = 1
),

patient_status_12_months_after_dsd_start AS (
	SELECT * FROM (
		SELECT 
			d.PatientId,
			d.StartDate,
			CASE WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate < DATEADD(MONTH, 12, d.StartDate)) OR c.ExitDate >= DATEADD(MONTH, 12, d.StartDate) THEN 'Active' WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate >= DATEADD(MONTH, 12, d.StartDate)) THEN 'Lost To Follow Up' ELSE c.ExitReason END AS StatusAt12M,
			CASE WHEN (c.ExitDate IS NULL AND c.ProjectedLTFUDate < DATEADD(MONTH, 12, d.StartDate)) OR c.ExitDate >= DATEADD(MONTH, 12, d.StartDate) THEN NULL ELSE 
				(CASE WHEN c.ExitDate < DATEADD(MONTH, 12, d.StartDate) THEN c.ExitDate ELSE c.ProjectedLTFUDate END)
			END AS ExitDateAt12M,
--			c.ExitDate,
--			c.ProjectedLTFUDate,
			c.ExitReason,
			ROW_NUMBER() OVER(PARTITION BY d.PatientId ORDER BY c.AppointmentDate DESC) rown
		FROM dsd_start_cte d
		LEFT JOIN careending_cte c 
			ON c.PatientId = d.PatientId
		WHERE 
			(CASE WHEN c.ExitDate < DATEADD(MONTH, 12, d.StartDate) THEN c.ExitDate ELSE c.ProjectedLTFUDate END)
			< DATEADD(MONTH, 12, d.StartDate)
	) s WHERE s.rown = 1
)
--SELECT * FROM dsd_start_cte
--return
--SELECT * FROM patient_status_6_months_after_dsd_start WHERE PatientId = 9866

--return
--select * from gcPatientView WHERE EnrollmentNumber = '13939-24886'
--select * from apc_cte -- WHERE PatientId = 1469
--select * from dc_cte WHERE patientId = 2053
--return

SELECT  DISTINCT /*a.PatientID AS ID,*/
  a.EnrollmentNumber AS [Patient CCC Number],
  dsdstart.DCModel AS [DSD Type],
  dsdstart.startdate AS [DSD Model Start Date],
  art.ARTInitiationDate AS [Date of ART initiation],
  a.currentAge AS Age,
  a.Sex,
  ovc.Education AS [Education Level],
  ISNULL(ovc.InSchool, 'N') AS [In School],
  ms.MaritalStatus AS [Marital Status],
  '' AS Disclosure,
  adh.AdherenceScore AS [Adherence],
  pr.PregnancyStatus AS [Pregnancy Status],
  ISNULL(onTBTx.EverBeenOnTBTx, 'N') AS [TB Treatment],
  fvst.firstVisitDate AS [Date of first visit],
  fvlsample.VlSampleDate AS [Date of 1st VL Sample Collection],
  bvl.VlDate AS [Date 1st VL Results Posted to the website],
  bvl.VLResults AS [1st VL results],
  lvst.LastVisitDate AS [Date of last visit],
  lvlsample.VlSampleDate AS [Date of last VL Sample Collection],
  vl.VlDate AS [Date last VL Results Posted to the website],
  vl.VLResults AS [Last VL results],
  ps6.StatusAt6M,
  ps6.ExitDateAt6M,
  ps12.StatusAt12M,
  ps12.ExitDateAt12M,
  a.ExitReason AS [Exit Reasons]
FROM all_Patients_cte a
	LEFT JOIN marital_status_cte ms ON ms.PatientId = a.PatientID
	LEFT JOIN apc_cte ovc ON ovc.PatientId = a.PatientID
	LEFT JOIN last_visit_cte lvst ON lvst.PatientId = a.PatientID
	LEFT JOIN first_visit_cte fvst ON fvst.PatientId = a.PatientID
	INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
	INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId = a.PatientID
	LEFT JOIN dsd_start_cte dsdstart ON dsdstart.PatientId = a.PatientID
	LEFT JOIN baseline_vl_cte bvl ON bvl.patientId = a.PatientID
	LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
	LEFT JOIN first_vl_sample_cte fvlsample ON fvlsample.patientId = a.PatientID
	LEFT JOIN last_vl_sample_cte lvlsample ON lvlsample.patientId = a.PatientID
	LEFT JOIN pregnancy_cte pr ON pr.PatientId = a.PatientID
	LEFT JOIN art_adherence_cte adh ON adh.PatientId = a.PatientID
	LEFT JOIN ever_on_tb_tx_cte onTBTx ON onTBTx.PatientId = a.PatientID
	LEFT JOIN patient_status_6_months_after_dsd_start ps6 ON ps6.PatientId = a.PatientID
	LEFT JOIN patient_status_12_months_after_dsd_start ps12 ON ps12.PatientId = a.PatientID
--	LEFT JOIN dsd_cte dsd On dsd.PatientId = a.PatientID
WHERE 
--	dsd.DsdDate BETWEEN @startDate AND @endDate
	dsdstart.StartDate BETWEEN @startDate AND @endDate

--  AND a.PatientID = 2053
-- ORDER BY ID

/*
select * from PatientAppointment WHERE PatientId = 7732 order by id desc

select * from gcPatientView WHERE EnrollmentNumber LIKE '%24573%' 

select * from gcPatientView WHERE id = 5466

SELECT * FROM PatientEncounter WHERE PatientMasterVisitId = 229115

select * from PatientCategorization WHERE PatientMasterVisitId = 170327

select * from PatientAppointment where id = 74861 order by id desc
*/



