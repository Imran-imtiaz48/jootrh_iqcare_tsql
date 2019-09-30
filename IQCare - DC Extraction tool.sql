DECLARE @startDate AS date;
DECLARE @endDate AS date;
DECLARE @midDate AS date;

set @startDate ='2018-01-01';
set @endDate = '2019-05-10';

WITH all_Patients_cte AS (SELECT g.Id AS PatientID,
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
        FROM PatientCareending ce
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
  baseline_cd4_results_cte AS (SELECT *
    FROM (SELECT *,
        Row_Number() OVER (PARTITION BY cd4.patientId ORDER BY cd4.CD4Date) AS
        RowNum
      FROM (SELECT PatientLabTracker.patientId,
          PatientLabTracker.SampleDate AS CD4Date,
          PatientLabTracker.ResultValues AS CD4Results
        FROM PatientLabTracker
        WHERE PatientLabTracker.SampleDate <= @endDate AND
          PatientLabTracker.Results = 'Complete' AND
          PatientLabTracker.LabTestId = 1
        UNION
        SELECT PatientBaselineAssessment.PatientId,
          PatientBaselineAssessment.CreateDate,
          PatientBaselineAssessment.CD4Count
        FROM PatientBaselineAssessment
        WHERE PatientBaselineAssessment.CD4Count > 0) cd4) cd4
    WHERE cd4.RowNum = 1),
  cd4_results_cte AS (SELECT *
    FROM (SELECT PatientLabTracker.patientId,
        PatientLabTracker.SampleDate AS CD4Date,
        PatientLabTracker.ResultValues AS CD4Results,
        Row_Number() OVER (PARTITION BY PatientLabTracker.patientId ORDER BY
        PatientLabTracker.SampleDate DESC) AS RowNum
      FROM PatientLabTracker
      WHERE PatientLabTracker.SampleDate <= @endDate AND
        PatientLabTracker.Results = 'Complete' AND PatientLabTracker.LabTestId =
        1) cd4
    WHERE cd4.RowNum = 1),
  all_vl_cte AS (SELECT DISTINCT t.patientId,
      CAST(t.SampleDate AS DATE) AS VlDate,
      CASE WHEN tr.Undetectable = 1 OR t.ResultTexts LIKE '%< LDL%' THEN 0
        ELSE t.ResultValues END AS VLResults
    FROM PatientLabTracker t
      INNER JOIN dtl_LabOrderTestResult tr ON t.LabOrderId = tr.LabOrderId
    WHERE t.Results = 'Complete' AND t.LabTestId = 3 AND t.SampleDate <=
      @endDate),
  pending_vl_results_cte AS (SELECT *
    FROM (SELECT PatientLabTracker.patientId,
        PatientLabTracker.SampleDate AS VLDate,
        PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY PatientLabTracker.patientId ORDER BY
        PatientLabTracker.SampleDate DESC) AS RowNum
      FROM PatientLabTracker
      WHERE PatientLabTracker.SampleDate <= @endDate AND
        PatientLabTracker.Results = 'Pending' AND PatientLabTracker.LabTestId =
        3) vlr),
  last_vl_sample_in_past_1yr_cte AS (SELECT vlr.patientId,
      vlr.SampleDate,
      vlr.VLResults
    FROM (SELECT PatientLabTracker.patientId,
        CAST(PatientLabTracker.SampleDate AS DATE) AS SampleDate,
        PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY PatientLabTracker.patientId ORDER BY
        PatientLabTracker.SampleDate DESC) AS RowNum
      FROM PatientLabTracker
      WHERE PatientLabTracker.LabTestId = 3 AND PatientLabTracker.SampleDate <=
        @endDate AND DateDiff(MM, PatientLabTracker.SampleDate, @endDate) <=
        12) vlr
    WHERE vlr.RowNum = 1),
  baseline_vl_cte AS (SELECT *
    FROM (SELECT PatientLabTracker.patientId,
        CAST(PatientLabTracker.SampleDate AS DATE) AS VlDate,
        PatientLabTracker.ResultValues AS VLResults,
        Row_Number() OVER (PARTITION BY PatientLabTracker.patientId ORDER BY
        PatientLabTracker.SampleDate) AS RowNum
      FROM PatientLabTracker
      WHERE PatientLabTracker.Results = 'Complete' AND
        PatientLabTracker.LabTestId = 3 AND PatientLabTracker.SampleDate <=
        @endDate) r
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
  patient_artintitiation_dates_cte AS (SELECT PatientARTdates.PatientId,
      CAST(Min(PatientARTdates.ARTDate) AS DATE) AS ARTInitiationDate
    FROM (SELECT PatientHivDiagnosis.PatientId,
        PatientHivDiagnosis.ARTInitiationDate AS ARTDate
      FROM PatientHivDiagnosis
      WHERE PatientHivDiagnosis.ARTInitiationDate IS NOT NULL AND
        PatientHivDiagnosis.ARTInitiationDate >= 2000
      UNION
      SELECT p.Id AS PatientId,
        o.DispensedByDate AS ARTDate
      FROM ord_PatientPharmacyOrder o
        INNER JOIN Patient p ON p.ptn_pk = o.Ptn_pk
      WHERE o.DispensedByDate IS NOT NULL AND o.DispensedByDate <= @endDate AND
        o.ptn_pharmacy_pk IN (SELECT o.ptn_pharmacy_pk
        FROM dtl_PatientPharmacyOrder o INNER JOIN Mst_Drug d
            ON d.Drug_pk = o.Drug_Pk
        WHERE o.Prophylaxis = 0 AND d.Abbreviation IS NOT NULL AND
          d.DrugName NOT LIKE '%COTRI%' AND d.DrugName NOT LIKE '%Sulfa%' AND
          d.DrugName NOT LIKE '%Septrin%' AND d.DrugName NOT LIKE '%Dapson%')
        AND o.DeleteFlag = 0 AND Year(o.DispensedByDate) >=
        2000) PatientARTdates
    GROUP BY PatientARTdates.PatientId),
  all_treatmenttracker_cte AS (SELECT *
    FROM (SELECT t.PatientMasterVisitId,
        t.RegimenId,
        Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenStartDate
        DESC) AS rowNum,
        t.PatientId,
        t.RegimenLine,
        t.Regimen,
        t.RegimenStartDate AS RegimenDate,
        CASE WHEN t.RegimenLine LIKE '%First%' THEN '1'
          WHEN t.RegimenLine LIKE '%Second%' THEN '2'
          WHEN t.RegimenLine LIKE '%third%' THEN 3 ELSE NULL END AS Line,
        TLE400 = (SELECT CASE WHEN Count(o.PatientMasterVisitId) > 0 THEN 1
            ELSE 0 END
        FROM dtl_PatientPharmacyOrder d INNER JOIN ord_PatientPharmacyOrder o
            ON o.ptn_pharmacy_pk = d.ptn_pharmacy_pk
        WHERE o.PatientMasterVisitId = t.PatientMasterVisitId AND
          d.Drug_Pk = 1702)
      FROM PatientTreatmentTrackerViewD4T t
      WHERE t.Regimen IS NOT NULL AND t.RegimenStartDate <= @endDate AND
        Year(t.RegimenStartDate) >= 2000) t),
  curr_treatmenttracker_cte AS (SELECT t.PatientId,
      t.Regimen,
      t.RegimenId,
      t.RegimenDate,
      t.Line AS regimenLine,
      t.TLE400
    FROM (SELECT t.RegimenId,
        Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenDate DESC,
        t.PatientMasterVisitId DESC) AS rowNum,
        t.PatientId,
        t.RegimenLine,
        t.Regimen,
        t.RegimenDate AS RegimenDate,
        CASE WHEN t.RegimenLine LIKE '%First%' THEN '1'
          WHEN t.RegimenLine LIKE '%Second%' THEN '2'
          WHEN t.RegimenLine LIKE '%third%' THEN 3 ELSE NULL END AS Line,
        t.TLE400
      FROM all_treatmenttracker_cte t
      WHERE t.Regimen IS NOT NULL AND t.RegimenDate <= @endDate AND
        Year(t.RegimenDate) >= 2000) t
    WHERE t.rowNum = 1),
  init_treatmenttracker_cte AS (SELECT t.TLE400,
      t.PatientMasterVisitId,
      t.PatientId,
      t.Regimen,
      t.RegimenId,
      t.ARTInitiationDate,
      t.Line AS regimenLine
    FROM (SELECT t.PatientMasterVisitId,
        t.RegimenId,
        Row_Number() OVER (PARTITION BY t.PatientId ORDER BY t.RegimenDate,
        t.RegimenDate, t.PatientMasterVisitId DESC) AS rowNum,
        t.PatientId,
        t.RegimenLine,
        t.Regimen,
        CAST(t.RegimenDate AS DATE) AS ARTInitiationDate,
        CASE WHEN t.RegimenLine LIKE '%First%' THEN '1'
          WHEN t.RegimenLine LIKE '%Second%' THEN '2'
          WHEN t.RegimenLine LIKE '%third%' THEN 3 ELSE NULL END AS Line,
        t.TLE400
      FROM all_treatmenttracker_cte t
      WHERE t.Regimen IS NOT NULL AND Year(t.RegimenDate) >= 2000 AND
        t.RegimenDate <= @endDate) t
    WHERE t.rowNum = 1),
  prev_treatmenttracker_cte AS (SELECT t.PatientId,
      t.Regimen,
      t.RegimenId,
      t.RegimenDate,
      t.Line AS regimenLine,
      t.TLE400
    FROM (SELECT att.RegimenDate,
        att.PatientId,
        att.RegimenId,
        att.Regimen,
        CASE WHEN att.RegimenLine LIKE '%First%' THEN '1'
          WHEN att.RegimenLine LIKE '%Second%' THEN '2'
          WHEN att.RegimenLine LIKE '%third%' THEN 3 ELSE NULL END AS Line,
        t.TLE400,
        Row_Number() OVER (PARTITION BY att.PatientId ORDER BY att.RegimenDate
        DESC) AS RowNum
      FROM curr_treatmenttracker_cte t
        INNER JOIN all_treatmenttracker_cte att ON t.PatientId = att.PatientId
          AND t.RegimenId <> att.RegimenId) t
    WHERE t.RowNum = 1),
  prev_regimen_date_cte AS (SELECT attx.PatientId,
      Min(attx.RegimenDate) AS Regimendate
    FROM all_treatmenttracker_cte attx
      INNER JOIN prev_treatmenttracker_cte pttx ON attx.PatientId =
        pttx.PatientId AND pttx.RegimenId = attx.RegimenId
    GROUP BY attx.PatientId),
  curr_regimen_date_cte AS (SELECT attx.PatientId,
      Min(attx.RegimenDate) AS Regimendate
    FROM all_treatmenttracker_cte attx
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
  all_visits_cte AS (SELECT visits.PatientId,
      visits.VisitDate,
      visits.PatientMasterVisitId,
      visits.ProviderId,
      visits.ProviderName,
      visits.UserID,
      visits.GroupID,
      visits.VisitBy
    FROM (SELECT v.PatientId,
        v.VisitDate,
        v.PatientMasterVisitId,
        v.ProviderId,
        p.ProviderName,
        p.GroupID,
        p.UserID,
        v.VisitBy,
        Row_Number() OVER (PARTITION BY v.PatientId, v.PatientMasterVisitId
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
          WHERE a.PatientId = v.PatientId) AND v.VisitDate = @endDate) v
        INNER JOIN providers_cte p ON p.UserID = v.ProviderId
      WHERE v.VisitDate = @endDate) visits
    WHERE visits.RowNum = 1),
  last_visit_cte AS (SELECT lv.LastVisitDate,
      lv.PatientId,
      lv.PatientMasterVisitId,
      lv.LastProvider,
      lv.LastProviderName,
      LastProviders = Stuff((SELECT DISTINCT ',' + pr.ProviderName
      FROM PatientEncounter e INNER JOIN providers_cte pr ON e.CreatedBy =
          pr.UserID
      WHERE e.PatientMasterVisitId = lv.PatientMasterVisitId
      FOR XML PATH('')), 1, 1, ''),
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
          L1.Name AS PregnancyStatus,
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
        V.VisitDate DESC, s.id DESC) AS rowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        V.VisitDate AS CategorizationDate
      FROM PatientCategorization s
        INNER JOIN PatientMasterVisit AS V ON V.Id = s.PatientMasterVisitId
      WHERE V.VisitDate <= @endDate AND V.DeleteFlag = 0 AND s.DeleteFlag = 0) s
    WHERE s.rowNum = 1),
  dc_cte AS (SELECT dc.PatientId,
      dc.DCModel,
      dc.ServiceArea
    FROM (SELECT PA.PatientId,
        PA.DifferentiatedCareId,
        V.VisitDate,
        L.Name,
        L.DisplayName AS DCModel,
        l1.DisplayName AS ServiceArea,
        Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate DESC,
        PA.Description, PA.CreateDate DESC, PA.CreatedBy DESC) AS RowNum
      FROM PatientAppointment AS PA
        INNER JOIN PatientMasterVisit AS V ON V.Id = PA.PatientMasterVisitId
        INNER JOIN PatientCategorization AS PC ON PC.PatientMasterVisitId =
          PA.PatientMasterVisitId
        INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
        INNER JOIN LookupItem AS l1 ON l1.Id = PA.ServiceAreaId
      WHERE V.VisitDate <= @endDate AND PA.DeleteFlag = 0 AND
        PC.DeleteFlag = 0) dc
    WHERE dc.RowNum = 1),
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
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId, Month(V.VisitDate)
        ORDER BY V.VisitDate DESC) AS RowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        s.PatientMasterVisitId,
        CAST(V.VisitDate AS DATE) AS CategorizationDate
      FROM PatientCategorization s
        INNER JOIN PatientMasterVisit AS V ON V.Id = s.PatientMasterVisitId
      WHERE s.CreateDate >= DateAdd(M, DateDiff(M, 0, @startDate), 0) AND
        V.VisitDate <= EOMONTH(@startDate)) s
    WHERE s.RowNum = 1),
  curr_month_dc_cte AS (SELECT dc.PatientId,
      dc.DCModel
    FROM (SELECT PA.PatientId,
        PA.DifferentiatedCareId,
        V.VisitDate,
        L.Name,
        L.DisplayName AS DCModel,
        Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate DESC)
        AS RowNum
      FROM PatientAppointment AS PA
        INNER JOIN PatientMasterVisit AS V ON V.Id = PA.PatientMasterVisitId
        INNER JOIN PatientCategorization S ON S.PatientMasterVisitId =
          PA.PatientMasterVisitId
        INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
      WHERE V.VisitDate >= DateAdd(M, DateDiff(M, 0, @startDate), 0) AND
        V.VisitDate <= EOMONTH(@startDate)) dc
    WHERE dc.RowNum = 1),
  all_prev_stability_cte AS (SELECT s.PatientId,
      s.Categorization,
      s.CategorizationDate
    FROM (SELECT Row_Number() OVER (PARTITION BY s.PatientId ORDER BY
        V.VisitDate DESC) AS RowNum,
        s.PatientId,
        CASE WHEN s.Categorization = 1 THEN 'Stable' ELSE 'Unstable'
        END AS Categorization,
        s.PatientMasterVisitId,
        CAST(V.VisitDate AS DATE) AS CategorizationDate
      FROM PatientCategorization s
        INNER JOIN PatientMasterVisit AS V ON V.Id = s.PatientMasterVisitId
      WHERE V.VisitDate <= DateAdd(M, DateDiff(M, 0, @startDate), 0)) s
    WHERE s.RowNum = 1),
  prev_dc_cte AS (SELECT dc.PatientId,
      dc.DCModel
    FROM (SELECT PA.PatientId,
        PA.DifferentiatedCareId,
        V.VisitDate,
        L.Name,
        L.DisplayName AS DCModel,
        Row_Number() OVER (PARTITION BY PA.PatientId ORDER BY V.VisitDate DESC)
        AS RowNum
      FROM PatientAppointment AS PA
        INNER JOIN PatientMasterVisit AS V ON V.Id = PA.PatientMasterVisitId
        INNER JOIN PatientCategorization S ON S.PatientMasterVisitId =
          PA.PatientMasterVisitId
        INNER JOIN LookupItem AS L ON PA.DifferentiatedCareId = L.Id
      WHERE V.VisitDate <= DateAdd(M, DateDiff(M, 0, @startDate), 0)) dc
    WHERE dc.RowNum = 1),
	tbscreening_cte AS (
		SELECT * FROM (
			SELECT        l.Name as TbScreeningOutcome, PatientId, PatientMasterVisitId, CreatedBy as [Provider], CreateDate as VisitDate, ROW_NUMBER() OVER(PARTITION BY PatientId ORDER BY CreateDate DESC) rown
			FROM            PatientScreening p INNER JOIN LookupItem l ON l.id = ScreeningValueId
			WHERE        (ScreeningTypeId = 4)
		) tb WHERE tb.rown = 1
	)


