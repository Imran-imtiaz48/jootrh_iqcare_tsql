WITH next_appointment_cte AS (SELECT nextAppointment.AppointmentDate AS
      nextAppointmentDate,
      nextAppointment.PatientId,
      nextAppointment.AppointmentReason,
      nextAppointment.Description AS comments
    FROM (SELECT Row_Number() OVER (PARTITION BY a.PatientId ORDER BY
        a.AppointmentDate DESC) AS rowNum,
        a.PatientId,
        CAST(a.AppointmentDate AS Date) AS AppointmentDate,
        a.StatusId,
        a.ReasonId,
        a.Description,
        l1.DisplayName AS AppointmentReason
      FROM PatientAppointment a
        INNER JOIN LookupMasterItem l1 ON l1.LookupItemId = a.ReasonId
      WHERE CAST(a.AppointmentDate AS Date) <= @appointmentDate) nextAppointment
    WHERE nextAppointment.rowNum = 1),
  patient_master_cte AS (SELECT DISTINCT p.Id AS PatientId,
      pm.PatientID AS cccNumber,
      Upper(pm.PatientName) AS PatientName,
      pm.Gender AS Sex,
      pm.AgeCurrent,
      pm.LastVisit AS LastVisit1,
      pm.PhoneNumber,
      pm.ContactPhoneNumber
    FROM tmp_PatientMaster pm
      INNER JOIN Patient p ON p.ptn_pk = pm.PatientPK),
  careending_cte AS (SELECT *
    FROM (SELECT PatientCareending.PatientId,
        PatientCareending.ExitReason,
        PatientCareending.ExitDate
      FROM PatientCareending
      UNION
      SELECT Patient.Id AS PatientId,
        CASE dtl_PatientCareEnded.PatientExitReason WHEN 91 THEN 526
          WHEN 93 THEN 259 WHEN 115 THEN 260 WHEN 118 THEN 260 WHEN 414 THEN 526
        END AS ExitReason,
        dtl_PatientCareEnded.CareEndedDate AS ExitDate
      FROM dtl_PatientCareEnded
        INNER JOIN Patient ON dtl_PatientCareEnded.Ptn_Pk = Patient.ptn_pk) c
    WHERE CAST(c.ExitDate AS Date) <= @appointmentDate),
  tbscreening_cte AS (SELECT PatientScreening.Id,
      PatientScreening.PatientId,
      PatientScreening.PatientMasterVisitId,
      PatientScreening.CreatedBy AS Provider,
      PatientScreening.CreateDate AS VisitDate
    FROM PatientScreening
    WHERE (PatientScreening.ScreeningTypeId = 4) OR
      (PatientScreening.ScreeningTypeId = 12)),
  visits_cte AS (SELECT PatientMasterVisit.Id AS PatientMasterVisitId,
      PatientMasterVisit.PatientId,
      PatientMasterVisit.CreatedBy AS UserId
    FROM PatientMasterVisit
    WHERE PatientMasterVisit.VisitDate IS NOT NULL),
  activevisits_cte AS (SELECT v.*,
      t.VisitDate,
      Coalesce(t.Provider, v.UserId) AS Provider
    FROM visits_cte v
      INNER JOIN tbscreening_cte t ON v.PatientMasterVisitId =
        t.PatientMasterVisitId),
  last_visit_cte1 AS (SELECT lastVisit.VisitDate AS lastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        v.VisitDate,
        v.PatientMasterVisitId
      FROM activevisits_cte v
      WHERE Abs(DateDiff(D, v.VisitDate, @appointmentDate)) < 7) lastVisit
    WHERE lastVisit.rowNum = 1),
  last_visit_cte AS (SELECT CAST(lastEncounter.EncounterDate AS DATE) AS
      lastEncounterDate,
      lastEncounter.PatientId,
      lastEncounter.LastProvider
    FROM (SELECT Row_Number() OVER (PARTITION BY e.PatientId ORDER BY
        e.EncounterDate DESC) AS rowNum,
        e.PatientId,
        e.EncounterDate,
        CONCAT(u.UserFirstName, ' ', u.UserLastName) AS LastProvider
      FROM (SELECT e.PatientId,
          e.EncounterEndTime AS EncounterDate,
          e.CreatedBy
        FROM PatientEncounter e
        WHERE e.CreatedBy NOT IN (93, 49, 38, 95, 75, 37)
        UNION
        SELECT v.PatientId,
          v.CreateDate AS EncounterDate,
          v.CreatedBy
        FROM PatientVitals v
        WHERE v.CreatedBy NOT IN (93, 49, 38, 95, 75, 37)
        UNION
        SELECT p.PatientId,
          p.CreateDate AS EncounterDate,
          p.CreatedBy
        FROM PatientAppointment p
        WHERE p.CreatedBy NOT IN (93, 49, 38, 95, 75, 37)
        UNION
        SELECT s.PatientId,
          s.CreateDate AS EncounterDate,
          s.CreatedBy
        FROM PatientScreening s
        WHERE s.CreatedBy NOT IN (93, 49, 38, 95, 75, 37)
        UNION
        SELECT v.PatientId,
          v.VisitDate AS EncounterDate,
          v.CreatedBy
        FROM PatientMasterVisit v
        WHERE v.VisitDate IS NOT NULL AND v.CreatedBy NOT IN (93, 49, 38, 95,
          75, 37)) e
        INNER JOIN mst_user u ON u.UserID = e.CreatedBy) lastEncounter
    WHERE lastEncounter.rowNum = 1),
  appointment_master_cte AS (SELECT pm.*,
      V.lastEncounterDate AS LastVisit,
      DateDiff(D, V.lastEncounterDate, GetDate()) AS DaysSinceLastVisit,
      a.nextAppointmentDate,
      a.comments,
      a.AppointmentReason,
      DateDiff(D, a.nextAppointmentDate, V.lastEncounterDate) AS DaysMissed,
      V.LastProvider
    FROM next_appointment_cte a
      INNER JOIN patient_master_CTE pm ON pm.PatientId = a.PatientId
      LEFT JOIN careending_cte C ON C.PatientId = a.PatientId
      LEFT JOIN last_visit_cte V ON V.PatientId = a.PatientId
    WHERE a.nextAppointmentDate = @appointmentDate AND C.PatientId IS NULL)
SELECT *,
  CASE
    WHEN appointment_master_cte.DaysMissed >= -3 AND
    appointment_master_cte.DaysMissed <= 3 THEN 'Attended' ELSE 'Not Attended'
  END AS AppointmentStatus
FROM appointment_master_cte