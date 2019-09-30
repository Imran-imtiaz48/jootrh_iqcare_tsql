DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate ='2018-08-15';
set @endDate = '2019-08-14';

WITH all_Patients_cte AS (SELECT g.Id AS PatientID,
      g.PersonId,
      pmst.PatientName,
      PC.MobileNumber AS PhoneNumber,
      tp.ContactPhoneNumber,
      tp.ContactName,
      g.EnrollmentNumber,
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
      tp.MaritalStatus,
      tp.EducationLevel,
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
      LEFT JOIN (SELECT DISTINCT p.PatientPK,
        p.ContactPhoneNumber,
        p.PhoneNumber,
        p.ContactName,
        p.MaritalStatus,
        p.EducationLevel,
        CONCAT(p.Landmark, '-', p.NearestHealthCentre) AS Address
      FROM IQTools_KeHMIS.dbo.tmp_PatientMaster p) tp ON tp.PatientPK = g.ptn_pk
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = g.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Max(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X
      GROUP BY X.PatientId) P ON g.Id = P.PatientId
      INNER JOIN iqtools_kehmis.dbo.tmp_PatientMaster pmst ON g.ptn_pk = pmst.PatientPK),
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
      visits.GroupID
    FROM (SELECT v.PatientId,
        v.VisitDate,
        v.PatientMasterVisitId,
        v.ProviderId,
        p.ProviderName,
        p.GroupID,
        p.UserID,
        Row_Number() OVER (PARTITION BY v.PatientId, v.PatientMasterVisitId
        ORDER BY v.VisitDate DESC) AS RowNum
      FROM (SELECT v.PatientId,
          CAST(v.VisitDate AS DATE) AS VisitDate,
          v.Id AS PatientMasterVisitId,
          v.CreatedBy AS ProviderId
        FROM PatientMasterVisit v
          INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND
            e.PatientMasterVisitId = v.Id
        WHERE v.VisitDate IS NOT NULL AND
          v.VisitDate <= (SELECT Max(a.AppointmentDate)
          FROM PatientAppointment a
          WHERE a.PatientId = v.PatientId AND a.CreateDate <= @endDate)
        UNION
        SELECT PatientScreening.PatientId,
          CAST(PatientScreening.CreateDate AS DATE) AS VisitDate,
          PatientScreening.PatientMasterVisitId,
          PatientScreening.CreatedBy AS lastProvider
        FROM PatientScreening
        UNION
        SELECT p.Id AS PatientId,
          CAST(o.VisitDate AS DATE) AS VisitDate,
          0,
          o.CreatedBy AS LastProvider
        FROM ord_Visit o
          INNER JOIN Patient p ON o.Ptn_Pk = p.ptn_pk
        WHERE o.VisitDate < @endDate) v
        INNER JOIN providers_cte p ON p.UserID = v.ProviderId) visits
    WHERE visits.VisitDate <= @endDate AND visits.RowNum = 1),
  last_visit_cte_wo_provider AS (SELECT lastVisit.Visitdate AS lastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.Visitdate,
      lastVisit.ProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        CAST(v.VisitDate AS DATE) AS Visitdate,
        v.ProviderName,
        v.PatientMasterVisitId,
        v.UserID lastProvider
      FROM all_visits_cte v) lastVisit
    WHERE lastVisit.rowNum = 1),
  last_visit_cte AS (SELECT lastVisit.lastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.Visitdate DESC) AS rowNum,
        v.PatientId,
        v.lastVisitDate,
        v.PatientMasterVisitId,
        v.lastProvider,
        v.ProviderName AS LastProviderName
      FROM last_visit_cte_wo_provider v) lastVisit
    WHERE lastVisit.rowNum = 1),
  gc_last_visit_cte AS (SELECT lastVisit.LastVisitdate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        v.VisitDate LastVisitdate,
        v.PatientMasterVisitId,
        v.UserID lastProvider,
        v.ProviderName AS LastProviderName
      FROM all_visits_cte v
        INNER JOIN PatientEncounter e ON v.PatientId = e.PatientId AND
          v.PatientMasterVisitId = e.PatientMasterVisitId
      WHERE v.PatientMasterVisitId > 0 AND e.EncounterTypeId = 1482) lastVisit
    WHERE lastVisit.rowNum = 1),
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
  last_tca_cte AS (SELECT *
    FROM (SELECT Row_Number() OVER (PARTITION BY all_tca_cte.PatientId
        ORDER BY all_tca_cte.Visitdate DESC, all_tca_cte.AppointmentDate DESC)
        AS rowNUm,
        *
      FROM all_tca_cte) tca
    WHERE tca.rowNUm = 1)
SELECT a.EnrollmentNumber AS PatientId,
  ti.TINumber,
  mch.MCHNumber,
  a.PatientName,
  a.Sex,
  CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType,
  CAST(a.EnrollmentDate AS DATE) AS RegistrationDate,
  CAST(lv.lastVisitDate AS DATE) lastVisitDate,
  CAST(a.NextAppointmentDate AS DATE) TCADate,
  CASE WHEN a.PatientStatus = 'Death' THEN 'Dead'
    WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) < 30 THEN 'Active'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 30 AND
    DateDiff(D, a.NextAppointmentDate, @endDate) < 90 THEN 'Defaulter'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 90 OR
    DateDiff(D, a.NextAppointmentDate, @endDate) IS NULL THEN 'LTFU'
    ELSE a.PatientStatus END AS PatientStatus,
  lv.LastProviderName,
  Abs(DateDiff(D, a.NextAppointmentDate, GetDate())) AS DaysMissed,
  Abs(DateDiff(D, a.NextAppointmentDate, lv.lastVisitDate)) AS
  DaysSinceLastVisit
FROM all_Patients_cte a
  INNER JOIN last_tca_cte tca ON a.PatientID = tca.PatientId
  LEFT JOIN last_visit_cte lv ON a.PatientID = lv.PatientId
  LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
  LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
WHERE Abs(DateDiff(D, a.NextAppointmentDate, lv.lastVisitDate)) > 7 AND
--  lv.LastProviderName IN ('Nancy Odhiambo', 'Onywera Susan', 'Diana Oketch') AND
  a.NextAppointmentDate BETWEEN @startDate AND @endDate AND a.PatientStatus =
  'Active'
--  AND a.currentAge BETWEEN 0 AND 14