SELECT a.PatientID AS ID,
  a.EnrollmentNumber AS [CCC Number],
  a.Sex,
  CAST(a.DateOfBirth AS DATE) AS DOB,
  a.currentAge AS Age,
  art.Regimen AS RegimenAtStart,
  art.ARTInitiationDate AS ARTStartDate,
  pttx.Regimen AS PrevRegimen,
  pttx.RegimenDate AS PrevRegimenStartDate,
  art_cur.Regimen AS CurrentRegimen,
  art_cur.regimenLine AS CurrentregimenLine,
  (SELECT CAST(Min(IsNull(ptt.RegimenStartDate, ptt.DispensedByDate)) AS DATE)
  FROM PatientTreatmentTrackerViewD4T ptt
  WHERE ptt.PatientId = a.PatientID AND ptt.Regimen = art_cur.Regimen)
  AS DateOFSwitchToCurrentRegimen,
  art_cur.regimenLine,
  pr.LMP,
  pr.EDD,
  pr.PregnancyStatus,
  '' AS currentlyOnFp,
  FpMethod = Stuff((SELECT DISTINCT ',' + fp.FPMethod FROM fp_method_cte fp
  WHERE fp.PatientId = a.PatientID FOR XML PATH('')), 1, 1, ''),
  '' AS Occupation,
  CONCAT(l.Location, ' - ', l.WardName, ' - ', l.LandMark) AS Residence,
  st.Categorization,
  dc.DCModel AS StableModel,
  dc.ServiceArea,
  st.CategorizationDate,
  svl.VLResults AS SecondLastVL,
  svl.VlResultsDate AS SecondLastVLDate,
  vl.VLResults AS LastVL,
  vl.VlDate AS LastVLDate,
  tbs.TbScreeningOutcome,
  CASE WHEN a.PatientStatus = 'Death' THEN 'Dead'
    WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) <= 30 THEN 'Active'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) > 30 AND
    DateDiff(D, a.NextAppointmentDate, @endDate) <= 90 THEN 'Defaulter'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 90 THEN 'LTFU'
    ELSE 'Active' END AS PatientStatus,
  lvst.LastProviderName,
  lvst.LastVisitDate,
  CAST(a.NextAppointmentDate AS DATE) NextAppointmentDate,
  csta.Categorization AS CurrentMonthStabilityStatus,
  csta.CategorizationDate AS CurrentMonthCategorizationDate,
  cmdc.DCModel AS CurrentMonthStableModel,
  psta.Categorization AS PrevStabilityStatus,
  psta.CategorizationDate AS PrevCategorizationDate,
  pdc.DCModel AS PrevStableModel
