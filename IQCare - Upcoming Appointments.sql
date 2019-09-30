DECLARE @startDate AS date;
DECLARE @endDate AS date;

set @startDate ='2019-06-11';
set @endDate = '2019-06-11';

;WITH all_Patients_cte AS (
SELECT g.Id AS PatientID,
      g.PersonId,
      tp.PatientName,
      tp.PhoneNumber,
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
      LEFT JOIN (SELECT DISTINCT p.PatientPK,
		p.PatientName,
        p.ContactPhoneNumber,
        p.PhoneNumber,
        p.ContactName,
        p.MaritalStatus,
        p.EducationLevel,
        CONCAT(p.Landmark, '-', p.NearestHealthCentre) AS Address
      FROM IQTools_KeHMIS.dbo.tmp_PatientMaster p) tp ON tp.PatientPK = g.ptn_pk
      LEFT JOIN PatientTransferIn TI ON TI.PatientId = g.Id
      LEFT JOIN (SELECT X.PatientId,
        CAST(Min(X.AppointmentDate) AS DATE) AS NextAppointmentDate
      FROM IQCare_CPAD.dbo.PatientAppointment X
	  WHERE x.AppointmentDate >= @endDate AND x.CreatedBy <> 114
      GROUP BY X.PatientId) P ON g.Id = P.PatientId),

	providers_cte AS (
			SELECT CONCAT(u.UserFirstName,' ', u.UserLastName) as ProviderName, u.UserID, lg.GroupID from lnk_UserGroup lg
			INNER JOIN mst_User u ON u.UserID = lg.UserID
			WHERE lg.GroupID = 5 or lg.GroupID = 7 -- ('7 - Nurses', '5 - Clinician')	
	),

	all_visits_cte AS (
		SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId, ProviderName,UserId,GroupId FROM (
			SELECT PatientId,VisitDate,PatientMasterVisitId,ProviderId,p.ProviderName,P.GroupID,p.UserID,ROW_NUMBER() OVER (PARTITION BY PatientId,PatientMasterVisitId ORDER BY VisitDate DESC) as RowNum FROM (
				SELECT v.PatientId,CAST(VisitDate AS DATE) AS VisitDate,v.Id as PatientMasterVisitId, e.CreatedBy as ProviderId FROM PatientMasterVisit v 
				INNER JOIN PatientEncounter e ON e.PatientId = v.PatientId AND e.PatientMasterVisitId = v.id			
				WHERE VisitDate IS NOT NULL AND VisitDate <= (SELECT max(AppointmentDate) FROM PatientAppointment a WHERE a.patientId = v.PatientId AND CreateDate <= @endDate)
				--UNION
				--SELECT PatientId,CAST(CreateDate AS DATE) as VisitDate,PatientMasterVisitId, CreatedBy as lastProvider FROM PatientScreening
				--UNION
				--SELECT p.id as PatientId,CAST(VisitDate AS DATE) as VisitDate,0, o.CreatedBy as LastProvider from ord_Visit o INNER JOIN Patient p ON o.Ptn_pk = p.ptn_pk
				--WHERE VisitDate < @endDate -- AND VisitDate >= @startDate
			) v INNER JOIN providers_cte p ON p.UserID = v.ProviderId
		) visits WHERE VisitDate <= @endDate AND RowNum = 1
	),


  last_visit_cte AS (SELECT lastVisit.lastVisitDate,
      lastVisit.PatientId,
      lastVisit.PatientMasterVisitId,
      lastVisit.lastProvider,
      lastVisit.LastProviderName
    FROM (SELECT Row_Number() OVER (PARTITION BY v.PatientId ORDER BY
        v.Visitdate DESC) AS rowNum,
        v.PatientId,
        v.VisitDate as LastVisitDate,
        v.PatientMasterVisitId,
        v.UserId AS lastProvider,
        v.ProviderName AS LastProviderName
      FROM all_visits_cte v) lastVisit
    WHERE lastVisit.rowNum = 1),
 last_tca_b4_visit_cte AS (
	SELECT PatientID,AppointmentDate FROM (
		SELECT v.PatientId,a.AppointmentDate,DATEDIFF(DAY,a.AppointmentDate,v.lastVisitDate) AS VisitsDelay, ROW_NUMBER() OVER(PARTITION BY v.PatientId ORDER BY a.AppointmentDate DESC) AS rown FROM last_visit_cte v INNER JOIN PatientAppointment a ON v.PatientId = a.PatientId AND ABS(DATEDIFF(DAY,a.AppointmentDate,v.lastVisitDate)) <=7 
	) v WHERE v.rown = 1
 ),	


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
      l.Name AS VisitStatus, ServiceAreaId, p.ReasonId, l1.Name AS AppointmentReason, [Description]
    FROM PatientAppointment p
      INNER JOIN PatientMasterVisit v ON p.PatientMasterVisitId = v.Id
      INNER JOIN LookupItem l ON l.Id = p.StatusId
	  LEFT JOIN LookupItem l1 ON l1.Id = p.ReasonId
    WHERE (v.VisitDate <= @endDate AND Abs(DateDiff(M, v.VisitDate, p.AppointmentDate)) <= 3) OR
      (p.AppointmentDate <= @endDate)
    ),
  last_tca_cte AS (SELECT PatientId,AppointmentDate AS NextAppointmentDate, ServiceArea, AppointmentReason, [Description]
    FROM (SELECT Row_Number() OVER (PARTITION BY t.PatientId
        ORDER BY t.Visitdate DESC, t.AppointmentDate DESC)
        AS rowNUm,
        t.PatientId,
		t.AppointmentDate,
		l.ServiceArea, AppointmentReason, [Description]
      FROM all_tca_cte t
	  INNER JOIN (SELECT ItemId, ItemDisplayName AS ServiceArea FROM LookupItemView WHERE MasterName = 'ServiceArea') l ON l.ItemId = t.ServiceAreaId 
	   WHERE t.AppointmentDate BETWEEN @startDate AND @endDate
	  ) tca
    WHERE tca.rowNUm = 1)

