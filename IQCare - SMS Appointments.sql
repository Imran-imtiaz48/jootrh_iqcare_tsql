USE IQCare_CPAD
Go

SET STATISTICS TIME ON

DECLARE @appointmentDate AS DATE = '2019-08-05'; 

;WITH all_Patients_cte AS (
	SELECT pt.Id AS PatientID,
	  pt.ptn_pk,
      pt.PersonId,
      tp.PatientName,
      tp.PhoneNumber,
      g.PatientEnrollmentID AS EnrollmentNumber,
      CASE WHEN g.Sex = 52 THEN 'F' ELSE 'M' END AS Sex,
      CAST(CASE WHEN TI.TransferInDate IS NOT NULL THEN TI.TransferInDate
        ELSE g.RegistrationDate END AS Date) AS EnrollmentDate,
      P.NextAppointmentDate,
      CASE WHEN ce.PatientId IS NULL THEN 'Active' ELSE ce.ExitReason
      END PatientStatus
    FROM mst_Patient g
	INNER JOIN Patient pt ON pt.ptn_pk = g.Ptn_Pk
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
        WHERE ce.ExitDate < @appointmentDate AND ce.DeleteFlag = 0) ce
      WHERE ce.RowNum = 1) ce ON pt.Id = ce.PatientId
      LEFT JOIN (SELECT DISTINCT p.PatientPK,
        p.PatientName,
        p.ContactPhoneNumber,
        p.PhoneNumber,
        p.ContactName,
        p.MaritalStatus,
        p.EducationLevel,
        CONCAT(p.Landmark, '-', p.NearestHealthCentre) AS Address
      FROM IQTools_KeHMIS.dbo.tmp_PatientMaster p) tp ON tp.PatientPK = g.ptn_pk
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = pt.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X
      WHERE X.AppointmentDate >= @appointmentDate AND X.CreatedBy <> 114
      GROUP BY X.PatientId) P ON pt.Id = P.PatientId
	),
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
          e.CreatedBy AS ProviderId
        FROM PatientMasterVisit v
          INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND
            e.PatientMasterVisitId = v.Id
        WHERE v.VisitDate IS NOT NULL AND
          v.VisitDate <= (SELECT Max(a.AppointmentDate)
          FROM PatientAppointment a
          WHERE a.PatientId = v.PatientId AND a.CreateDate <= @appointmentDate)) v
        INNER JOIN providers_cte p ON p.UserID = v.ProviderId) visits
    WHERE visits.VisitDate <= @appointmentDate AND visits.RowNum = 1),
  last_visit_cte AS (SELECT lastVisit.LastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.VisitDate DESC) AS rowNum,
        v.PatientId,
        v.VisitDate AS LastVisitDate,
        v.PatientMasterVisitId,
        v.UserID AS lastProvider,
        v.ProviderName AS LastProviderName
      FROM all_visits_cte v) lastVisit
    WHERE lastVisit.rowNum = 1),
  all_tca_cte AS (SELECT p.PatientId,
      CAST(p.AppointmentDate AS DATE) AS AppointmentDate,
      CAST(v.VisitDate AS DATE) AS Visitdate,
      l.Name AS VisitStatus,
      p.ServiceAreaId,
      p.ReasonId,
      l1.Name AS AppointmentReason,
      p.Description
    FROM PatientAppointment p
      INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id
      INNER JOIN LookupItem l ON l.Id = p.StatusId
      LEFT JOIN LookupItem l1 ON l1.Id = p.ReasonId
    WHERE p.AppointmentDate = @appointmentDate),
  last_tca_cte AS (SELECT tca.PatientId,
      tca.AppointmentDate AS NextAppointmentDate,
      tca.ServiceArea,
      tca.AppointmentReason,
      tca.Description
    FROM (SELECT Row_Number() OVER (PARTITION BY t.PatientId ORDER BY
        t.Visitdate DESC, t.AppointmentDate DESC) AS rowNUm,
        t.PatientId,
        t.AppointmentDate,
        l.ServiceArea,
        t.AppointmentReason,
        t.Description
      FROM all_tca_cte t
        INNER JOIN (SELECT LookupItemView.ItemId,
          LookupItemView.ItemDisplayName AS ServiceArea
        FROM LookupItemView
        WHERE LookupItemView.MasterName = 'ServiceArea') l ON l.ItemId =
          t.ServiceAreaId
      WHERE t.AppointmentDate = @appointmentDate) tca
    WHERE tca.rowNUm = 1),
	consent_cte AS (
		SELECT distinct patientid FROM PatientConsent
		WHERE ConsentType = 265
		AND CreatedBy = 0
	),

	consented_line_list_cte AS (
		SELECT 
			a.ptn_pk as PatientPK,tca.NextAppointmentDate,a.PhoneNumber,
			--tca.*,
			--a.*,
		  VisitStatus = CASE
			WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) = 0 THEN 'Came'
			WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) <= -1 AND
			DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) >= -7 THEN
			'Came early'
			WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) BETWEEN 1 AND 7
			THEN 'Came late'
			WHEN DateDiff(D, tca.NextAppointmentDate, GetDate()) <= 0 THEN 'Pending'
			WHEN tca.NextAppointmentDate IS NULL THEN NULL ELSE 'Missed' END

		FROM all_Patients_cte a
		  INNER JOIN last_tca_cte tca ON a.PatientID = tca.PatientId
		  LEFT JOIN last_visit_cte lv ON a.PatientID = lv.PatientId
		  INNER JOIN consent_cte c ON c.PatientId = a.PatientID
		WHERE tca.ServiceArea = 'PSC Clinic' AND tca.NextAppointmentDate = @appointmentDate AND a.PatientStatus = 'Active'
	)


--INVALID Phone NUmber
-- SELECT * FROM consented_line_list_cte WHERE VisitStatus = 'Pending' AND (PhoneNumber NOT LIKE '07[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND PhoneNumber NOT LIKE '2547[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')  -- Matches numbers with a length of 10 characters 
--VALID Phone NUmber
 SELECT * FROM consented_line_list_cte WHERE VisitStatus = 'Pending' AND (PhoneNumber LIKE '07[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' OR PhoneNumber LIKE '2547[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')  -- Matches numbers with a length of 10 characters 


--SELECT PATINDEX('__________','07294259060') --0718402205'