FROM all_Patients_cte a
  LEFT JOIN last_visit_cte lvst ON lvst.PatientId = a.PatientID
  INNER JOIN init_treatmenttracker_cte art ON art.PatientId = a.PatientID
  INNER JOIN curr_treatmenttracker_cte art_cur ON art_cur.PatientId =
    a.PatientID
  LEFT JOIN prev_treatmenttracker_cte pttx ON pttx.PatientId = a.PatientID
  LEFT JOIN vl_cte vl ON vl.patientId = a.PatientID
  LEFT JOIN second_last_vl_cte svl ON svl.patientId = a.PatientID
  LEFT JOIN pregnancy_cte pr ON pr.PatientId = a.PatientID
  LEFT JOIN stability_cte st ON st.PatientId = a.PatientID
  LEFT JOIN dc_cte dc ON dc.PatientId = a.PatientID
  LEFT JOIN fp_cte fp ON a.PatientID = fp.PatientId
  LEFT JOIN location_cte l ON l.PatientId = a.PatientID
  LEFT JOIN all_curr_month_stability_cte csta ON csta.PatientId = a.PatientID
  LEFT JOIN curr_month_dc_cte cmdc ON cmdc.PatientId = a.PatientID
  LEFT JOIN all_prev_stability_cte psta ON psta.PatientId = a.PatientID
  LEFT JOIN prev_dc_cte pdc ON pdc.PatientId = a.PatientID
  LEFT JOIN last_tca_cte ltca ON ltca.PatientId = a.PatientID
  LEFT JOIN tbscreening_cte tbs ON tbs.PatientId = a.PatientID
WHERE a.EnrollmentDate <= @endDate AND DateDiff(D, a.NextAppointmentDate,
  @endDate) <= 30
ORDER BY ID

/*
select * from PatientAppointment WHERE PatientId = 7732 order by id desc

select * from gcPatientView WHERE EnrollmentNumber LIKE '%24573%' 

select * from gcPatientView WHERE id = 5466

SELECT * FROM PatientEncounter WHERE PatientMasterVisitId = 229115

select * from PatientCategorization WHERE PatientMasterVisitId = 170327

select * from PatientAppointment where id = 74861 order by id desc
*/