SELECT a.EnrollmentNumber AS PatientId,
  ti.TINumber,
  mch.MCHNumber,
  a.PatientName,
  a.Sex,
  CASE WHEN a.PatientType = 258 THEN 'NEW' ELSE 'TI' END AS PatientType,
  CAST(a.EnrollmentDate AS DATE) AS RegistrationDate,
  CAST(lv.lastVisitDate AS DATE) lastVisitDate,
  CAST(tca.NextAppointmentDate AS DATE) TCADate,
--   DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) aa,
--  tca.NextAppointmentDate,
  tca.AppointmentReason,
  tca.[Description],
  tca.ServiceArea,
  VisitStatus = CASE 
				WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) = 0 THEN 'Came' 
				WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) <= -1 AND DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate)>=-7 THEN 'Came early'		
				WHEN DateDiff(D, tca.NextAppointmentDate, lv.LastVisitDate) BETWEEN 1 AND 7 THEN 'Came late'		
				WHEN DateDiff(D, tca.NextAppointmentDate, GetDate()) <= 0 THEN 'Pending' 
				WHEN tca.NextAppointmentDate IS NULL THEN NULL
				ELSE 'Missed'  
				END, 
/*
	CASE WHEN a.PatientStatus = 'Death' THEN 'Dead'
    WHEN a.PatientStatus = 'Transfer Out' THEN 'TransferOut'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) < 30 THEN 'Active'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 30 AND
    DateDiff(D, a.NextAppointmentDate, @endDate) < 90 THEN 'Defaulter'
    WHEN DateDiff(D, a.NextAppointmentDate, @endDate) >= 90 OR
    DateDiff(D, a.NextAppointmentDate, @endDate) IS NULL THEN 'LTFU'
    ELSE a.PatientStatus END AS PatientStatus,
*/
  lv.LastProviderName,
  CASE WHEN DateDiff(D, lv.lastVisitDate, tca.NextAppointmentDate) = 0 THEN 0 ELSE DateDiff(D, tca.NextAppointmentDate, GETDATE()) END AS
  DaysMissed
FROM all_Patients_cte a
  INNER JOIN last_tca_cte tca ON a.PatientID = tca.PatientId
  LEFT JOIN last_visit_cte lv ON a.PatientID = lv.PatientId
  LEFT JOIN ti_cte ti ON ti.PatientId = a.PatientID
  LEFT JOIN mch_cte mch ON mch.PatientID = a.PatientID
  --LEFT JOIN last_tca_b4_visit_cte lt ON lt.PatientId = a.PatientID
WHERE 
	-- Abs(DateDiff(D, a.NextAppointmentDate, lv.lastVisitDate)) > 7 AND
	tca.NextAppointmentDate BETWEEN @startDate AND @endDate 
	AND a.PatientStatus =  'Active'
 AND tca.ServiceArea = 'PSC Clinic'
--  AND a.currentAge BETWEEN 0 AND 14
--AND a.PatientId= 42210

-- Attended
-- Attended Late
-- Attended Early
-- Missed
-- Pending - 

-- Last Appointment date 7 days earlier or 7days before the last visit date 
return
select * from PatientAppointment WHERE PatientId= 42210-- AppointmentDate BETWEEN '2019-06-06' AND '2019-06-07'
select * from PatientMasterVisit WHERE PatientId= 42210
select * from gcPatientView WHERE EnrollmentNumber = '13939-27496'

select * from mst_User WHERE UserId= 30